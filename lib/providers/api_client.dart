import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class ApiClient {
  ApiClient._internal() {
    final envUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    final baseUrl = envUrl.isNotEmpty
        ? envUrl
        : (kIsWeb ? 'http://localhost:4000' : 'http://10.0.2.2:4000');

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final box = GetStorage();
          final token = box.read<String>('accessToken');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;
}
