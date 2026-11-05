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

  test('format réel de /my-kpi : libellés, commerciaux, appels et entreprises lus', () {
    // Clés exactement telles que renvoyées par le backend.
    final body = <String, dynamic>{
      'success': true,
      'data': {
        'totalContacts': 485, 'totalCalls': 454, 'totalCompanies': 367,
        'totalCommerciaux': 3, 'totalActifs': 256, 'totalNonValides': 156,
        'contactsByStatus': [{'status': 'ok', 'count': 256}, {'status': 'client_refuse', 'count': 63}],
        'contactsByType': [{'clientType': 'Batiment', 'count': 304}],
        'contactsByCommercial': [
          {'commercial': 'wajdi', 'contacts': 337, 'calls': 291, 'actifs': 184, 'nonValides': 106, 'entreprises': 293},
          {'commercial': 'mayssa', 'contacts': 88, 'calls': 92, 'actifs': 49, 'nonValides': 23, 'entreprises': 14},
        ],
        'topCompanies': [{'name': 'Vervie', 'contacts': 2, 'calls': 3}],
        'monthlyActivity': [{'month': 'Avr', 'contacts': 322, 'calls': 290}],
      },
    };
    final m = CommercialAnalyticsModel.fromJson(CommercialContactService.unwrapKpiPayload(body));
    expect(m.contactsByStatut.map((s) => s.statut), ['ok', 'client_refuse']); // libellés non vides
    expect(m.contactsByType.single.type, 'Batiment');
    expect([m.totalCommerciaux, m.totalActifs, m.totalNonValides], [3, 256, 156]);
    expect(m.contactsByCommercial.map((c) => [c.commercial, c.contacts, c.calls, c.entreprises]), [
      ['wajdi', 337, 291, 293],
      ['mayssa', 88, 92, 14],
    ]);
    expect(m.topCompanies.single.name, 'Vervie');
    expect([m.topCompanies.single.contacts, m.topCompanies.single.calls], [2, 3]);
    expect(m.monthlyActivity.single.month, 'Avr');
  });

  // Réponse EXACTE de GET /commercial-contacts/kpi (superadmin) produite par la
  // version déployée du backend (valeurs de la base locale) : totalCommercials
  // et topCommercials, sans contactsByCommercial / topCompanies / monthlyActivity.
  const deployedKpi = <String, dynamic>{
    'success': true,
    'data': {
      'isPersonalDashboard': false,
      'totalContacts': 486, 'totalCalls': 454, 'totalCompanies': 368, 'totalCommercials': 2,
      'contactsByStatus': [
        {'status': 'ok', 'count': 256}, {'status': 'user_injoignable', 'count': 94},
        {'status': 'rappeler_plus_tard', 'count': 73}, {'status': 'client_refuse', 'count': 63},
      ],
      'contactsByType': [{'clientType': 'Batiment', 'count': 304}, {'clientType': 'Tuteur', 'count': 182}],
      'topCommercials': [
        {'rank': 1, 'userName': 'info', 'email': 'info@probardistribution.com', 'score': 95.28, 'contactsCount': 485, 'callsCount': 454, 'activeContacts': 256},
        {'rank': 2, 'userName': 'aziz_nefzaoui', 'email': 'aziz_nefzaoui@probardistribution.com', 'score': 0.08, 'contactsCount': 1, 'callsCount': 0, 'activeContacts': 0},
      ],
    },
  };

  group('version déployée de /kpi (topCommercials, totalCommercials)', () {
    final m = CommercialAnalyticsModel.fromJson(CommercialContactService.unwrapKpiPayload(deployedKpi));

    test('KPI : exactement les nombres reçus (commerciaux = totalCommercials, jamais 0)', () {
      expect([m.totalContacts, m.totalCalls, m.totalCompanies, m.totalCommerciaux], [486, 454, 368, 2]);
    });

    test('contacts / appels / actifs / score par commercial = topCommercials, champ par champ', () {
      expect(m.providesByCommercial, isTrue);
      expect(m.contactsByCommercial.map((c) => [c.commercial, c.contacts, c.calls, c.actifs, c.score]), [
        ['info', 485, 454, 256, 95.28],
        ['aziz_nefzaoui', 1, 0, 0, 0.08],
      ]);
      // Non fournis par ce format : inconnus (« — » à l'écran), jamais 0.
      expect(m.contactsByCommercial.every((c) => c.nonValides == null && c.entreprises == null), isTrue);
    });

    test('totaux actifs / non validés : lus dans contactsByStatus du serveur (mêmes règles que le backend)', () {
      expect([m.totalActifs, m.totalNonValides], [256, 94 + 63]);
    });

    test('entreprises et activité mensuelle : signalées NON FOURNIES (pas « aucune »)', () {
      expect([m.providesTopCompanies, m.providesMonthly], [false, false]);
      expect([m.topCompanies, m.monthlyActivity], [isEmpty, isEmpty]);
    });
  });

  // Extrait EXACT de GET /commercial-contacts/kpi produit par le backend à jour
  // (base locale) : topCompanies { companyName, contactsCount, callsCount },
  // monthlyActivity { month, label, newContacts, callsCount: null }.
  final updatedKpi = <String, dynamic>{
    'data': {
      ...(deployedKpi['data'] as Map<String, dynamic>),
      'totalCommerciaux': 4, 'totalActifs': 256, 'totalNonValides': 157, 'contactsWithoutCompany': 115,
      'contactsByCommercial': [
        {'commercial': 'wajdi', 'contacts': 337, 'calls': 291, 'actifs': 184, 'nonValides': 106, 'entreprises': 293},
      ],
      'topCompanies': [
        {'companyName': 'Vervie', 'contactsCount': 2, 'callsCount': 3},
        {'companyName': 'Depot de construction', 'contactsCount': 2, 'callsCount': 0},
        {'companyName': 'DEPOT DES MATERIAUX DE CONSTRUCTION', 'contactsCount': 2, 'callsCount': 0},
        {'companyName': 'CHOKRI B HSSINE RAFEI', 'contactsCount': 1, 'callsCount': 3},
      ],
      'monthlyActivity': [
        for (final (ym, label, n) in [
          ('2025-12', 'Déc', 0), ('2026-01', 'Jan', 0), ('2026-02', 'Fév', 0), ('2026-03', 'Mar', 0),
          ('2026-04', 'Avr', 322), ('2026-05', 'Mai', 162), ('2026-06', 'Jun', 1), ('2026-07', 'Jul', 0),
          ('2026-08', 'Aoû', 0), ('2026-09', 'Sep', 0), ('2026-10', 'Oct', 1), ('2026-11', 'Nov', 0),
        ])
          {'month': ym, 'label': label, 'newContacts': n, 'callsCount': null},
      ],
      'monthlyCallsAvailable': false,
      'monthlyCallsNote': 'Appels non répartis par mois : seul le total cumulé par contact (nbAppels) est enregistré, sans date pour chaque appel.',
    },
  };

  group('backend à jour : top entreprises et activité mensuelle', () {
    final m = CommercialAnalyticsModel.fromJson(CommercialContactService.unwrapKpiPayload(updatedKpi));

    test('commerciaux : contactsByCommercial prioritaire, totalCommerciaux préféré', () {
      expect(m.totalCommerciaux, 4);
      expect(m.contactsByCommercial.single.commercial, 'wajdi');
      expect([m.contactsByCommercial.single.nonValides, m.contactsByCommercial.single.entreprises, m.contactsByCommercial.single.score], [106, 293, null]);
      expect([m.totalActifs, m.totalNonValides], [256, 157]);
    });

    test('top entreprises : classement, nom, contacts, appels tels que reçus', () {
      expect(m.providesTopCompanies, isTrue); // plus de « Non fourni par le serveur »
      expect(m.topCompanies.map((c) => [c.name, c.contacts, c.calls]), [
        ['Vervie', 2, 3],
        ['Depot de construction', 2, 0],
        ['DEPOT DES MATERIAUX DE CONSTRUCTION', 2, 0],
        ['CHOKRI B HSSINE RAFEI', 1, 3],
      ]);
      expect(m.contactsWithoutCompany, 115); // sans entreprise : comptés à part
    });

    test('activité mensuelle : 12 mois, nouveaux contacts réels, appels NON répartis (série masquée)', () {
      expect(m.providesMonthly, isTrue);
      expect(m.monthlyActivity, hasLength(12));
      expect(m.monthlyActivity.map((x) => x.month).first, 'Déc');
      expect(m.monthlyActivity.map((x) => x.contacts).fold<int>(0, (s, n) => s + n), 486);
      expect(m.monthlyActivity.every((x) => x.calls == null), isTrue);
      expect(m.monthlyCallsAvailable, isFalse);
      expect(m.monthlyCallsNote, contains('nbAppels'));
    });
  });

  test('appels mensuels réels fournis (format futur) : série affichable', () {
    final m = CommercialAnalyticsModel.fromJson({
      'monthlyActivity': [{'month': '2026-04', 'label': 'Avr', 'newContacts': 3, 'callsCount': 5}],
    });
    expect([m.monthlyActivity.single.contacts, m.monthlyActivity.single.calls], [3, 5]);
    expect(m.monthlyCallsAvailable, isTrue);
  });

  test('contacts bruts (repli client) : jamais d’appels répartis par mois', () {
    final m = CommercialAnalyticsModel.fromContacts(const []);
    expect(m.monthlyActivity.every((x) => x.calls == null), isTrue);
    expect(m.monthlyCallsAvailable, isFalse);
  });

  test('ancien format à plat : inchangé', () {
    final body = <String, dynamic>{'totalContacts': 12, 'totalCalls': 3};
    expect(CommercialContactService.unwrapKpiPayload(body), same(body));
  });
}
