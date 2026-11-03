// Compte back-office en consultation seule (backoffice_readonly) — côté
// Flutter (VM). Le backend reste l'autorité (403 sur toute écriture,
// test/backofficeReadOnly.test.js) ; ici : règles locales, session, garde-fou
// d'ApiClient (aucune écriture n'est envoyée) et profil affiché.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/app_shell_route/components/topbar/read_only_profile_badge.dart';
import 'package:dash_master_toolkit/core/config/read_only_access.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

/// Transport simulé : enregistre chaque requête RÉELLEMENT envoyée.
class _Recorder implements HttpClientAdapter {
  final sent = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    sent.add('${o.method} ${o.path}');
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _session(GetStorage box, {required String role, bool? readOnly, String? reference}) async {
  // Mêmes clés que AuthService._persistSession.
  await box.write('isLoggedIn', true);
  await box.write('accessToken', 'jeton-de-test');
  await box.write('userRole', role);
  await box.write('userEmail', role == kBackofficeReadOnlyRole ? 'backoffice@cbi-tunisia.com' : 'info@probardistribution.com');
  if (readOnly == null) {
    await box.remove('readOnly');
  } else {
    await box.write('readOnly', readOnly);
  }
  if (reference == null) {
    await box.remove('referenceEmail');
  } else {
    await box.write('referenceEmail', reference);
  }
}

void main() {
  late GetStorage box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('backoffice_ro_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    // Stockage sécurisé (jetons) : sans implémentation en VM.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
    await GetStorage.init();
    box = GetStorage();
  });

  group('règles locales (mêmes que le backend)', () {
    test('compte en consultation : rôle dédié ou drapeau du backend', () {
      expect(isReadOnlyAccount(role: 'backoffice_readonly'), isTrue);
      expect(isReadOnlyAccount(role: ' BACKOFFICE_READONLY '), isTrue);
      expect(isReadOnlyAccount(role: 'commercial', readOnlyFlag: true), isTrue);
      expect(isReadOnlyAccount(role: 'commercial'), isFalse);
      expect(isReadOnlyAccount(role: 'superadmin', readOnlyFlag: false), isFalse);
    });

    test('Notes de calcul : Valider / Refuser permis, rien d’autre', () {
      for (final p in ['/calculation-notes/12/validate', '/calculation-notes/12/reject', 'https://api.crmprobar.com/calculation-notes/7/VALIDATE/']) {
        expect(readOnlyBlocksRequest('POST', p), isFalse, reason: p);
      }
      for (final (m, p) in [
        ('POST', '/calculation-notes'),
        ('POST', '/calculation-notes/12/cancel'),
        ('POST', '/calculation-notes/12/resubmit'),
        ('POST', '/calculation-notes/12/documents'),
        ('POST', '/calculation-notes/12/complementary-documents'),
        ('PUT', '/calculation-notes/12/assignment'),
        ('PATCH', '/calculation-notes/12/validate'),
        ('POST', '/calculation-notes/12/validate/extra'),
        ('POST', '/calculation-notes/abc/validate'),
        ('POST', '/production-fiche-approvals/promesh/1/approve'),
      ]) {
        expect(readOnlyBlocksRequest(m, p), isTrue, reason: '$m $p');
      }
    });

    test('écritures bloquées, lectures et authentification du compte permises', () {
      for (final m in ['GET', 'HEAD', 'OPTIONS']) {
        expect(readOnlyBlocksRequest(m, '/projects'), isFalse, reason: m);
      }
      for (final (m, p) in [('POST', '/projects'), ('PUT', '/projects/1'), ('PATCH', '/raw-material-requests/1/status'), ('DELETE', '/commercial-contacts/1'), ('POST', '/production-fiche-approvals/promesh/1/approve'), ('POST', '/auth/signup'), ('POST', '/PROJECTS/')]) {
        expect(readOnlyBlocksRequest(m, p), isTrue, reason: '$m $p');
      }
      for (final p in ['/auth/signin', '/auth/refresh', '/auth/logout', '/auth/forgot-password', '/auth/reset-password', 'https://api.crmprobar.com/auth/signin', '/AUTH//signin/']) {
        expect(readOnlyBlocksRequest('POST', p), isFalse, reason: p);
      }
    });
  });

  group('session et interface', () {
    test('back-office : consultation seule, écrans du compte de référence (commercial)', () async {
      await _session(box, role: 'backoffice_readonly', readOnly: true, reference: 'info@probardistribution.com');
      final a = AuthService();
      expect(a.isReadOnly, isTrue);
      expect(a.usesCommercialScreens, isTrue); // menus de consultation commerciaux
      expect(a.userRole, 'backoffice_readonly'); // rôle réel inchangé
      expect(a.normalizedRole, 'backoffice_readonly'); // jamais converti en commercial
      expect(a.readOnlyReferenceEmail, 'info@probardistribution.com');
      expect(a.canViewCommercialKpi, isTrue);
      expect(a.isAdmin, isFalse);
    });

    test('autres comptes : aucun changement (rôle réel, pas de consultation seule)', () async {
      for (final role in ['commercial', 'superadmin', 'responsable_logistique_achat', 'user']) {
        await _session(box, role: role);
        expect([role, AuthService().isReadOnly, AuthService().normalizedRole, AuthService().usesCommercialScreens], [role, false, role, role == 'commercial']);
      }
    });

    test('déconnexion : drapeau de consultation et compte de référence effacés', () async {
      await _session(box, role: 'backoffice_readonly', readOnly: true, reference: 'info@probardistribution.com');
      await box.write('grantedPermissions', [kProductionReadAll]);
      await AuthService().logout();
      expect(box.read('readOnly'), isNull);
      expect(box.read('referenceEmail'), isNull);
      expect(box.read('grantedPermissions'), isNull);
      expect(AuthService().isReadOnly, isFalse);
      expect(AuthService().canConsultProductionReadOnly, isFalse);
    });

    test('Production : production.read_all renvoyé par le backend → consultation ; identité jamais remplacée', () async {
      await _session(box, role: 'backoffice_readonly', readOnly: true, reference: 'info@probardistribution.com');
      await box.write('grantedPermissions', [kProductionReadAll]);
      final a = AuthService();
      expect(a.hasPermission(kProductionReadAll), isTrue);
      expect(a.canConsultProductionReadOnly, isTrue);
      expect(a.userRole, 'backoffice_readonly'); // identité réelle
      expect(a.usesCommercialScreens, isTrue); // contacts commerciaux inchangés
      expect(a.canViewCommercialKpi, isTrue);
    });

    test('Production : menus et écrans conservés même sans `granted` (serveur pas encore à jour, ancienne session)', () async {
      await _session(box, role: 'backoffice_readonly', readOnly: true, reference: 'info@probardistribution.com');
      await box.remove('grantedPermissions');
      expect(AuthService().canConsultProductionReadOnly, isTrue);
      await box.write('grantedPermissions', <String>['autre.permission']);
      expect(AuthService().canConsultProductionReadOnly, isTrue);
      // Un compte non back-office ne passe jamais par cette consultation.
      await _session(box, role: 'commercial');
      await box.write('grantedPermissions', [kProductionReadAll]);
      expect(AuthService().canConsultProductionReadOnly, isFalse);
      await box.remove('grantedPermissions');
    });
  });

  group('ApiClient : aucune écriture envoyée par un compte en consultation', () {
    late _Recorder recorder;
    setUp(() {
      recorder = _Recorder();
      ApiClient.instance.dio.httpClientAdapter = recorder;
    });

    test('back-office : écritures rejetées localement (403), lectures envoyées', () async {
      await _session(box, role: 'backoffice_readonly', readOnly: true);
      final dio = ApiClient.instance.dio;
      for (final call in <Future<Response> Function()>[
        () => dio.post('/projects', data: {'name': 'x'}),
        () => dio.put('/commercial-contacts/1', data: {}),
        () => dio.patch('/raw-material-requests/1/status', data: {'status': 'VALIDATED'}),
        () => dio.delete('/commercial-contacts/1'),
        () => dio.post('/production-fiche-approvals/promesh/1/approve'),
      ]) {
        await expectLater(
          call(),
          throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statut', 403).having((e) => (e.response?.data as Map)['code'], 'code', 'READ_ONLY_ACCOUNT')),
        );
      }
      expect(recorder.sent, isEmpty); // rien n'est parti sur le réseau
      // Exception : décision sur une note de calcul (le backend revérifie).
      await dio.post('/calculation-notes/7/reject', data: {'commentaire': 'Motif'});
      expect(recorder.sent, ['POST /calculation-notes/7/reject']);
      recorder.sent.clear();
      await dio.get('/commercial-contacts');
      await dio.post('/auth/logout');
      expect(recorder.sent, ['GET /commercial-contacts', 'POST /auth/logout']);
    });

    test('autres comptes : écritures envoyées normalement (aucune régression)', () async {
      await _session(box, role: 'commercial');
      await ApiClient.instance.dio.post('/projects', data: {'name': 'x'});
      expect(recorder.sent, ['POST /projects']);
    });
  });

  testWidgets('profil affiché : « Back-office — Consultation uniquement »', (tester) async {
    await _session(box, role: 'backoffice_readonly', readOnly: true, reference: 'info@probardistribution.com');
    tester.view.physicalSize = const Size(1280, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: ReadOnlyProfileBadge()))));
    expect(find.text('Back-office — Consultation uniquement'), findsOneWidget);
    expect(find.byTooltip('Aucune création, modification ou suppression.\nVisibilité de info@probardistribution.com'), findsOneWidget);
  });
}
