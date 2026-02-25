import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../providers/api_client.dart';

class DevisApi {
  DevisApi._();
  static final instance = DevisApi._();

  Dio get _dio => ApiClient.instance.dio;

  // ✅ UPLOAD (création)
  Future<Response> uploadDevis({
    required String projectId,
    required String nomDevis,
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      "nomDevis": nomDevis, // ✅ IMPORTANT
      "file": MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _dio.post("/projects/$projectId/devis", data: formData);
  }

  // ✅ UPDATE (nom + fichier optionnel)
  Future<Response> updateDevis({
    required String projectId,
    required String nomDevis,
    Uint8List? bytes,
    String? filename,
  }) async {
    // backend PUT attend multipart (même si pas de fichier, il lit req.body.nomDevis)
    final formData = FormData.fromMap({
      "nomDevis": nomDevis, // ✅ IMPORTANT
      if (bytes != null && filename != null)
        "file": MultipartFile.fromBytes(bytes, filename: filename),
    });

    return _dio.put("/projects/$projectId/devis", data: formData);
  }

  // ✅ Update matricule project
  Future<Response> updateMatricule({
    required String projectId,
    required String matriculeFiscale,
  }) {
    return _dio.put("/projects/$projectId", data: {
      "matriculeFiscale": matriculeFiscale,
    });
  }

  // ✅ GET project
  Future<Map<String, dynamic>> getProject({required String projectId}) async {
    final res = await _dio.get("/projects/$projectId");
    return Map<String, dynamic>.from(res.data);
  }

  // ✅ GET devis by project
  Future<Map<String, dynamic>?> getDevisByProject({required String projectId}) async {
    final res = await _dio.get("/projects/$projectId/devis");
    if (res.data == null) return null;

    // si jamais backend renvoie liste
    if (res.data is List && (res.data as List).isNotEmpty) {
      return Map<String, dynamic>.from((res.data as List).first);
    }

    return Map<String, dynamic>.from(res.data);
  }
}