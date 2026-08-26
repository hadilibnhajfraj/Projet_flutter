// test/finance_unit_diameter_normalization_test.dart
//
// §CORRECTION EXTRACTION — SÉPARATION UNITÉ / DIAMÈTRE (§12 TEST
// OBLIGATOIRE) — tests unitaires PURS (aucun widget) de
// normalizeFinanceUnit(), l'utilitaire CENTRAL (§11) consommé par
// FinanceShipmentItemModel/FinanceInvoiceItemModel.displayUnit/
// displayDiameter — donc par le tableau, le détail ET l'export Excel à la
// fois (une seule logique, jamais dupliquée).

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/finance/model/finance_models.dart';

void main() {
  group('normalizeFinanceUnit — valeurs fusionnées (§1/§7)', () {
    final cases = <String, (String, String)>{
      'M² 10': ('M²', '10'),
      'ML 04': ('ML', '04'),
      'ML 08': ('ML', '08'),
      'ML 12': ('ML', '12'),
      'M² 06': ('M²', '06'),
      'ML 05': ('ML', '05'),
      'M² 08': ('M²', '08'),
    };

    cases.forEach((input, expected) {
      test('"$input" -> Unit="${expected.$1}", Diameter="${expected.$2}"', () {
        final result = normalizeFinanceUnit(input, null);
        expect(result.unit, expected.$1);
        // §4 : le zéro initial n'est JAMAIS retiré ("04" ne devient jamais "4").
        expect(result.diameter, expected.$2);
      });
    });
  });

  group('normalizeFinanceUnit — unités sans diamètre (§2)', () {
    for (final unit in ['ML', 'KG', 'LITRE', 'M²', 'M2', 'TONNE', 'PIECE', 'UNITE']) {
      test('"$unit" (seul) -> Unit="$unit", Diameter="" (jamais inventé)', () {
        final result = normalizeFinanceUnit(unit, null);
        expect(result.unit, unit);
        expect(result.diameter == null || result.diameter!.isEmpty, isTrue);
      });
    }
  });

  group('normalizeFinanceUnit — déjà correctement séparé (§6/§8)', () {
    test('Unit="M²", Diameter="08" -> inchangé, jamais reconstruit en "M² 08"', () {
      final result = normalizeFinanceUnit('M²', '08');
      expect(result.unit, 'M²');
      expect(result.diameter, '08');
    });
  });

  group('normalizeFinanceUnit — cas limites', () {
    test('préfixe non reconnu devant un nombre -> jamais séparé à tort', () {
      final result = normalizeFinanceUnit('XYZ 10', null);
      expect(result.unit, 'XYZ 10');
      expect(result.diameter, isNull);
    });

    test('null -> null', () {
      final result = normalizeFinanceUnit(null, null);
      expect(result.unit, isNull);
      expect(result.diameter, isNull);
    });
  });

  group('FinanceShipmentItemModel.displayUnit/displayDiameter (§9-11)', () {
    test('unit fusionné dans les données brutes -> séparé à la lecture, sans toucher aux autres champs', () {
      const item = FinanceShipmentItemModel(
        id: 'x',
        reference: '00200003',
        designation: 'PROBAR EN ARMATURE SF',
        unit: 'ML 04',
        quantity: 24,
      );
      expect(item.displayUnit, 'ML');
      expect(item.displayDiameter, '04');
      // §5 : reference/designation/quantity jamais modifiés.
      expect(item.reference, '00200003');
      expect(item.designation, 'PROBAR EN ARMATURE SF');
      expect(item.quantity, 24);
    });

    test('unit/diameter déjà séparés en base -> inchangés', () {
      const item = FinanceShipmentItemModel(id: 'x', unit: 'M²', diameter: '08');
      expect(item.displayUnit, 'M²');
      expect(item.displayDiameter, '08');
    });
  });

  group('FinanceInvoiceItemModel.displayUnit/displayDiameter (§9-11)', () {
    test('unit fusionné -> séparé à la lecture', () {
      const item = FinanceInvoiceItemModel(id: 'x', unit: 'M² 10');
      expect(item.displayUnit, 'M²');
      expect(item.displayDiameter, '10');
    });
  });
}
