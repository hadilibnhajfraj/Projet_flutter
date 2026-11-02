// « Created by » d'un contact commercial : créateur RÉEL renvoyé par le
// backend (relation createdBy → users : createdByName / createdByEmail) et
// commercial choisi sur un compte partagé (commercialName). Formes de réponse
// identiques à GET /commercial-contacts (test/commercialContactsVisibility.test.js).

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/application/users/model/commercial_contact_model.dart';

Map<String, dynamic> _contact(Map<String, dynamic> extra) => {
      'id': 'c-1',
      'nom': 'Ben Salah',
      'prenom': 'Ali',
      'telephone': '+216 20 000 000',
      'nbAppels': 0,
      ...extra,
    };

void main() {
  test('contact créé par Aziz (compte propre, sans nom de profil) : « Aziz (email) »', () {
    final c = CommercialContact.fromJson(_contact({
      'user_nom': 'aziz',
      'createdByName': 'aziz_nefzaoui@probardistribution.com', // pas de nom de profil : email
      'createdByEmail': 'aziz_nefzaoui@probardistribution.com',
      'commercialName': 'aziz',
    }));
    expect(c.createdByLabel, 'Aziz (aziz_nefzaoui@probardistribution.com)');
  });

  test('compte partagé info@ : le commercial choisi et le compte créateur réel', () {
    final c = CommercialContact.fromJson(_contact({
      'user_nom': 'najeh',
      'createdByName': 'info@probardistribution.com',
      'createdByEmail': 'info@probardistribution.com',
      'commercialName': 'najeh',
    }));
    expect(c.createdByLabel, 'Najeh (info@probardistribution.com)');
  });

  test('créateur avec un nom de profil : ce nom, jamais celui d’un autre utilisateur', () {
    final c = CommercialContact.fromJson(_contact({
      'user_nom': 'najeh',
      'createdByName': 'Hadil',
      'createdByEmail': 'hadil.ibnhajfraj@gmail.com',
      'commercialName': 'najeh',
    }));
    expect(c.createdByLabel, 'Hadil (hadil.ibnhajfraj@gmail.com)');
  });

  test('Filter by User : créateur réel (GET /commercial-contacts/creators/list)', () {
    final c = CommercialContactCreator.fromJson({
      'id': 'a25cc0a3-b02c-4d39-88f3-57df49dfc6c6',
      'email': 'aziz_nefzaoui@probardistribution.com',
      'name': 'Aziz Nefzaoui',
      'count': 1,
    });
    expect(c.label, 'Aziz Nefzaoui – aziz_nefzaoui@probardistribution.com (1)');
    expect(CommercialContactCreator.fromJson({'id': 'x', 'email': null, 'name': null, 'count': '3'}).label, '- (3)');
  });

  test('ancienne réponse (sans créateur réel) : repli sur le nom du commercial, sinon « - »', () {
    expect(CommercialContact.fromJson(_contact({'user_nom': 'mayssa'})).createdByLabel, 'Mayssa');
    expect(CommercialContact.fromJson(_contact({})).createdByLabel, '-');
  });
}
