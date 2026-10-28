// Exactitude du détail des fiches de production : mapping API → modèle et
// formatage, à partir de réponses RÉELLES de GET /por-promesh/:id et
// GET /industrial-records/:id (fiches PROMESH-2026-001708 et PROBAR
// bfcd46cb, base de développement, champs reproduits tels que renvoyés).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/industrial/model/industrial_record_model.dart';
import 'package:dash_master_toolkit/forms/industrial/view/detail/fiche_detail_layout.dart';
import 'package:dash_master_toolkit/forms/industrial/view/probar/widgets/probar_detail_data.dart';
import 'package:dash_master_toolkit/forms/por_promesh/model/por_promesh_model.dart';

final _promeshJson = <String, dynamic>{
  'id': 'd6acd60a-157b-4ce2-9a0f-fbcab92f1a4f',
  'sequenceNumber': 1708,
  'numero': 'PROMESH-2026-001708',
  'status': 'VALIDE',
  'isLocked': true,
  'validatedAt': '2026-10-27T10:14:51.382Z',
  'approval': {
    'status': 'REJECTED',
    'label': 'Refusée',
    'version': 1,
    'submittedAt': '2026-10-27T10:13:26.776Z',
    'decidedAt': '2026-10-27T10:17:42.528Z',
    'decidedByEmail': 'responsable_logistique@cbi-tunisia.com',
    'rejectedAt': '2026-10-27T10:17:42.528Z',
    'rejectionComment': 'test',
  },
  'dateProduction': '2026-09-23',
  'heureDebut': '11:13:26',
  'heureFin': '11:13:26',
  'operateur': 'aziz',
  'machine': '1',
  'poste': 'matin',
  'diametreMaille1': '50*50',
  'diametreMaille2': '8',
  'diametreMaille3': null,
  'productionM2': '1250.00',
  'personnelActif': {'responsable1': 'test', 'responsable2': '', 'operateur1': ''},
  'air': '> 6 bars',
  'niveauBainEau': 'Bien',
  'temperaturePistons': 55,
  'etatPistons': 'Propre',
  'fluideVisuel': 'Absence',
  'observationsGenerales': 'ok',
  'dateValidationProcess': null,
  'conformite': 'conforme',
  'createdBy': 'dd746847-c5ad-42e9-a5ab-4a721a0e3839',
  'creator': {'id': 'dd746847-c5ad-42e9-a5ab-4a721a0e3839', 'email': 'production_1@cbi-tunisia.com', 'role': 'responsable_logistique_achat'},
  'controlesQualite': [
    {'id': 'cdc37a85', 'heure': '6:00', 'numeroPlaque': '1', 'maille': '125', 'longueur': '151.00', 'largeur': '145.00', 'statutCOQ': 'C'},
  ],
  'arretsMachine': [],
  'consommations': [],
  'attachments': [],
  'createdAt': '2026-10-27T10:13:26.776Z',
  'updatedAt': '2026-10-27T10:14:51.382Z',
};

final _probarJson = <String, dynamic>{
  'id': 'bfcd46cb-f194-4e30-aa74-fff78736519d',
  'module': 'probar',
  'machine': '1',
  'poste': 'matin',
  'dateFiche': '2026-08-28',
  'operateur': null,
  'quantiteProduite': '1250.00',
  'statutQualite': 'ok',
  'description': jsonEncode({
    'dia': '12',
    'p': {'r1': 'hadil'},
    'cm': {'ai': '>= 6 bars', 'nb': 'Bon', 'te': '52', 'ep': 'Propre', 'fv': 'Absence', 'ed': 'OK', 'jm': 'test', 'bo': 'OK', 'rs': 'OK', 'z1': '25', 'z2': '25', 'z3': '25', 'nbb': '5', 'bf': 'OK', 'mc': 'OK', 'mb': 'OK'},
    'qm': {'l1h': '07:47', 'l1l': '125', 'l1m': '125', 'l1d': '125', 'tp': '55'},
    'cq': [
      {'statutCOQ': 'OK', 'heure': '07:30', 'nbBobines': '15', 'vitesse': '125', 'mesure': '25', 'diametre': '14', 'poids': '15', 'longueurBarre': '14', 'longueurDechet': '12'},
      {'statutCOQ': null, 'heure': '11:00', 'nbBobines': '', 'vitesse': '', 'mesure': '', 'diametre': '', 'poids': '', 'longueurBarre': '', 'longueurDechet': ''},
      {'statutCOQ': null, 'heure': '14:00', 'nbBobines': '', 'vitesse': '', 'mesure': '', 'diametre': '', 'poids': '', 'longueurBarre': '', 'longueurDechet': ''},
      {'statutCOQ': null, 'heure': '17:00', 'nbBobines': '', 'vitesse': '', 'mesure': '', 'diametre': '', 'poids': '', 'longueurBarre': '', 'longueurDechet': ''},
    ],
  }),
  'observations': 'test',
  'heureDebut': null,
  'heureFin': null,
  'statut': 'validee',
  'approval': null,
  'createdBy': 'b4a9bf6f-65f1-4dd7-9a38-bb7a07210641',
  'creator': {'id': 'b4a9bf6f-65f1-4dd7-9a38-bb7a07210641', 'email': 'responsable_logistique@cbi-tunisia.com', 'role': 'responsable_logistique_achat'},
  'createdAt': '2026-08-28T18:46:47.100Z',
  'updatedAt': '2026-08-28T18:48:40.165Z',
};

void main() {
  group('PROMESH — réponse API réelle → modèle', () {
    final m = PorPromeshModel.fromJson(_promeshJson);

    test('quantité « 1250.00 » (texte décimal) → 1250 m², jamais perdue', () {
      expect(m.productionM2, 1250.0);
      expect(fdNumber(m.productionM2), '1 250');
    });

    test('statut réel : saisie terminée (VALIDE) puis refusée → déverrouillée pour correction', () {
      expect(m.status, 'submitted');
      expect(m.approval!.status, 'REJECTED');
      expect(m.isLocked, isFalse); // isLocked:true de l'API levé par le refus (règle existante)
      expect(ficheStatus(isDraft: m.status == 'draft', approvalStatus: m.approval?.status).label, 'Refusée');
    });

    test('producteur et validateur : compte créateur et décideur réels', () {
      expect(m.creator!['email'], 'production_1@cbi-tunisia.com');
      expect(m.operateur, 'aziz'); // opérateur saisi, distinct du compte
      expect(m.approval!.decidedByEmail, 'responsable_logistique@cbi-tunisia.com');
      expect(m.approval!.rejectionComment, 'test');
    });

    test('fin de saisie : validatedAt lu (dateValidationProcess absent en base)', () {
      expect(m.validatedAt, '2026-10-27T10:14:51.382Z');
      expect(m.dateValidationProcess, isNull);
      expect(fdDateTime(m.validatedAt), matches(RegExp(r'^27/10/2026 \d{2}:14$')));
    });

    test('heures : « 11:13:26 » affichée « 11:13 », une seule fois si début = fin', () {
      expect(fdHours(m.heureDebut, m.heureFin), '11:13');
      expect(fdHours('06:00', '14:00:00'), '06:00 – 14:00');
      expect(fdHours(null, ''), '—');
      expect(fdTime('6:00'), '06:00');
    });

    test('contrôle qualité : mesures et statut tels que renvoyés', () {
      final r = m.controlesQualite.single;
      expect([fdMeasure(r['maille']), fdMeasure(r['longueur']), fdMeasure(r['largeur'])], ['125', '151', '145']);
      expect(r['statutCOQ'], 'C');
      expect(m.conformite, 'conforme');
    });

    test('dates : AAAA-MM-JJ → JJ/MM/AAAA ; ISO → heure locale', () {
      expect(fdDate(m.dateProduction), '23/09/2026');
      expect(fdDateTime(m.createdAt), contains('27/10/2026'));
    });
  });

  group('PROBAR — réponse API réelle → modèle', () {
    final r = IndustrialRecordModel.fromJson(_probarJson);
    final d = ProbarDetailData.fromModel(r);

    test('quantité en mètres linéaires (texte décimal), statut et qualité', () {
      expect(r.quantiteProduite, 1250.0);
      expect(r.statut, 'validee');
      expect(r.approval, isNull);
      expect(ficheStatus(isDraft: r.statut != 'validee', approvalStatus: r.approval?.status).label, 'Soumise');
      expect(r.statutQualite, 'ok');
    });

    test('contrôle qualité par créneau (cq) et diamètre (dia) désormais décodés', () {
      expect(d.diametre, '12');
      expect(d.controlesQualite, hasLength(4));
      expect(d.controlesQualite.first, containsPair('statutCOQ', 'OK'));
      expect(d.controlesQualite.first, containsPair('vitesse', '125'));
    });

    test('données absentes restées absentes : heures, opérateur', () {
      expect([d.heureDebut, d.heureFin, r.operateur], [null, null, null]);
      expect(fdHours(d.heureDebut, d.heureFin), '—');
      expect(fdValue(r.operateur), '—');
    });

    test('contrôle machine, mesures de ligne, personnel, observation', () {
      expect(d.machineControl['air'], '>= 6 bars');
      expect(d.machineControl['justification'], 'test');
      expect(d.qualiteMesures['l1l'], '125');
      expect(d.qualiteMesures['tp'], '55');
      expect(d.personnel['responsable1'], 'hadil');
      expect(d.observationsText, 'test');
      expect(r.creator!['email'], 'responsable_logistique@cbi-tunisia.com');
    });
  });

  test('zéro ≠ donnée indisponible', () {
    expect(fdMeasure('0'), '0');
    expect(fdMeasure(0), '0');
    expect(fdMeasure(null), '—');
    expect(fdMeasure('  '), '—');
    expect(fdMeasure('abc'), 'abc');
    expect(fdMeasure('12', ' mm'), '12 mm');
    expect(fdNumber(0), '0');
    expect(fdNumber(null), '—');
  });
}
