import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/core/config/logistics_managers.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_pending_prompt.dart' show kRawMaterialValidatorEmails;

void main() {
  test('responsables logistique et production : mêmes droits, liste unique', () {
    expect(kLogisticsManagerEmails, {'responsable_logistique@cbi-tunisia.com', 'responsable_production@cbi-tunisia.com'});
    expect(isLogisticsManagerEmail('responsable_production@cbi-tunisia.com'), isTrue);
    expect(isLogisticsManagerEmail('  Responsable_Production@CBI-tunisia.com '), isTrue);
    expect(isLogisticsManagerEmail('responsable_logistique@cbi-tunisia.com'), isTrue);
    // Popup / page des demandes à valider : même liste.
    expect(identical(kRawMaterialValidatorEmails, kLogisticsManagerEmails), isTrue);
  });

  test('jamais les comptes de production (même rôle) ni le Super Admin', () {
    for (final e in [
      'production_1@cbi-tunisia.com',
      'production_2@cbi-tunisia.com',
      'production_3@cbi-tunisia.com',
      'production_4@cbi-tunisia.com',
      'production_5@cbi-tunisia.com',
      'cbitunisia@cbi-tunisia.com',
      null,
      '',
    ]) {
      expect(isLogisticsManagerEmail(e), isFalse, reason: '$e');
    }
  });
}
