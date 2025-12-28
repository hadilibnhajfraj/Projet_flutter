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

  // ✅ Signup : création de compte seulement
  Future<void> signup({required String email, required String password}) async {
    await ApiClient.instance.dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
    });
  }

  // ✅ Signin : connexion + stockage du token
  Future<void> signin({required String email, required String password}) async {
  try {
    final res = await ApiClient.instance.dio.post('/auth/signin', data: {
      'email': email,
      'password': password,
    });

    final token = res.data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('accessToken manquant');
    }

    _box.write('accessToken', token);
    _box.write('isLoggedIn', true);
    notifyListeners();
  } catch (e) {
    rethrow;
  }
}


  Future<void> logout() async {
    _box.remove('accessToken');
    _box.write('isLoggedIn', false);
    notifyListeners();
  }
}
