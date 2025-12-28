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

  // ✅ infos user stockées
  String? get userId => _box.read<String>('userId');
  String? get userEmail => _box.read<String>('userEmail');
  String? get userRole => _box.read<String>('userRole');

  // ✅ Signup : création de compte seulement
  Future<void> signup({required String email, required String password}) async {
    await ApiClient.instance.dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
    });
  }

  // ✅ Signin : connexion + stockage token + user
  Future<void> signin({required String email, required String password}) async {
    final res = await ApiClient.instance.dio.post('/auth/signin', data: {
      'email': email,
      'password': password,
    });

    final token = res.data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('accessToken manquant');
    }

    // ✅ token
    _box.write('accessToken', token);
    _box.write('isLoggedIn', true);

    // ✅ user (adapter selon ta réponse backend)
    // Exemple backend:
    // { accessToken: "...", user: { id: "1", email: "...", role: "admin" } }
    final user = res.data['user'];
    if (user != null) {
      _box.write('userId', (user['id'] ?? '').toString());
      _box.write('userEmail', (user['email'] ?? '').toString());
      _box.write('userRole', (user['role'] ?? '').toString());
    } else {
      // fallback si backend renvoie direct email/role
      if (res.data['email'] != null) _box.write('userEmail', res.data['email']);
      if (res.data['role'] != null) _box.write('userRole', res.data['role']);
      if (res.data['id'] != null) _box.write('userId', res.data['id'].toString());
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _box.remove('accessToken');
    _box.remove('userId');
    _box.remove('userEmail');
    _box.remove('userRole');
    _box.write('isLoggedIn', false);
    notifyListeners();
  }
}
