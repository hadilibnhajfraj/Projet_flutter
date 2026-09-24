// lib/reports/service/reports_service.dart
//
// Client HTTP du "Rapport de pilotage" (backend : GET /reports/*).
// Toutes les valeurs proviennent du backend (agrégations SQL) — aucun calcul
// métier n'est fait côté Flutter.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException, Options, ResponseType;
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';

class ReportFilters {
  DateTime? from;
  DateTime? to;
  String? commercialId;
  String? userId;
  String? statut;
  String? projectId;
  String? companyId;
  String? machine;
  String? module;
  String? poste;

  ReportFilters();

  ReportFilters copy() => ReportFilters()
    ..from = from
    ..to = to
    ..commercialId = commercialId
    ..userId = userId
    ..statut = statut
    ..projectId = projectId
    ..companyId = companyId
    ..machine = machine
    ..module = module
    ..poste = poste;

  bool get isEmpty =>
      from == null &&
      to == null &&
      commercialId == null &&
      userId == null &&
      statut == null &&
      projectId == null &&
      companyId == null &&
      machine == null &&
      module == null &&
      poste == null;

  Map<String, String> toQuery(String lang) {
    final f = DateFormat('yyyy-MM-dd');
    return {
      'lang': lang,
      if (from != null) 'from': f.format(from!),
      if (to != null) 'to': f.format(to!),
      if (commercialId != null) 'commercialId': commercialId!,
      if (userId != null) 'userId': userId!,
      if (statut != null) 'statut': statut!,
      if (projectId != null) 'projectId': projectId!,
      if (companyId != null) 'companyId': companyId!,
      if (machine != null) 'machine': machine!,
      if (module != null) 'module': module!,
      if (poste != null) 'poste': poste!,
    };
  }
}

class ReportsService {
  static final ReportsService instance = ReportsService._();
  ReportsService._();

  static const _base = '/reports';
  static const _timeout = Duration(seconds: 90);

  Future<dynamic> _get(String path, Map<String, String> q) async {
    final res = await ApiClient.instance.dio.get(
      '$_base$path',
      queryParameters: q,
      options: Options(receiveTimeout: _timeout),
    );
    final body = res.data;
    if (body is Map) return body['data'];
    return null;
  }

  Future<Map<String, dynamic>> _map(String path, Map<String, String> q) async {
    final d = await _get(path, q);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> filters() => _map('/filters', const {});
  Future<Map<String, dynamic>> overview(Map<String, String> q) => _map('/overview', q);
  Future<List<Map<String, dynamic>>> commercials(Map<String, String> q) async => _list(await _get('/commercials', q));
  Future<Map<String, dynamic>> projects(Map<String, String> q) => _map('/projects', {...q, 'limit': '500'});
  Future<Map<String, dynamic>> archived(Map<String, String> q) => _map('/projects/archived', {...q, 'limit': '500'});
  Future<Map<String, dynamic>> contacts(Map<String, String> q) => _map('/contacts', q);
  Future<List<Map<String, dynamic>>> users(Map<String, String> q) async => _list(await _get('/users', q));
  Future<Map<String, dynamic>> userDetail(String id, Map<String, String> q) => _map('/users/$id', q);
  Future<Map<String, dynamic>> activity(Map<String, String> q) => _map('/activity', {...q, 'limit': '200'});
  Future<Map<String, dynamic>> industrial(Map<String, String> q) => _map('/industrial', q);
  Future<Map<String, dynamic>> machines(Map<String, String> q) => _map('/machines', q);
  Future<Map<String, dynamic>> production(Map<String, String> q) => _map('/production', q);
  Future<Map<String, dynamic>> dataQuality(Map<String, String> q) => _map('/data-quality', q);
  Future<Map<String, dynamic>> recommendations(Map<String, String> q) => _map('/recommendations', q);

  List<Map<String, dynamic>> _list(dynamic d) =>
      (d as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// [kind] = 'excel' | 'pdf'. Retourne des octets typés (Uint8List) : un
  /// List<int> quelconque serait converti en texte par Blob et corromprait le fichier.
  Future<Uint8List> export(String kind, Map<String, String> q) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '$_base/export/$kind',
        queryParameters: q,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 180)),
      );
      final raw = res.data;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(List<int>.from(raw as List));
      if (kind == 'pdf') {
        final head = bytes.length >= 5 ? String.fromCharCodes(bytes.sublist(0, 5)) : '';
        if (head != '%PDF-') {
          throw ReportExportException('Invalid PDF received (${bytes.length} bytes)');
        }
      } else if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        throw ReportExportException('Invalid Excel file received (${bytes.length} bytes)');
      }
      return bytes;
    } on DioException catch (e) {
      // Le corps d'erreur est du JSON, mais reçu en octets (responseType.bytes).
      String? serverMsg;
      try {
        final data = e.response?.data;
        if (data is List<int>) {
          final j = jsonDecode(utf8.decode(data));
          if (j is Map && j['message'] != null) serverMsg = j['message'].toString();
        }
      } catch (_) {}
      throw ReportExportException(serverMsg ?? e.message ?? 'network error', statusCode: e.response?.statusCode);
    }
  }
}

class ReportExportException implements Exception {
  final String message;
  final int? statusCode;
  ReportExportException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null ? 'HTTP $statusCode: $message' : message;
}
