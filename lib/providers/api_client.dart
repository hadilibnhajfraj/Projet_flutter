import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._internal() {
    final envUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');

    final baseUrl = envUrl.isNotEmpty
        ? envUrl
        : (kIsWeb ? 'http://localhost:4000' : 'http://10.0.2.2:4000');

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
        // ✅ Laisse Dio throw sur 400/500 (par défaut)
        // validateStatus: (status) => status != null && status < 300,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _box.read<String>('accessToken');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
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
            await _box.remove('accessToken');
            await _box.write('isLoggedIn', false);
            await _box.remove('userId');
            await _box.remove('userEmail');
            await _box.remove('userRole');
          }

          return handler.next(e);
        },
      ),
    );
  }
  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    await prefs.remove("token");

    // si tu utilises localStorage web:
    // html.window.localStorage.remove("accessToken");
  }
  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  late final GetStorage _box;

  Dio get dio => _dio;
}
