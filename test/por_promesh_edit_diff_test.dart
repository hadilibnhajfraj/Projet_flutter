// Édition d'une fiche PROMESH — seuls les champs réellement modifiés doivent
// partir dans le PUT (UPDATE partiel). Données : VRAIE réponse de
// GET /por-promesh/:id (test/fixtures/por_promesh_api_response.dart, sortie
// réelle du DTO backend, noms anonymisés), passée par le vrai modèle
// PorPromeshModel.fromJson/toJson, puis par le diff utilisé par
// PorPromeshController.pendingChanges().
//
// Dart pur : exécutable sur la VM (`flutter test`), sans navigateur.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/por_promesh/model/por_promesh_model.dart';
import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_diff.dart';

import 'fixtures/por_promesh_api_response.dart';

Map<String, dynamic> _api() => jsonDecode(kPorPromeshApiResponse) as Map<String, dynamic>;

/// Payload tel que produit par le formulaire pour une réponse API donnée.
Map<String, dynamic> _payload(Map<String, dynamic> apiJson) {
  final json = PorPromeshModel.fromJson(apiJson).toJson()
    ..remove('id')
    ..remove('status');
  return deepCopyJson(json);
}

Map<String, dynamic> _diffAfter(void Function(Map<String, dynamic> api) edit) {
  final snapshot = _payload(_api());
  final edited = _api();
  edit(edited);
  return changedFields(snapshot, _payload(edited));
}

void main() {
  test('chargement : valeurs et types conservés (décimal "1250.00" → 1250.0, date intacte)', () {
    final api = _api();
    final m = PorPromeshModel.fromJson(api);
    expect(m.id, api['id']);
    expect(m.productionM2, double.parse(api['productionM2'].toString()));
    expect(m.dateProduction, api['dateProduction']);
    expect(m.machine, api['machine']);
    expect(m.controlesQualite.length, (api['controlesQualite'] as List).length);
  });

  test('TEST 7 — aucune modification → payload vide (aucune écriture)', () {
    expect(_diffAfter((_) {}), isEmpty);
  });

  test('TEST 2 — quantité seule → uniquement productionM2', () {
    expect(_diffAfter((a) => a['productionM2'] = '1600.00'), {'productionM2': 1600.0});
  });

  test('TEST 3 — déchet seul → uniquement totalDechetGraine', () {
    expect(_diffAfter((a) => a['totalDechetGraine'] = '20.00'), {'totalDechetGraine': 20.0});
  });

  test('TEST 4 — diamètre seul → uniquement diametreMaille2', () {
    expect(_diffAfter((a) => a['diametreMaille2'] = '10'), {'diametreMaille2': '10'});
  });

  test('TEST 5 — machine seule → uniquement machine', () {
    final changes = _diffAfter((a) => a['machine'] = a['machine'] == '4' ? '1' : '4');
    expect(changes.keys, ['machine']);
  });

  test('TEST 6 — plusieurs champs → exactement ces champs', () {
    final changes = _diffAfter((a) {
      a['productionM2'] = '1700.50';
      a['totalChuteBarres'] = '3.00';
      a['heureFin'] = '14:30';
    });
    expect(changes, {'productionM2': 1700.5, 'totalChuteBarres': 3.0, 'heureFin': '14:30'});
  });

  test('ligne de contrôle qualité modifiée → tableau envoyé complet (aucune ligne perdue)', () {
    final changes = _diffAfter((a) => (a['controlesQualite'] as List).first['maille'] = 'MODIFIÉ');
    expect(changes.keys, ['controlesQualite']);
    expect((changes['controlesQualite'] as List).length, (_api()['controlesQualite'] as List).length);
  });

  test('personnel modifié → personnelActif envoyé avec les autres membres intacts', () {
    final changes = _diffAfter((a) => (a['personnelActif'] as Map)['responsable2'] = 'Nouveau responsable');
    expect(changes.keys, ['personnelActif']);
    expect((changes['personnelActif'] as Map)['responsable2'], 'Nouveau responsable');
    expect((changes['personnelActif'] as Map)['responsable1'], 'Personne 1');
  });

  test('vider un champ est une vraie modification (null envoyé)', () {
    expect(_diffAfter((a) => a['productionM2'] = null), {'productionM2': null});
  });

  test("'' et null, 1600 et 1600.0, ordre des clés : jamais pris pour une modification", () {
    expect(sameForDiff('', null), isTrue);
    expect(sameForDiff(1600, 1600.0), isTrue);
    expect(sameForDiff({'a': 1, 'b': ''}, {'b': null, 'a': 1.0}), isTrue);
    expect(sameForDiff('8', '10'), isFalse);
  });

  test('Contrôle Machine : temperatureEau / etatDisqueCoupe jamais envoyés (CREATE/UPDATE), même pour une ancienne fiche', () {
    final api = _api()
      ..['temperatureEau'] = '52.00'
      ..['etatDisqueCoupe'] = 'NOK';
    final model = PorPromeshModel.fromJson(api);
    expect(model.temperatureEau, 52.0); // toujours lus (historique)
    expect(model.etatDisqueCoupe, 'NOK');
    final json = model.toJson();
    expect(json.containsKey('temperatureEau'), isFalse);
    expect(json.containsKey('etatDisqueCoupe'), isFalse);
    expect(json['fluideVisuel'], api['fluideVisuel']); // "Fuite d'eau visuelle" conservée
  });

  test('instantané = copie profonde : une mutation EN PLACE reste détectée', () {
    final current = _payload(_api());
    final snapshot = deepCopyJson(current);
    ((current['controlesQualite'] as List).first as Map)['maille'] = 'MODIFIÉ EN PLACE';
    expect(changedFields(snapshot, current).keys, ['controlesQualite']);
  });
}
