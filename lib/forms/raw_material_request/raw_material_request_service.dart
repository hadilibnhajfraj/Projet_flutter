// lib/forms/raw_material_request/raw_material_request_service.dart
//
// Client HTTP des demandes de matières premières (backend :
// /raw-material-requests). Qui doit faire une demande (compte + poste) est
// décidé par le backend à partir de l'utilisateur authentifié — jamais par
// cet écran ; le backend refuse aussi la création de fiche sans demande.

import 'package:dio/dio.dart' show DioException;

import 'package:dash_master_toolkit/providers/api_client.dart';

/// Une ligne du formulaire (une des 5 matières). Unité toujours KG côté backend.
class RawMaterialLine {
  final String material; // code : 'ISO', 'RESINE', … 'FIBRE' (voir kRawMaterials)
  final String? reference;
  final String? lot;
  final double quantiteDisponible;
  final double besoinProduction;
  final double quantiteDemandee;

  const RawMaterialLine({
    required this.material,
    this.reference,
    this.lot,
    required this.quantiteDisponible,
    required this.besoinProduction,
    required this.quantiteDemandee,
  });

  Map<String, dynamic> toJson() => {
        'material': material,
        'reference': (reference ?? '').trim().isEmpty ? null : reference!.trim(),
        'lot': (lot ?? '').trim().isEmpty ? null : lot!.trim(),
        'quantiteDisponible': quantiteDisponible,
        'besoinProduction': besoinProduction,
        'quantiteDemandee': quantiteDemandee,
      };
}

/// Demande du vendredi rejetée par le responsable : à corriger puis à
/// soumettre de nouveau (même demande, valeurs rechargées).
class RawMaterialRejection {
  final String id;
  final List<dynamic> items;
  final String? comment;
  const RawMaterialRejection({required this.id, this.items = const [], this.comment});
}

/// Réponse du backend (jour et heure du SERVEUR) : demande exigée ? Poste
/// retenu, échéance de validation (vendredi 14 h), demande déjà soumise ce
/// vendredi, ou demande rejetée à corriger.
class RawMaterialRequirement {
  final bool required;
  final String? poste;
  final String? pendingRequestId;
  final DateTime? deadlineAt;
  final bool deadlinePassed;
  final RawMaterialRejection? rejected;

  const RawMaterialRequirement({
    required this.required,
    this.poste,
    this.pendingRequestId,
    this.deadlineAt,
    this.deadlinePassed = false,
    this.rejected,
  });
}

RawMaterialRequirement _requirementFrom(dynamic body, String? poste) {
  final data = body is Map ? body['data'] : null;
  if (data is! Map) return RawMaterialRequirement(required: false, poste: poste);
  final rejected = data['rejectedRequest'];
  return RawMaterialRequirement(
    required: data['required'] == true,
    poste: data['poste']?.toString() ?? poste,
    pendingRequestId: data['pendingRequestId']?.toString(),
    deadlineAt: data['deadlineAt'] == null ? null : DateTime.tryParse(data['deadlineAt'].toString()),
    deadlinePassed: data['deadlinePassed'] == true,
    rejected: rejected is Map && rejected['id'] != null
        ? RawMaterialRejection(
            id: rejected['id'].toString(),
            items: rejected['items'] is List ? rejected['items'] as List : const [],
            comment: rejected['comment']?.toString(),
          )
        : null,
  );
}

class RawMaterialRequestService {
  static final RawMaterialRequestService instance = RawMaterialRequestService._();
  RawMaterialRequestService._();

  static const _base = '/raw-material-requests';

  /// true si l'utilisateur connecté doit valider une demande avant de créer
  /// une fiche `module` ('promesh' | 'probar') au poste `poste`.
  Future<bool> isRequired({required String module, required String poste}) async =>
      (await requirement(module: module, poste: poste)).required;

  /// Comme [isRequired], avec le poste retenu par le backend : sans `poste`
  /// (fiche MÉLANGE), il est déduit des horaires de production du compte.
  Future<RawMaterialRequirement> requirement({required String module, String? poste}) async {
    try {
      final res = await ApiClient.instance.dio.get('$_base/requirement', queryParameters: {
        'module': module,
        if (poste != null) 'poste': poste,
      });
      return _requirementFrom(res.data, poste);
    } on DioException catch (e) {
      // Backend antérieur à cette fonctionnalité : aucune demande exigée.
      if (e.response?.statusCode == 404) return RawMaterialRequirement(required: false, poste: poste);
      rethrow;
    }
  }

  /// Popup à la connexion (le vendredi seulement, heure du serveur). Le
  /// poste est déterminé par le backend (horaires de production du compte)
  /// — false si la demande de ce vendredi a déjà été soumise.
  Future<RawMaterialRequirement> sessionRequirement() async {
    try {
      final res = await ApiClient.instance.dio.get('$_base/session-requirement');
      return _requirementFrom(res.data, null);
    } on DioException catch (e) {
      // Backend antérieur à cette fonctionnalité : aucune demande exigée.
      if (e.response?.statusCode == 404) return const RawMaterialRequirement(required: false);
      rethrow;
    }
  }

  /// Demande enregistrée (lignes `items` telles que stockées en base).
  Future<Map<String, dynamic>> fetchById(String id) async {
    final res = await ApiClient.instance.dio.get('$_base/$id');
    final data = res.data is Map ? (res.data as Map)['data'] : null;
    if (data is! Map || data['id'] == null) throw Exception('Demande de matières premières introuvable.');
    return Map<String, dynamic>.from(data);
  }

  /// Enregistre la demande. `clientRequestId` est fixé à l'ouverture de la
  /// popup : renvoyer la même requête (double clic, nouvel essai) ne crée
  /// jamais une seconde demande.
  Future<Map<String, dynamic>> create({
    required String clientRequestId,
    String? module, // null : demande faite à la connexion
    String? machine,
    required String poste,
    required List<RawMaterialLine> lines,
  }) async {
    final res = await ApiClient.instance.dio.post(_base, data: {
      'clientRequestId': clientRequestId,
      if (module != null) 'module': module,
      if (machine != null) 'machine': machine,
      'poste': poste,
      'items': lines.map((l) => l.toJson()).toList(),
    });
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    // Enregistrée seulement si le backend le confirme (succès + identifiant).
    if (body is! Map || body['success'] != true || data is! Map || data['id'] == null) {
      throw Exception("Le serveur n'a pas confirmé l'enregistrement de la demande.");
    }
    return Map<String, dynamic>.from(data);
  }

  /// Correction d'une demande rejetée : mêmes règles et même confirmation
  /// que [create] ; la demande repasse « En attente de validation ».
  Future<Map<String, dynamic>> resubmit(String id, {required List<RawMaterialLine> lines}) async {
    final res = await ApiClient.instance.dio.put('$_base/$id/resubmit', data: {
      'items': lines.map((l) => l.toJson()).toList(),
    });
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (body is! Map || body['success'] != true || data is! Map || data['id'] == null) {
      throw Exception("Le serveur n'a pas confirmé l'enregistrement de la demande.");
    }
    return Map<String, dynamic>.from(data);
  }

  /// Message lisible pour une erreur d'enregistrement.
  static String friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final m = data is Map ? data['message']?.toString() : null;
      if (m != null && m.isNotEmpty) return m;
      if (e.response == null) return 'Serveur injoignable. Vérifiez votre connexion puis réessayez.';
      return 'Erreur HTTP ${e.response!.statusCode}.';
    }
    return e.toString();
  }
}
