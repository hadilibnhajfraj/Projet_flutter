import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final GetStorage _box = GetStorage();

  bool get isLoggedIn => _box.read<bool>('isLoggedIn') ?? false;
  String? get accessToken => _box.read<String>('accessToken');

  String? get userId => _box.read<String>('userId');
  String? get userEmail => _box.read<String>('userEmail');
  String? get userRole => _box.read<String>('userRole');

  Future<void> signup({required String email, required String password}) async {
    await ApiClient.instance.dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
    });
  }

  Future<void> signin({required String email, required String password}) async {
  // ✅ reset session avant tentative
  await _box.write('isLoggedIn', false);
  await _box.remove('accessToken');
  await _box.remove('userId');
  await _box.remove('userEmail');
  await _box.remove('userRole');

  try {
    final res = await ApiClient.instance.dio.post('/auth/signin', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    // ✅ IMPORTANT: au cas où validateStatus accepte 400/500
    final status = res.statusCode ?? 0;
    if (status >= 400) {
      final data = res.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Erreur de connexion';
      throw Exception(msg);
    }

    final token = res.data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('accessToken manquant');
    }

    // ✅ stock token + user
    await _box.write('accessToken', token);
    await _box.write('isLoggedIn', true);

    final user = res.data['user'];
    if (user is Map) {
      await _box.write('userId', (user['id'] ?? '').toString());
      await _box.write('userEmail', (user['email'] ?? '').toString());
      await _box.write('userRole', (user['role'] ?? '').toString());
    }

    notifyListeners();
  } on DioException catch (e) {
    // ✅ backend error (si Dio throw)
    final data = e.response?.data;
    final msg = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : (e.message ?? 'Erreur de connexion');

    // ✅ assure nettoyage
    await _box.write('isLoggedIn', false);
    await _box.remove('accessToken');
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');

    throw Exception(msg);
  } catch (e) {
    // ✅ autres erreurs (par ex: accessToken manquant)
    await _box.write('isLoggedIn', false);
    await _box.remove('accessToken');
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');

    rethrow;
  }
}


  Future<void> logout() async {
    await _box.remove('accessToken');
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');
    await _box.write('isLoggedIn', false);
    notifyListeners();
  }
    Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final res = await ApiClient.instance.dio.post('/auth/forgot-password', data: {
      'email': email.trim().toLowerCase(),
    });

    final status = res.statusCode ?? 0;
    if (status >= 400) {
      final data = res.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Erreur forgot password';
      throw Exception(msg);
    }

    return (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final res = await ApiClient.instance.dio.post('/auth/reset-password', data: {
      'email': email.trim().toLowerCase(),
      'token': token,
      'newPassword': newPassword,
    });

    final status = res.statusCode ?? 0;
    if (status >= 400) {
      final data = res.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Erreur reset password';
      throw Exception(msg);
    }

    return (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : Map<String, dynamic>.from(res.data);
  }

}
