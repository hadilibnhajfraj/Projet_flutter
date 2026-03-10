import 'package:dio/dio.dart';
import 'package:dash_master_toolkit/application/users/model/commercial_contact_models.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
// ⚠️ adapte selon ton projet (baseUrl + headers token)
class CommercialContactApi {
  CommercialContactApi._();
  static final instance = CommercialContactApi._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://localhost:4000", // ✅ change to your API
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  // ✅ Remplace par ta fonction authHeaders() si tu l'as déjà
 Map<String, String> _authHeaders() {
    final token = AuthService().accessToken ?? "";
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
  }

  Future<Map<String, dynamic>> createContact(CommercialContactCreateDto dto) async {
    final res = await _dio.post(
      "/commercial-contacts",
      data: dto.toJson(),
      options: Options(headers: _authHeaders()),
    );

    return Map<String, dynamic>.from(res.data);
  }
}