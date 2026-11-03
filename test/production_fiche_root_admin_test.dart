// « Consultation des fiches de production » — Modifier / Supprimer réservés
// au root admin (droit renvoyé par le backend : productionFicheAdmin).
// Le backend reste l'autorité (test/productionFicheRootAdmin.test.js).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/production_dashboard/production_dashboard_routes.dart';
import 'package:dash_master_toolkit/production_records/fiche_edit_session.dart';
import 'package:dash_master_toolkit/production_records/model/production_record_model.dart';
import 'package:dash_master_toolkit/production_records/view/fiche_admin_actions.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

const _uuid = '0b6d2f1e-1111-4a8b-9c3d-000000000001';

ProductionRecordModel _row({String type = 'promesh', bool locked = true, bool archived = false, String? machine = '3', String? poste = 'nuit'}) =>
    ProductionRecordModel(id: '$type:$_uuid', type: type, numero: type == 'promesh' ? 'PROMESH-2026-000042' : 'PROBAR-2026-0B6D2F', machine: machine, poste: poste, isLocked: locked, archived: archived, statut: locked ? 'validee' : 'brouillon');

Future<void> _session(GetStorage box, {required String role, required String email, bool? ficheAdmin, bool readOnly = false}) async {
  await box.write('isLoggedIn', true);
  await box.write('accessToken', 'jeton-de-test');
  await box.write('userRole', role);
  await box.write('userEmail', email);
  await box.write('readOnly', readOnly);
  if (ficheAdmin == null) {
    await box.remove('productionFicheAdmin');
  } else {
    await box.write('productionFicheAdmin', ficheAdmin);
  }
}

void main() {
  late GetStorage box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('fiche_root_admin_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
    await GetStorage.init();
    box = GetStorage();
  });

  group('droit renvoyé par le backend (jamais déduit de l’adresse)', () {
    test('root admin : productionFicheAdmin = true → actions', () async {
      await _session(box, role: 'superadmin', email: 'cbitunisia@cbi-tunisia.com', ficheAdmin: true);
      expect(AuthService().canManageAllProductionFiches, isTrue);
    });

    test('même adresse sans le droit du serveur : aucune action', () async {
      await _session(box, role: 'superadmin', email: 'cbitunisia@cbi-tunisia.com', ficheAdmin: null);
      expect(AuthService().canManageAllProductionFiches, isFalse);
    });

    test('back-office, autre superadmin, production : aucune action', () async {
      for (final (role, email) in [('backoffice_readonly', 'backoffice@cbi-tunisia.com'), ('superadmin', 'bayrem@gmail.com'), ('responsable_logistique_achat', 'production_1@cbi-tunisia.com')]) {
        await _session(box, role: role, email: email, ficheAdmin: false, readOnly: role == 'backoffice_readonly');
        expect([email, AuthService().canManageAllProductionFiches], [email, false]);
        expect(FicheAdminActions.of(_row(), isFicheAdmin: AuthService().canManageAllProductionFiches).visible, isFalse);
      }
    });

    test('déconnexion : droit effacé', () async {
      await _session(box, role: 'superadmin', email: 'cbitunisia@cbi-tunisia.com', ficheAdmin: true);
      await AuthService().logout();
      expect(box.read('productionFicheAdmin'), isNull);
      expect(AuthService().canManageAllProductionFiches, isFalse);
    });
  });

  group('actions par fiche', () {
    test('fiche validée PROMESH : Modifier (écran de saisie existant) et Supprimer', () {
      final a = FicheAdminActions.of(_row(), isFicheAdmin: true);
      expect([a.visible, a.canEdit, a.canDelete], [true, true, true]);
      expect(a.editRoute, '/production/promesh/machine/3/poste/nuit/modules?ficheId=$_uuid');
    });

    test('fiche validée PROBAR : même chose, grille PROBAR', () {
      final a = FicheAdminActions.of(_row(type: 'probar', machine: '1', poste: 'matin'), isFicheAdmin: true);
      expect([a.canEdit, a.canDelete], [true, true]);
      expect(a.editRoute, '/production/probar/machine/1/poste/matin/modules?ficheId=$_uuid');
    });

    test('fiche archivée : ni Modifier ni Supprimer, raison affichée', () {
      final a = FicheAdminActions.of(_row(archived: true), isFicheAdmin: true);
      expect([a.visible, a.canEdit, a.canDelete], [true, false, false]);
      expect(a.blockedReason, contains('archivée'));
    });

    test('machine / équipe absentes : Supprimer seulement (la grille de saisie en a besoin)', () {
      final a = FicheAdminActions.of(_row(poste: null), isFicheAdmin: true);
      expect([a.canEdit, a.canDelete], [false, true]);
      expect(ProdPaths.ficheEdit(compositeId: 'promesh:', type: 'promesh', machine: '1', poste: 'matin'), isNull);
    });

    test('consultation : champ archived lu depuis l’API', () {
      expect(ProductionRecordModel.fromJson({'id': 'promesh:x', 'type': 'promesh', 'archived': true}).archived, isTrue);
      expect(ProductionRecordModel.fromJson({'id': 'promesh:x', 'type': 'promesh'}).archived, isFalse);
    });
  });

  group('bouton Modifier : mode modification d’une fiche existante', () {
    test('verrouillage : bloque Modifier / Supprimer pour tous sauf le root admin', () async {
      await _session(box, role: 'superadmin', email: 'cbitunisia@cbi-tunisia.com', ficheAdmin: true);
      expect([ficheLockBlocksWrite(true), ficheLockBlocksWrite(false)], [false, false]);
      for (final (role, email) in [('superadmin', 'bayrem@gmail.com'), ('responsable_logistique_achat', 'production_1@cbi-tunisia.com'), ('backoffice_readonly', 'backoffice@cbi-tunisia.com')]) {
        await _session(box, role: role, email: email, ficheAdmin: false, readOnly: role == 'backoffice_readonly');
        expect([email, ficheLockBlocksWrite(true), ficheLockBlocksWrite(false)], [email, true, false]); // règle d’avant, inchangée
      }
    });

    test('root admin : session ouverte sur l’ID RÉEL de la fiche, retour à la liste d’origine', () async {
      await _session(box, role: 'superadmin', email: 'cbitunisia@cbi-tunisia.com', ficheAdmin: true);
      FicheEditSession.start('promesh:$_uuid', returnTo: '/production/records');
      expect(FicheEditSession.isEditing(_uuid), isTrue); // préfixe composite retiré
      expect(FicheEditSession.isEditing('PROMESH-2026-000042'), isFalse); // jamais le numéro d’affichage
      expect(FicheEditSession.returnRouteFor(_uuid), '/production/records');
      expect(FicheEditSession.end(_uuid), '/production/records');
      expect(FicheEditSession.isEditing(_uuid), isFalse); // fermée après « Terminer la modification »
    });

    test('autres comptes : aucune session (parcours de saisie inchangé)', () async {
      for (final email in ['bayrem@gmail.com', 'production_1@cbi-tunisia.com']) {
        await _session(box, role: 'superadmin', email: email, ficheAdmin: false);
        FicheEditSession.start(_uuid, returnTo: '/production/records');
        expect([email, FicheEditSession.isEditing(_uuid)], [email, false]);
      }
    });

    test('route de modification : grille de saisie du BON type, par l’ID réel (PROBAR, PROMESH 1-2-3, PROMESH 4)', () {
      expect(ProdPaths.ficheEdit(compositeId: 'probar:$_uuid', type: 'probar', machine: '2', poste: 'matin'), '/production/probar/machine/2/poste/matin/modules?ficheId=$_uuid');
      for (final m in ['1', '2', '3', '4']) {
        expect(ProdPaths.ficheEdit(compositeId: 'promesh:$_uuid', type: 'promesh', machine: m, poste: 'nuit'), '/production/promesh/machine/$m/poste/nuit/modules?ficheId=$_uuid');
      }
    });
  });

  group('confirmation de suppression', () {
    testWidgets('affiche le numéro, le type et l’avertissement « irréversible »', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => confirmFicheDeletion(context, _row()), child: const Text('go'))))),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fiche-delete-dialog')), findsOneWidget);
      expect(find.text('PROMESH-2026-000042'), findsOneWidget);
      expect(find.text('PROMESH'), findsOneWidget);
      expect(find.textContaining('irréversible'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Confirmer la suppression'), findsOneWidget);
    });

    testWidgets('Confirmer la suppression → true ; Annuler → false', (tester) async {
      for (final (key, expected) in [('fiche-delete-confirm', true), ('fiche-delete-cancel', false)]) {
        bool? result;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () async => result = await confirmFicheDeletion(context, _row(type: 'probar')), child: const Text('go'))))),
        ));
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('PROBAR'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect([key, result], [key, expected]);
      }
    });
  });
}
