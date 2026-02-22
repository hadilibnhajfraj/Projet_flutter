// lib/providers/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._internal() {
    final envUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');

    final baseUrl = envUrl.isNotEmpty
        ? envUrl
        : (kIsWeb ? 'https://api.crmprobar.com' : 'https://api.crmprobar.com');

    _box = GetStorage();

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // ✅ Token depuis GetStorage
          final token = _box.read<String>('accessToken');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // ✅ IMPORTANT (Web) pour cookies refresh si backend envoie Set-Cookie
          // (Dio web supporte ça via extra/Options)
          if (kIsWeb) {
            options.extra['withCredentials'] = true;
          }

          if (kDebugMode) {
            debugPrint("➡️ [${options.method}] ${options.baseUrl}${options.path}");
            debugPrint("Headers: ${options.headers}");
            if (options.data != null) debugPrint("Body: ${options.data}");
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint("✅ Response [${response.statusCode}] ${response.requestOptions.path}");
            debugPrint("Data: ${response.data}");
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            debugPrint("❌ DioError: ${e.message}");
            if (e.response != null) {
              debugPrint("Status: ${e.response?.statusCode}");
              debugPrint("Data: ${e.response?.data}");
            }
          }

          // ✅ si 401 => clear session
          final status = e.response?.statusCode;
          if (status == 401) {
            await clearAuth();
          }

          return handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  late final GetStorage _box;

  Dio get dio => _dio;

  // =====================================================
  // ✅ Helpers Token
  // =====================================================
  String? getAccessToken() => _box.read<String>('accessToken');

  Future<void> setAccessToken(String token) async {
    await _box.write('accessToken', token);
    await _box.write('isLoggedIn', true);
  }

  // =====================================================
  // ✅ Clear Auth (GetStorage + SharedPreferences)
  // =====================================================
  Future<void> clearAuth() async {
    // GetStorage
    await _box.remove('accessToken');
    await _box.write('isLoggedIn', false);
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');

    // SharedPreferences (si tu l’utilises ailleurs)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    await prefs.remove("token");
  }
}
