// lib/quality_control/service/quality_control_service.dart
//
// Client HTTP du module CONTRÔLE QUALITÉ (/quality-control) — fiches qualité
// des MACHINES (PROMESH / PROBAR), indépendantes de la production.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;

import 'package:dash_master_toolkit/providers/api_client.dart';
import '../model/quality_control_comparison.dart';
import '../model/quality_control_model.dart';

/// Erreur métier renvoyée par le backend (code + message + erreurs par
/// paramètre pour VALIDATION_FAILED).
class QualityControlApiException implements Exception {
  final String? code;
  final String message;
  final List<Map<String, dynamic>> errors;
  // FICHE_EXISTS : id de la fiche déjà ouverte (machine / date / poste).
  final String? existingId;
  // READING_TIME_EXISTS : id du prélèvement déjà enregistré à cette heure.
  final String? existingReadingId;
  QualityControlApiException(this.message, {this.code, this.errors = const [], this.existingId, this.existingReadingId});

  Set<String> get parameterKeysInError =>
      errors.map((e) => e['parameterKey']?.toString()).whereType<String>().toSet();

  @override
  String toString() => message;
}

class QualityControlService {
  static final QualityControlService instance = QualityControlService._();
  QualityControlService._();

  static const _basePath = '/quality-control';

  // ── Synchronisation (PostgreSQL = source unique de vérité) ─────────────
  //
  // `revision` est incrémenté après CHAQUE écriture réussie (création,
  // brouillon, modification, validation) : les écrans encore montés
  // (accueil, ligne, machine — pages imbriquées qui restent dans la pile)
  // l'écoutent et relisent l'API. Aucun compteur n'est jamais recalculé
  // localement.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Période partagée par toutes les pages du module (mêmes chiffres partout).
  final ValueNotifier<String> period = ValueNotifier<String>('all');

  Future<T> _call<T>(Future<Response> Function() request, T Function(dynamic data) parse) async {
    try {
      final res = await request();
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return parse(body['data']);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        throw QualityControlApiException(
          data['message']?.toString() ?? 'Erreur serveur',
          code: data['code']?.toString(),
          errors: (data['errors'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
          existingId: data['existingId']?.toString(),
          existingReadingId: data['existingReadingId']?.toString(),
        );
      }
      throw QualityControlApiException(e.message ?? 'Erreur réseau');
    }
  }

  QualityControlModel _control(dynamic data) => QualityControlModel.fromJson(Map<String, dynamic>.from(data as Map));

  List<QualityControlModel> _controls(dynamic data) =>
      (data as List? ?? []).whereType<Map>().map((m) => QualityControlModel.fromJson(Map<String, dynamic>.from(m))).toList();

  Future<List<QualityParameter>> fetchParameters() => _call(
        () => ApiClient.instance.dio.get('$_basePath/parameters'),
        (data) => (data as List? ?? [])
            .whereType<Map>()
            .map((m) => QualityParameter.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  QualityConfig? _config;

  /// Paramètres (sections, types de champ, unités, choix) + lignes de
  /// production et leurs machines — servis par le backend, mis en cache.
  Future<QualityConfig> fetchConfig({bool refresh = false}) async {
    final cached = _config;
    if (cached != null && !refresh) return cached;
    final config = await _call(
      () => ApiClient.instance.dio.get('$_basePath/config'),
      (data) => QualityConfig.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    _config = config;
    return config;
  }

  /// `status` : un ou plusieurs statuts séparés par des virgules
  /// ("À vérifier" = 'EN_ATTENTE,EN_COURS'). `from`/`to` : AAAA-MM-JJ.
  Future<List<QualityControlModel>> fetchHistory({
    String? status,
    String? productionType,
    String? machine,
    String? from,
    String? to,
    int limit = 100,
  }) =>
      _call(
        () => ApiClient.instance.dio.get(_basePath, queryParameters: {
          'limit': limit.toString(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (productionType != null && productionType.isNotEmpty) 'productionType': productionType,
          if (machine != null && machine.isNotEmpty) 'machine': machine,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        }),
        _controls,
      );

  /// Filtres de l'Historique → paramètres de requête (liste, export) :
  /// les mêmes partout, le backend applique la même fonction de filtrage.
  static Map<String, String> historyQuery({
    String? status,
    String? productionType,
    String? machine,
    String? from,
    String? to,
    String? search,
  }) =>
      {
        if (status != null && status.isNotEmpty) 'status': status,
        if (productionType != null && productionType.isNotEmpty) 'productionType': productionType,
        if (machine != null && machine.isNotEmpty) 'machine': machine,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };

  /// Fichier généré par le backend (xlsx / pdf / csv) — contenu vérifié.
  Future<Uint8List> _download(String path, Map<String, String> query, String format) async {
    try {
      final res = await ApiClient.instance.dio.get(
        path,
        queryParameters: {...query, 'format': format},
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 180)),
      );
      final raw = res.data;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(List<int>.from(raw as List));
      final valid = switch (format) {
        'pdf' => bytes.length > 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-',
        'xlsx' => bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B, // archive ZIP
        _ => bytes.isNotEmpty,
      };
      if (!valid) throw QualityControlApiException('Fichier $format invalide reçu (${bytes.length} octets)');
      return bytes;
    } on DioException catch (e) {
      // Corps d'erreur JSON reçu en octets (responseType.bytes).
      String message = e.message ?? 'Erreur réseau';
      String? code;
      final data = e.response?.data;
      if (data is List<int>) {
        try {
          final json = jsonDecode(utf8.decode(data));
          if (json is Map) {
            message = json['message']?.toString() ?? message;
            code = json['code']?.toString();
          }
        } catch (_) {}
      }
      throw QualityControlApiException(message, code: code);
    }
  }

  /// Export de l'Historique (données FILTRÉES) : 'xlsx' | 'pdf' | 'csv'.
  Future<Uint8List> exportHistory(String format, Map<String, String> filters) =>
      _download('$_basePath/export', filters, format);

  /// Comparaison qualité (calculée par le backend sur PostgreSQL).
  Future<QualityComparison> fetchComparison(Map<String, String> query) => _call(
        () => ApiClient.instance.dio.get('$_basePath/comparison', queryParameters: query),
        (data) => QualityComparison.fromJson(Map<String, dynamic>.from(data as Map)),
      );

  /// Export de la comparaison : 'xlsx' | 'pdf'.
  Future<Uint8List> exportComparison(String format, Map<String, String> query) =>
      _download('$_basePath/comparison/export', query, format);

  /// Historique paginé + recherche (référence, ligne, contrôleur, « machine N »).
  Future<QualityControlPage> fetchHistoryPage({
    int page = 1,
    int limit = 20,
    String? status,
    String? productionType,
    String? machine,
    String? from,
    String? to,
    String? search,
    String? period,
  }) async {
    try {
      final res = await ApiClient.instance.dio.get(_basePath, queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (period != null && period.isNotEmpty && period != 'all') 'period': period,
        if (status != null && status.isNotEmpty) 'status': status,
        if (productionType != null && productionType.isNotEmpty) 'productionType': productionType,
        if (machine != null && machine.isNotEmpty) 'machine': machine,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final p = body['pagination'] is Map ? Map<String, dynamic>.from(body['pagination'] as Map) : <String, dynamic>{};
      return QualityControlPage(
        items: _controls(body['data']),
        page: (p['page'] as num?)?.toInt() ?? page,
        totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
        total: (p['total'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      throw QualityControlApiException(
        data is Map ? (data['message']?.toString() ?? 'Erreur serveur') : (e.message ?? 'Erreur réseau'),
        code: data is Map ? data['code']?.toString() : null,
      );
    }
  }

  // Statistiques — UNE requête (GET /quality-control/stats) pour toutes les
  // cartes (lignes, machines, derniers contrôles). TOUJOURS relue depuis
  // l'API ; la dernière réponse sert uniquement d'affichage immédiat pendant
  // le rechargement (jamais de valeur considérée comme définitive).
  final Map<String, QualityStats> _stats = {};

  /// Dernière réponse de l'API (affichage pendant le rechargement).
  QualityStats? cachedStats(String period) => _stats[period];

  Future<QualityStats> fetchStats({String? period}) async {
    final p = period ?? this.period.value;
    final stats = await _call(
      () => ApiClient.instance.dio.get('$_basePath/stats', queryParameters: {'period': p}),
      (data) => QualityStats.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    _stats[p] = stats;
    return stats;
  }

  /// Tests uniquement : pré-remplit les caches avec des réponses réelles
  /// capturées (aucun réseau en test).
  @visibleForTesting
  void seedForTest({QualityConfig? config, Map<String, QualityStats> stats = const {}}) {
    if (config != null) _config = config;
    _stats.addAll(stats);
  }

  // Après une écriture : anciennes statistiques écartées et écrans
  // notifiés (rechargement depuis l'API).
  T _invalidating<T>(T value) {
    _stats.clear();
    revision.value++;
    return value;
  }

  Future<QualityControlModel> fetchById(String id) =>
      _call(() => ApiClient.instance.dio.get('$_basePath/$id'), _control);

  /// Recherche automatique de la fiche de production (ligne + machine + date
  /// de production + poste) : état seulement, pour le message non bloquant.
  Future<QcProductionMatch> fetchProductionMatch({
    required String productionType,
    required String machine,
    required String productionDate,
    required String poste,
  }) =>
      _call(
        () => ApiClient.instance.dio.get('$_basePath/production-match', queryParameters: {
          'productionType': productionType,
          'machine': machine,
          'productionDate': productionDate,
          'poste': poste,
        }),
        (data) => QcProductionMatch.fromJson(Map<String, dynamic>.from(data as Map)),
      );

  /// Suppression d'un BROUILLON (403 CONTROL_LOCKED si le contrôle est validé).
  Future<void> delete(String id) => _call(
        () => ApiClient.instance.dio.delete('$_basePath/$id'),
        (data) => _invalidating(null),
      );

  /// Corps d'un PRÉLÈVEMENT : heure du contrôle + paramètres saisis.
  static Map<String, dynamic> _readingBody({String? readingTime, List<Map<String, dynamic>> items = const [], bool validate = false, String? status}) => {
        if (readingTime != null) 'readingTime': readingTime,
        'items': items,
        if (validate) 'validate': true,
        if (status != null) 'status': status,
      };

  /// CRÉATION (POST) d'une fiche qualité de machine. `reading` : PREMIER
  /// prélèvement (heure + paramètres ; `readingValidate` = valider ce prélèvement).
  /// `validate: true` + `status` : valider la FICHE dans la même transaction.
  /// 409 FICHE_EXISTS (+ existingId) si une fiche est déjà ouverte pour la
  /// même machine / date de production / poste.
  Future<QualityControlModel> create({
    required String productionType,
    required String machine,
    String? readingTime,
    List<Map<String, dynamic>> items = const [],
    bool readingValidate = false,
    String? remark,
    List<Map<String, dynamic>> physical = const [],
    Map<String, String> header = const {},
    bool validate = false,
    String? status,
  }) =>
      _call(
        () => ApiClient.instance.dio.post(_basePath, data: {
          'productionType': productionType,
          'machine': machine,
          ...header,
          if (readingTime != null)
            'reading': _readingBody(readingTime: readingTime, items: items, validate: readingValidate, status: readingValidate ? status : null),
          if (remark != null && remark.isNotEmpty) 'remark': remark,
          if (physical.isNotEmpty) 'physical': physical,
          if (validate) 'validate': true,
          if (validate && status != null) 'status': status,
        }),
        (data) => _invalidating(_control(data)),
      );

  // FICHE — `header` : champs d'en-tête MODIFIÉS uniquement (controlDate,
  // controlTime, productionDate, poste, lot, manufacturingOrder) — voir
  // QualityControlHeader.diff. La fiche de production n'est jamais envoyée :
  // le serveur l'associe lui-même. `physical` : PARAMÈTRES PHYSIQUES de la
  // fiche (modifiés uniquement) — indépendants du temps ; les contrôles
  // temporels appartiennent aux PRÉLÈVEMENTS (voir plus bas), jamais mélangés.
  Future<QualityControlModel> update(String id,
          {String? remark, Map<String, String> header = const {}, List<Map<String, dynamic>> physical = const []}) =>
      _call(
        () => ApiClient.instance.dio.put('$_basePath/$id', data: {
          ...header,
          if (remark != null) 'remark': remark,
          if (physical.isNotEmpty) 'physical': physical,
        }),
        (data) => _invalidating(_control(data)),
      );

  /// Validation de la FICHE : ses prélèvements brouillons sont validés avec elle,
  /// puis tout passe en lecture seule.
  Future<QualityControlModel> validate(String id, {String? remark, String? status, Map<String, String> header = const {}}) => _call(
        () => ApiClient.instance.dio.post('$_basePath/$id/validate', data: {
          ...header,
          if (remark != null) 'remark': remark,
          if (status != null) 'status': status,
        }),
        (data) => _invalidating(_control(data)),
      );

  // ── Prélèvements d'une fiche ────────────────────────────────────────────────

  /// NOUVEAU prélèvement (jamais une modification d'un prélèvement existant).
  /// 409 READING_TIME_EXISTS (+ existingReadingId) si l'heure existe déjà.
  Future<QualityControlModel> createReading(String id,
          {required String readingTime, List<Map<String, dynamic>> items = const [], bool validate = false, String? status}) =>
      _call(
        () => ApiClient.instance.dio.post('$_basePath/$id/readings',
            data: _readingBody(readingTime: readingTime, items: items, validate: validate, status: validate ? status : null)),
        (data) => _invalidating(_control(data)),
      );

  Future<QualityControlModel> updateReading(String id, String readingId, {String? readingTime, List<Map<String, dynamic>> items = const []}) => _call(
        () => ApiClient.instance.dio.put('$_basePath/$id/readings/$readingId', data: _readingBody(readingTime: readingTime, items: items)),
        (data) => _invalidating(_control(data)),
      );

  Future<QualityControlModel> validateReading(String id, String readingId,
          {String? readingTime, List<Map<String, dynamic>> items = const [], String? status}) =>
      _call(
        () => ApiClient.instance.dio
            .post('$_basePath/$id/readings/$readingId/validate', data: _readingBody(readingTime: readingTime, items: items, status: status)),
        (data) => _invalidating(_control(data)),
      );

  /// Suppression d'un prélèvement BROUILLON (403 READING_LOCKED s'il est validé).
  Future<QualityControlModel> deleteReading(String id, String readingId) => _call(
        () => ApiClient.instance.dio.delete('$_basePath/$id/readings/$readingId'),
        (data) => _invalidating(_control(data)),
      );
}
