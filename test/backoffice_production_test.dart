// Module Production — compte back-office en consultation seule : écrans
// accessibles (liste blanche) et droit d'écriture sur les fiches. Le backend
// reste l'autorité (test/backofficeProduction.test.js côté serveur).

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/core/config/read_only_access.dart';
import 'package:dash_master_toolkit/production_records/model/production_fiche_list.dart';
import 'package:dash_master_toolkit/production_records/view/production_fiches_list_screen.dart' show ficheCanWrite;

void main() {
  group('écrans Production ouverts au back-office', () {
    test('consultation : listes, détails, récapitulatifs, vue centralisée, historique', () {
      for (final path in [
        '/production/probar/fiches',
        '/por-promesh/list',
        '/production/probar-summary',
        '/production/promesh-summary',
        '/production/records',
        '/por-promesh/historique',
        '/por-promesh/detail',
        '/production/probar/machine/3/poste/nuit/detail',
        '/Production/Records/', // normalisation (casse, barre finale)
      ]) {
        expect(readOnlyProductionRouteAllowed(path), isTrue, reason: path);
      }
      expect(readOnlyProductionRouteAllowed(kReadOnlyProductionHome), isTrue);
    });

    test('saisie et validation : jamais accessibles', () {
      for (final path in [
        '/production',
        '/production/dashboard',
        '/production/promesh',
        '/production/promesh/machine/1',
        '/production/promesh/machine/1/poste/matin',
        '/production/promesh/machine/1/poste/matin/modules',
        '/production/probar/machine/1/poste/matin/modules/rendement',
        '/production/probar/form',
        '/production/validation-fiches',
        '/production/matieres-premieres',
        '/por-promesh/dashboard',
        '/production/probar/machine/1/poste/matin/detail/x',
      ]) {
        expect(readOnlyProductionRouteAllowed(path), isFalse, reason: path);
      }
    });
  });

  group('droit d’écriture sur une fiche (Modifier / Supprimer)', () {
    final row = FicheListRow.fromJson({'id': 'promesh:abc', 'type': 'promesh', 'createdBy': 'u-1'});

    test('back-office : jamais, même sur une fiche non verrouillée', () {
      expect(ficheCanWrite(row, role: kBackofficeReadOnlyRole, userId: 'u-1'), isFalse);
    });

    test('autres rôles inchangés', () {
      expect(ficheCanWrite(row, role: 'admin', userId: 'x'), isTrue);
      expect(ficheCanWrite(row, role: 'responsable_logistique_achat', userId: 'u-1'), isTrue);
      expect(ficheCanWrite(row, role: 'responsable_logistique_achat', userId: 'u-2'), isFalse);
    });
  });
}
