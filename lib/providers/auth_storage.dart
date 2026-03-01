import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  AuthStorage._();
  static final instance = AuthStorage._();

  final _storage = const FlutterSecureStorage();

  static const _kToken = "auth_token";
  static const _kExpiry = "auth_expiry_ms"; // epoch ms

  Future<void> saveToken({required String token, required DateTime expiry}) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kExpiry, value: expiry.millisecondsSinceEpoch.toString());
  }

  Future<String?> getToken() => _storage.read(key: _kToken);

  Future<DateTime?> getExpiry() async {
    final v = await _storage.read(key: _kExpiry);
    if (v == null) return null;
    final ms = int.tryParse(v);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kExpiry);
  }
}