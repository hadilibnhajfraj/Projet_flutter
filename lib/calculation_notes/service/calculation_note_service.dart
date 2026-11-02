// Module « Notes de calcul » — appels à /calculation-notes via ApiClient
// (jeton, rafraîchissement, et refus local des écritures du compte
// back-office). Le backend revérifie chaque permission.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';

import '../model/calculation_note.dart';
import 'note_file_saver.dart';

class CalculationNoteFilters {
  final String reference;
  final String project;
  final String? projectId;
  final String? requesterId;
  final String? status;
  final DateTime? from;
  final DateTime? to;
  final String sortBy; // createdAt | reference
  final bool ascending;
  final int page;
  final int limit;
  const CalculationNoteFilters({
    this.reference = '',
    this.project = '',
    this.projectId,
    this.requesterId,
    this.status,
    this.from,
    this.to,
    this.sortBy = 'createdAt',
    this.ascending = false,
    this.page = 1,
    this.limit = 20,
  });

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery() => {
        if (reference.trim().isNotEmpty) 'reference': reference.trim(),
        if (project.trim().isNotEmpty) 'project': project.trim(),
        if (projectId != null) 'projectId': projectId,
        if (requesterId != null) 'requesterId': requesterId,
        if (status != null) 'status': status,
        if (from != null) 'from': _day(from!),
        if (to != null) 'to': _day(to!),
        'sortBy': sortBy,
        'sortDir': ascending ? 'asc' : 'desc',
        'page': page,
        'limit': limit,
      };
}

/// Message lisible d'une erreur du backend ({ code, message }) ou d'une
/// réponse mal formée (champ nommé, jamais une TypeError brute).
String noteErrorMessage(Object e) {
  if (e is CalculationNoteFormatException) return e.toString();
  if (e is TypeError) return 'Réponse inattendue du serveur (format de données).';
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.response?.statusCode == 403) return 'Action non autorisée pour ce compte.';
    return e.message ?? 'Erreur réseau.';
  }
  return e.toString();
}

class CalculationNoteService {
  CalculationNoteService._();
  static final CalculationNoteService instance = CalculationNoteService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<CalculationNotePage> list(CalculationNoteFilters f) async {
    final res = await _dio.get('/calculation-notes', queryParameters: f.toQuery());
    return CalculationNotePage.fromJson(res.data as Map);
  }

  /// « Validation des notes de calcul » : notes soumises au validateur
  /// connecté (403 pour tout autre compte).
  Future<CalculationNotePage> validationQueue(CalculationNoteFilters f) async {
    final res = await _dio.get('/calculation-notes/validation', queryParameters: f.toQuery());
    return CalculationNotePage.fromJson(res.data as Map);
  }

  Future<CalculationNoteDetail> _post(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  /// Décisions : soumission attendue jointe (le backend refuse une décision
  /// fondée sur une soumission dépassée).
  Future<CalculationNoteDetail> validate(int id, {required int submissionVersion}) =>
      _post('/calculation-notes/$id/validate', {'submissionVersion': submissionVersion});
  Future<CalculationNoteDetail> reject(int id, String commentaire, {required int submissionVersion}) =>
      _post('/calculation-notes/$id/reject', {'commentaire': commentaire, 'submissionVersion': submissionVersion});
  Future<CalculationNoteDetail> cancel(int id, String motif) => _post('/calculation-notes/$id/cancel', {'motif': motif});
  Future<CalculationNoteDetail> resubmit(int id) => _post('/calculation-notes/$id/resubmit', const {});

  /// Affectation : nouvel utilisateur, ou null pour la retirer.
  Future<CalculationNoteDetail> setAssignment(int id, String? userId) async {
    final res = await _dio.put('/calculation-notes/$id/assignment', data: {'assignedToUserId': userId});
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  Future<List<NoteAssignmentEntry>> assignments(int id) async {
    final res = await _dio.get('/calculation-notes/$id/assignments');
    return ((res.data as Map)['data'] as List).map((e) => NoteAssignmentEntry.fromJson(e as Map)).toList();
  }

  /// Suivi des emails de la note (statut d'envoi) et relance des échecs.
  Future<List<NoteEmailStatus>> emailNotifications(int id) async {
    final res = await _dio.get('/calculation-notes/$id/email-notifications');
    return ((res.data as Map)['data'] as List).map((e) => NoteEmailStatus.fromJson(e as Map)).toList();
  }

  Future<int> resendFailedEmails(int id) async {
    final res = await _dio.post('/calculation-notes/$id/email-notifications/resend', data: const {});
    return (((res.data as Map)['data'] as Map)['retried'] as num?)?.toInt() ?? 0;
  }

  Future<CalculationNoteDetail> get(int id) async {
    final res = await _dio.get('/calculation-notes/$id');
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  Future<CalculationNoteOptions> options() async {
    final res = await _dio.get('/calculation-notes/options');
    return CalculationNoteOptions.fromJson((res.data as Map)['data'] as Map);
  }

  FormData _files(List<PendingNoteDocument> docs, Map<String, String> fields) {
    final fd = FormData();
    fields.forEach((k, v) => fd.fields.add(MapEntry(k, v)));
    if (docs.isNotEmpty) {
      fd.fields.add(MapEntry('commentaires', jsonEncode(docs.map((d) => d.comment.text.trim()).toList())));
      fd.fields.add(MapEntry('types', jsonEncode(docs.map((d) => d.documentType).toList())));
      for (final d in docs) {
        fd.files.add(MapEntry('files', MultipartFile.fromBytes(d.bytes, filename: d.name)));
      }
    }
    return fd;
  }

  Future<CalculationNoteDetail> create({
    required String projectId,
    required String requesterId,
    String commentaire = '',
    String? assignedToUserId,
    List<PendingNoteDocument> documents = const [],
  }) async {
    final res = await _dio.post('/calculation-notes',
        data: _files(documents, {
          'projectId': projectId,
          'requesterId': requesterId,
          if (commentaire.trim().isNotEmpty) 'commentaire': commentaire.trim(),
          if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
        }));
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  Future<CalculationNoteDetail> update(int id, {String? requesterId, String? commentaire}) async {
    final res = await _dio.patch('/calculation-notes/$id', data: {
      if (requesterId != null) 'requesterId': requesterId,
      if (commentaire != null) 'commentaire': commentaire,
    });
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  /// Documents complémentaires — réservé à l'utilisateur affecté (backend).
  Future<CalculationNoteDetail> addComplementaryDocuments(int id, List<PendingNoteDocument> documents) async {
    final res = await _dio.post('/calculation-notes/$id/complementary-documents', data: _files(documents, const {}));
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  Future<CalculationNoteDetail> addDocuments(int id, List<PendingNoteDocument> documents) async {
    final res = await _dio.post('/calculation-notes/$id/documents', data: _files(documents, const {}));
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  /// Commentaire, nom et type d'un document (seuls les champs fournis).
  Future<CalculationNoteDetail> updateDocument(int id, String docId, {String? commentaire, String? documentType}) async {
    final res = await _dio.patch('/calculation-notes/$id/documents/$docId', data: {
      if (commentaire != null) 'commentaire': commentaire,
      if (documentType != null) 'documentType': documentType,
    });
    return CalculationNoteDetail.fromJson((res.data as Map)['data'] as Map);
  }

  /// Contenu d'un document (authentifié — jamais une URL publique).
  Future<Uint8List> fetchBytes(NoteDocument doc, {bool inline = false}) async {
    final res = await _dio.get<List<int>>(
      '/calculation-notes/${doc.noteId}/documents/${doc.id}/download',
      queryParameters: inline ? {'inline': '1'} : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  Future<void> download(NoteDocument doc) async {
    final bytes = await fetchBytes(doc);
    await saveNoteFile(bytes, doc.originalName, doc.mimeType);
  }
}
