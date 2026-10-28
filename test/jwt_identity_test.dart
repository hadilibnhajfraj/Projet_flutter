import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/providers/auth_service.dart' show jwtIdentity;

// Jeton de forme JWT (en-tête.contenu.signature) construit pour le test :
// la signature n'est jamais vérifiée côté application (le backend le fait).
String _token(Map<String, dynamic> payload) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  test('identité relue depuis le jeton restauré (id, email, rôle)', () {
    final id = jwtIdentity(_token({
      'sub': 'b4a9bf6f-65f1-4dd7-9a38-bb7a07210641',
      'email': 'Responsable_Production@cbi-tunisia.com',
      'role': 'responsable_logistique_achat',
    }));
    expect(id, isNotNull);
    expect(id!.id, 'b4a9bf6f-65f1-4dd7-9a38-bb7a07210641');
    expect(id.email, 'responsable_production@cbi-tunisia.com');
    expect(id.role, 'responsable_logistique_achat');
  });

  test('jeton illisible ou incomplet : aucune identité (session non restaurée)', () {
    for (final t in ['', 'abc', 'a.b', 'a.b.c', _token({'email': 'x@y.z'}), _token({'sub': 'x'})]) {
      expect(jwtIdentity(t), isNull, reason: t);
    }
  });
}
