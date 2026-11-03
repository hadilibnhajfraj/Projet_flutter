// /commercial-contacts/my-kpi et /kpi : le backend renvoie
// { success: true, data: { totalContacts, ... } } — les indicateurs sont lus
// dans `data` (et un ancien format à plat reste accepté).

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/application/users/model/commercial_analytics_model.dart';
import 'package:dash_master_toolkit/services/commercial_contact_service.dart';

void main() {
  test('réponse réelle du serveur : totalContacts lu dans data', () {
    final body = <String, dynamic>{'success': true, 'data': {'totalContacts': 801}};
    final json = CommercialContactService.unwrapKpiPayload(body);
    expect(json['totalContacts'], 801);
    expect(CommercialAnalyticsModel.fromJson(json).totalContacts, 801);
  });

  test('ancien format à plat : inchangé', () {
    final body = <String, dynamic>{'totalContacts': 12, 'totalCalls': 3};
    expect(CommercialContactService.unwrapKpiPayload(body), same(body));
  });
}
