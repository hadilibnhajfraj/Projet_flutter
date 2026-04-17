import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'api_client.dart';
import 'auth_storage.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final GetStorage _box = GetStorage();
void setUserName(String name) {
  _box.write("user_nom", name);
}

String? getUserName() {
  return _box.read("user_nom");
}
String get displayName {
  return getUserName() ??
      userEmail ??
      "Unknown";
}
  bool get isLoggedIn => _box.read<bool>('isLoggedIn') ?? false;
  String? get accessToken => _box.read<String>('accessToken');

  String? get userId => _box.read<String>('userId');
  String? get userEmail => _box.read<String>('userEmail');
  String? get userRole => _box.read<String>('userRole');
  // Ajouter à la fin de AuthService (avant la fin de la classe)
bool get isAdmin => userRole?.toLowerCase() == 'admin';
bool get isAgent => userRole?.toLowerCase() == 'agent';
bool get isClient => userRole?.toLowerCase() == 'client';
  // ---------------- SIGNUP ----------------
  Future<void> signup({required String email, required String password}) async {
    await ApiClient.instance.dio.post('/auth/signup', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }
Future<List<String>> getUserNames() async {
  final response = await ApiClient.instance.dio.get(
    "/commercial-contacts/user-names/list",
  );

  return List<String>.from(response.data);
}
  // ---------------- SIGNIN (7 days session) ----------------
  Future<void> signin({required String email, required String password}) async {
    // ✅ reset session avant tentative
    await _box.write('isLoggedIn', false);
    await _box.remove('accessToken');
    await _box.remove('tokenExpiryMs');
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');

    try {
      final res = await ApiClient.instance.dio.post('/auth/signin', data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      });

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

      // ✅ expiry local = 7 jours (même si backend ne renvoie pas exp)
      final expiry = DateTime.now().add(const Duration(days: 7));

      // ✅ stockage sécurisé
      await AuthStorage.instance.saveToken(token: token, expiry: expiry);

      // ✅ (optionnel) garder un mirror dans GetStorage
      await _box.write('accessToken', token);
      await _box.write('tokenExpiryMs', expiry.millisecondsSinceEpoch);
      await _box.write('isLoggedIn', true);

      // ✅ stock user
      final user = res.data['user'];
      if (user is Map) {
        await _box.write('userId', (user['id'] ?? '').toString());
        await _box.write('userEmail', (user['email'] ?? '').toString());
        await _box.write('userRole', (user['role'] ?? '').toString());
      }

      // ✅ set token in dio header
      ApiClient.instance.setToken(token);

      notifyListeners();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Erreur de connexion');

      await _cleanupSession();
      throw Exception(msg);
    } catch (e) {
      await _cleanupSession();
      rethrow;
    }
  }

  // ---------------- RESTORE SESSION (auto login) ----------------
  Future<bool> restoreSession() async {
    try {
      final token = await AuthStorage.instance.getToken();
      final expiry = await AuthStorage.instance.getExpiry();

      if (token == null || expiry == null) {
        await _cleanupSession();
        return false;
      }

      // ✅ expiré => logout
      if (DateTime.now().isAfter(expiry)) {
        await _cleanupSession();
        return false;
      }

      // ✅ session OK
      ApiClient.instance.setToken(token);

      await _box.write('accessToken', token);
      await _box.write('tokenExpiryMs', expiry.millisecondsSinceEpoch);
      await _box.write('isLoggedIn', true);

      notifyListeners();
      return true;
    } catch (_) {
      await _cleanupSession();
      return false;
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await _cleanupSession();
    notifyListeners();
  }

  // ---------------- FORGOT PASSWORD ----------------
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

  // ---------------- RESET PASSWORD ----------------
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

  // ---------------- PRIVATE: CLEANUP ----------------
  Future<void> _cleanupSession() async {
    await AuthStorage.instance.clear(); // ✅ secure storage

    await _box.write('isLoggedIn', false);
    await _box.remove('accessToken');
    await _box.remove('tokenExpiryMs');
    await _box.remove('userId');
    await _box.remove('userEmail');
    await _box.remove('userRole');

    ApiClient.instance.clearToken(); // ✅ remove Authorization header
  }
}