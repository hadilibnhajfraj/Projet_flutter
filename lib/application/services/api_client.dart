import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class ApiClient {
  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ✅ Log (utile pour debug)
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
      ),
    );

    // ✅ Inject token automatiquement
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _box.read<String>('accessToken');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  // ✅ IMPORTANT :
  // - Flutter Web => localhost
  // - Android Emulator => 10.0.2.2
  // - Device réel => IP de ton PC (ex: http://192.168.1.xx:4000)
  static String get baseUrl {
    if (kIsWeb) return 'https://api.crmprobar.com';
    return 'https://api.crmprobar.com';
  }

  late final Dio dio;
  final GetStorage _box = GetStorage();
}
