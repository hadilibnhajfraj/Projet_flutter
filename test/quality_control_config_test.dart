// Module Contrôle Qualité — le formulaire est entièrement piloté par la
// configuration backend (GET /quality-control/config, réponse RÉELLE dans
// test/fixtures/quality_control_config.dart). Dart pur (VM).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart';

import 'fixtures/quality_control_config.dart';

QualityConfig _config() => QualityConfig.fromJson(jsonDecode(kQualityControlConfig) as Map<String, dynamic>);

void main() {
  test('lignes PROMESH / PROBAR et leurs machines (1 à 4, comme le module Production)', () {
    final c = _config();
    expect(c.line('PROMESH')!.machines, ['1', '2', '3', '4']);
    expect(c.line('probar')!.machines, ['1', '2', '3', '4']);
    expect(c.line('MELANGE'), isNull);
  });

  test('contrôles d\'un prélèvement répartis en catégories, avec types de champ et unités', () {
    final c = _config();
    expect(c.parameters, hasLength(41));
    expect(c.readingParameters, hasLength(27));
    // L'heure du contrôle appartient au PRÉLÈVEMENT : ce n'est plus un paramètre.
    expect(c.parameter('heure'), isNull);
    // Catégories d'un prélèvement, toutes lignes : celle de PROMESH (unique)
    // puis celles de PROBAR. Les paramètres physiques n'en font PAS partie.
    expect(c.visibleSections.map((s) => s.label), ['Contrôle Machine', 'Paramètres de ligne', 'Chauffage / imprégnation', 'Machine']);
    expect(c.parameter('pression_air_comprime'), isA<QualityParameter>().having((p) => p.unit, 'unit', 'bar').having((p) => p.kind, 'kind', 'number'));
    expect(c.parameter('temperature_machine')!.unit, '°C');
    expect(c.parameter('dimensions_cote_1_long')!.unit, 'mm');
    // Unité non définie par le métier : aucune unité affichée (rien d'inventé).
    expect(c.parameter('nombre_bar_longueur')!.unit, isNull);
    expect(c.parameter('viscosite_resine')!.unit, isNull);
    expect(c.readingIntervalMinutes, 180);
  });

  test('paramètres physiques : niveau fiche, propres à la ligne, jamais dans un prélèvement', () {
    final c = _config();
    expect(c.physicalParameters('PROBAR').map((p) => p.label), [
      'DIAMÈTRE NOMINAL',
      'DIAMÈTRE RÉEL',
      'SECTION TRANSVERSALE',
      'LONGUEUR',
      'POIDS EN g',
      'DÉFAUTS SUPERFICIELS',
      'QUALITÉ DE COUPE',
    ]);
    // PROMESH : Contrôle Produit — 7 caractéristiques du produit, niveau fiche.
    expect(c.physicalParameters('promesh').map((p) => p.label), [
      'DIAMÈTRE RÉEL',
      'NOMBRE DE BARRES EN LONGUEUR',
      'NOMBRE DE BARRES EN LARGEUR',
      'DIMENSIONS DE MAILLE',
      'DIMENSIONS CÔTÉ 1 LONG',
      'DIMENSIONS CÔTÉ 2 LONG',
      'ÉTAT D\'IMPRESSION',
    ]);
    expect(c.ficheParameters('PROMESH'), hasLength(7));
    // Diamètre réel : saisie libre, niveau fiche ; vitesse d'impression : contrôle machine du prélèvement.
    expect(c.parameter('promesh_diametre_reel'), isA<QualityParameter>().having((p) => p.kind, 'kind', 'text').having((p) => p.scope, 'scope', 'fiche').having((p) => p.unit, 'unit', isNull));
    expect(c.parameter('vitesse_impression'), isA<QualityParameter>().having((p) => p.kind, 'kind', 'number').having((p) => p.scope, 'scope', 'reading').having((p) => p.unit, 'unit', isNull));
    expect(c.parameter('etat_impression'), isA<QualityParameter>().having((p) => p.kind, 'kind', 'choice').having((p) => p.scope, 'scope', 'fiche'));
    // Unités : seulement celle déjà définie (mm) — aucune unité inventée.
    expect(c.physicalParameters('PROBAR').every((p) => p.unit == null), isTrue);
    // Qualité de coupe : choix Bon / Pas bon (codes BON / PAS_BON), jamais une saisie.
    final coupe = c.parameter('phys_qualite_coupe')!;
    expect(coupe.kind, 'choice');
    expect(coupe.options.map((o) => '${o.value}:${o.label}'), ['BON:Bon', 'PAS_BON:Pas bon']);
    for (final key in ['phys_vitesse_coupe', 'phys_longueur_coupe', 'phys_hauteur_nervures', 'phys_regularite_revetement', 'phys_ovalisation', 'phys_rectitude', 'phys_vitesse_refroidissement', 'phys_ceinture_tirage', 'phys_pas_profil_surface']) {
      expect(c.parameter(key), isNull, reason: key); // retirés
    }
    // Défauts superficiels : choix OK / NOK, jamais une saisie.
    final defauts = c.parameter('phys_defauts_superficiels_controle')!;
    expect(defauts.label, 'DÉFAUTS SUPERFICIELS');
    expect(defauts.kind, 'choice');
    expect(defauts.options.map((o) => '${o.value}:${o.label}'), ['OK:OK', 'NOK:NOK']);
    expect(c.parameter('phys_defauts_superficiels'), isNull);
    expect(c.parameter('phys_pas_profil_surface_controle'), isNull);
    // « Masse linéique » renommée « Poids en g » : saisie libre, même clé.
    expect(c.parameter('phys_masse_lineique'), isA<QualityParameter>().having((p) => p.label, 'label', 'POIDS EN g').having((p) => p.kind, 'kind', 'text').having((p) => p.unit, 'unit', isNull));
    final physicalKeys = {...c.physicalParameters('PROBAR').map((p) => p.key), ...c.physicalParameters('PROMESH').map((p) => p.key)};
    expect(c.readingParameters.any((p) => physicalKeys.contains(p.key)), isFalse);
    expect(c.physicalParameters('MELANGE'), isEmpty);
  });

  test('PROMESH : 8 contrôles machine par prélèvement (une catégorie) ; PROBAR inchangé', () {
    final c = _config();
    const bar = ['variateur_frequence_tirage', 'variateur_frequence_bobinage', 'nombre_bobines', 'vitesse_barre'];
    // PROMESH : une seule catégorie « Contrôle Machine », 8 paramètres dans
    // l'ordre, avec ses libellés ; les caractéristiques du produit n'y sont pas.
    expect(c.visibleSectionsFor('PROMESH').map((s) => s.label), ['Contrôle Machine']);
    final promesh = c.readingParametersFor('PROMESH');
    expect(promesh.map((p) => p.key), [
      'temperature_machine',
      'temperature_eau',
      'pression_air_comprime',
      'fuite_eau',
      'fuite_air_comprime',
      'etat_disque_coupe',
      'niveau_bain_graines',
      'vitesse_impression',
    ]);
    expect(promesh.map((p) => p.label), [
      'TEMPÉRATURE DE MACHINE',
      'TEMPÉRATURE D\'EAU',
      'PRESSION D\'AIR COMPRIMÉ',
      'FUITE D\'EAU',
      'FUITE D\'AIR COMPRIMÉ',
      'ÉTAT DISQUE DE COUPE',
      'NIVEAU BAIN DE GRAINES',
      'VITESSE D\'IMPRESSION',
    ]);
    expect(promesh.every((p) => p.section == 'controle_machine'), isTrue);
    expect(c.parametersOf('controle_machine', productionType: 'PROMESH'), hasLength(8));
    final productKeys = c.physicalParameters('PROMESH').map((p) => p.key).toSet();
    expect(productKeys, {'promesh_diametre_reel', 'nombre_bar_longueur', 'nombre_bar_largeur', 'dimensions_maille', 'dimensions_cote_1_long', 'dimensions_cote_2_long', 'etat_impression'});
    expect(promesh.map((p) => p.key).toSet().intersection(productKeys), isEmpty);
    expect(promesh.map((p) => p.key).toSet().intersection(bar.toSet()), isEmpty);
    for (final key in ['diametre_bar', 'vitesse_tirage', 'tension_rovings', 'nombre_rovings', 'temperature_filiere', 'temps_gel', 'degre_polymerisation', 'vitesse_polymerisation', 'vitesse_refroidissement', 'treillis_largeur', 'treillis_poids_m2']) {
      expect(c.parameter(key), isNull, reason: key); // plus renvoyés par l'API
    }
    for (final key in ['alignement_fibres', 'viscosite_resine', 'temperature_zone_1', 'temperature_zone_2', 'temperature_zone_3', 'pression_air']) {
      expect(c.parameter(key)!.lines, ['PROBAR'], reason: key); // restent à PROBAR seulement
    }
    // Un paramètre partagé garde son libellé et sa catégorie pour PROBAR.
    final disque = c.readingParametersFor('PROBAR').firstWhere((p) => p.key == 'etat_disque_coupe');
    expect([disque.label, disque.section], ['ÉTAT DU DISQUE DE COUPE', 'machine']);

    // PROBAR : structure propre aux barres — A (5), B (6), ni Polymérisation
    // ni Barre, ni Refroidissement / coupe (paramètres physiques) ; Machine (5).
    // 15 contrôles par prélèvement.
    expect(c.visibleSectionsFor('PROBAR').map((s) => s.label), ['Paramètres de ligne', 'Chauffage / imprégnation', 'Machine']);
    expect(c.readingParametersFor('PROBAR'), hasLength(15));
    expect(c.parametersOf('ligne', productionType: 'PROBAR').map((p) => p.label), ['VARIATEUR EN FRÉQUENCE DE TIRAGE', 'VARIATEUR EN FRÉQUENCE DE BOBINAGE', 'VITESSE DE BARRE (m/min)', 'NOMBRE DE BOBINES', 'ALIGNEMENT DES FIBRES']);
    expect(c.parametersOf('chauffage', productionType: 'PROBAR').map((p) => p.label), ['TEMPÉRATURE ZONE 1', 'TEMPÉRATURE ZONE 2', 'TEMPÉRATURE ZONE 3', 'PRESSION D\'AIR', 'VISCOSITÉ DE LA RÉSINE', 'RATIO RÉSINE / DURCISSEUR / CATALYSEUR']);
    expect(c.parametersOf('coupe', productionType: 'PROBAR'), isEmpty);
    // Trois zones de chauffage : trois saisies numériques indépendantes (°C).
    for (final key in ['temperature_zone_1', 'temperature_zone_2', 'temperature_zone_3']) {
      expect(c.parameter(key), isA<QualityParameter>().having((p) => p.kind, 'kind', 'number').having((p) => p.unit, 'unit', '°C').having((p) => p.section, 'section', 'chauffage'), reason: key);
    }
    // Pression d'air (chauffage) distincte de la pression d'air comprimé (machine).
    expect(c.parameter('pression_air')!.section, 'chauffage');
    // Paramètres retirés de PROBAR : plus renvoyés par l'API.
    for (final key in ['vitesse_tirage_bobinage', 'vitesse_alimentation_fibres', 'vitesse_bobinage', 'temperature_zones_chauffage', 'pression_impregnation']) {
      expect(c.parameter(key), isNull, reason: key);
    }
    // Machine : sans température de machine, pression d'air comprimé ni état d'impression (PROMESH uniquement).
    expect(c.parametersOf('machine', productionType: 'PROBAR').map((p) => p.key), ['temperature_eau', 'fuite_air_comprime', 'fuite_eau', 'etat_disque_coupe']);
    for (final key in ['pression_air_comprime', 'etat_impression', 'temperature_machine']) {
      expect(c.parameter(key)!.lines, isNot(contains('PROBAR')), reason: key);
    }
    // Ratio : contrôle binaire Conforme / Non conforme, sans valeur ni option.
    expect(c.parameter('ratio_resine_durcisseur_catalyseur'), isA<QualityParameter>().having((p) => p.kind, 'kind', 'conformity').having((p) => p.options, 'options', isEmpty));
    for (final key in ['variateur_frequence_tirage', 'variateur_frequence_bobinage', 'nombre_bobines', 'vitesse_barre']) {
      expect(c.parameter(key), isA<QualityParameter>().having((p) => p.kind, 'kind', 'number').having((p) => p.lines, 'lines', ['PROBAR']), reason: key);
    }
    final probarLabels = c.readingParametersFor('PROBAR').map((p) => p.label).toList();
    for (final label in ['NIVEAU BAIN DE GRAINES', 'VITESSE DE TIRAGE', 'TENSION DES ROVINGS', 'NOMBRE DE ROVINGS', 'TEMPÉRATURE DE LA FILIÈRE', 'TEMPS DE GEL', 'DEGRÉ DE POLYMÉRISATION', 'VITESSE DE POLYMÉRISATION', 'DIAMÈTRE DE LA BARRE', 'ÉTAT DE SURFACE', 'QUANTITÉ ET RÉGULARITÉ DU REVÊTEMENT', 'TOLÉRANCE DIMENSIONNELLE', 'ESPACEMENT DES FILS', 'VITESSE DE TIRAGE DE BOBINAGE', 'VITESSE D\'ALIMENTATION DES FIBRES', 'VITESSE DE BOBINAGE (m/min)', 'TEMPÉRATURE DES DIFFÉRENTES ZONES DE CHAUFFAGE', 'PRESSION / CONDITIONS D\'IMPRÉGNATION']) {
      expect(probarLabels, isNot(contains(label)), reason: label);
    }
    // Contrôle produit PROBAR : 7 paramètres.
    expect(c.physicalParameters('PROBAR'), hasLength(7));

    // Aucun paramètre spécifique de niveau fiche, pour aucune ligne.
    expect(c.specificParameters('PROBAR'), isEmpty);
    expect(c.specificSections('PROBAR'), isEmpty);
    expect(c.specificParameters('PROMESH'), isEmpty);
    expect(c.specificSections('PROMESH'), isEmpty);
    expect(c.physicalParameters('PROMESH'), hasLength(7)); // Contrôle Produit
  });

  test('PROMESH 4 : liste de paramètres propre à la machine ; PROMESH 1 à 3 et PROBAR gardent la leur', () {
    final c = _config();
    expect(c.lineKey('PROMESH', '4'), 'PROMESH:4');
    expect(c.lineKey('promesh', '4'), 'PROMESH:4');
    for (final machine in ['1', '2', '3']) {
      expect(c.lineKey('PROMESH', machine), 'PROMESH', reason: machine);
    }
    expect(c.lineKey('PROBAR', '4'), 'PROBAR');
    expect(c.lineKey('PROMESH', null), 'PROMESH');

    final p4 = c.readingParametersFor(c.lineKey('PROMESH', '4'));
    expect(p4.map((p) => p.key), [
      'promesh4_temperature_machine_1_zone_1',
      'promesh4_temperature_machine_1_zone_2',
      'promesh4_temperature_machine_2_zone_1',
      'promesh4_temperature_machine_2_zone_2',
      'temperature_eau',
      'promesh4_nombre_bobines',
      'promesh4_vitesse_tirage',
      'promesh4_viscosite_bain_1',
      'promesh4_viscosite_bain_2',
    ]);
    expect(c.visibleSectionsFor('PROMESH:4').map((s) => s.label), ['Contrôle Machine']);
    expect(c.visibleSectionsFor('PROMESH:4').single.key, 'controle_promesh_4');
    // Sous-groupes : deux zones par température machine, deux bains de viscosité.
    expect(p4.where((p) => p.group != null).map((p) => '${p.group} / ${p.shortLabel} / ${p.unit}'), [
      'TEMPÉRATURE MACHINE 1 / ZONE 1 / °C',
      'TEMPÉRATURE MACHINE 1 / ZONE 2 / °C',
      'TEMPÉRATURE MACHINE 2 / ZONE 1 / °C',
      'TEMPÉRATURE MACHINE 2 / ZONE 2 / °C',
      'VISCOSITÉ DE LA RÉSINE / BAIN 1 / °',
      'VISCOSITÉ DE LA RÉSINE / BAIN 2 / °',
    ]);
    expect(p4.where((p) => p.group == null).map((p) => '${p.label} / ${p.unit}'), ['TEMPÉRATURE D\'EAU / °C', 'NOMBRE DE BOBINES / null', 'VITESSE DE TIRAGE / null']);
    // Contrôle Produit de PROMESH 4 : niveau fiche, ses libellés et son ordre.
    final product = c.physicalParameters('PROMESH:4');
    expect(product.map((p) => p.key), ['promesh_diametre_reel', 'dimensions_cote_1_long', 'nombre_bar_longueur', 'dimensions_maille', 'nombre_bar_largeur', 'dimensions_cote_2_long']);
    expect(product.map((p) => p.label), ['DIAMÈTRE RÉEL', 'DIMENSIONS CÔTÉ 1 LONGUEUR', 'NOMBRE DE BARRES EN LONGUEUR', 'DIMENSIONS DE MAILLE', 'NOMBRE DE BARRES EN LARGEUR', 'DIMENSIONS CÔTÉ 2 LONGUEUR']);
    // « État d'impression » : PROMESH 1 à 3 uniquement.
    expect(product.any((p) => p.kind == 'choice'), isFalse);
    expect(c.parameter('etat_impression')!.lines, ['PROMESH']);
    expect(c.specificParameters('PROMESH:4'), isEmpty);
    // La ligne PROMESH garde ses libellés et son ordre.
    expect(c.physicalParameters('PROMESH').map((p) => p.label), ['DIAMÈTRE RÉEL', 'NOMBRE DE BARRES EN LONGUEUR', 'NOMBRE DE BARRES EN LARGEUR', 'DIMENSIONS DE MAILLE', 'DIMENSIONS CÔTÉ 1 LONG', 'DIMENSIONS CÔTÉ 2 LONG', 'ÉTAT D\'IMPRESSION']);

    // Les autres machines PROMESH et PROBAR ne reçoivent aucun paramètre de PROMESH 4.
    for (final line in ['PROMESH', 'PROBAR']) {
      expect([...c.readingParametersFor(line), ...c.ficheParameters(line)].any((p) => p.key.startsWith('promesh4_')), isFalse, reason: line);
    }
    expect(c.readingParametersFor('PROMESH'), hasLength(8));
    expect(c.physicalParameters('PROMESH'), hasLength(7));
    expect(c.readingParametersFor('PROBAR'), hasLength(15));
  });

  test('prélèvements : heure proposée = dernier prélèvement + cadence, y compris après minuit', () {
    expect(qcAddMinutes('08:00', 180), '11:00');
    expect(qcAddMinutes('11:07', 180), '14:07');
    expect(qcAddMinutes('22:30', 180), '01:30');
    expect(qcIsValidReadingTime('08:00'), isTrue);
    expect(qcIsValidReadingTime('24:00'), isFalse);
    expect(qcIsValidReadingTime('8:00'), isFalse);
  });

  test('paramètres à choix : boutons et tonalité (Conforme/Non conforme proposé)', () {
    final c = _config();
    final disque = c.parameter('etat_disque_coupe')!;
    expect(disque.kind, 'choice');
    expect(disque.options.map((o) => '${o.value}:${o.tone}'), ['OK:ok', 'NOK:nok']);
    expect(c.parameter('fuite_eau')!.options.map((o) => o.value), ['Absent', 'Présent']);
    // Paramètres qualitatifs : Conforme / Non conforme.
    for (final key in ['alignement_fibres', 'etat_impression']) {
      expect(c.parameter(key)!.kind, 'choice', reason: key);
      expect(c.parameter(key)!.options.map((o) => '${o.value}:${o.tone}'), ['Conforme:ok', 'Non conforme:nok'], reason: key);
    }
    // Niveau bain de graines : paramètre PROMESH (fiche de référence), trois niveaux.
    expect(c.parameter('niveau_bain_graines')!.options.map((o) => o.tone), ['ok', 'warn', 'nok']);
    for (final key in ['tension_rovings', 'nombre_rovings']) {
      expect(c.parameter(key), isNull, reason: key); // retirés de toutes les lignes
    }
  });

  test('résultat affiché : Conforme / Non conforme / À vérifier', () {
    expect(qualityResultLabel('CONFORME'), 'Conforme');
    expect(qualityResultLabel('NON_CONFORME'), 'Non conforme');
    expect(qualityResultLabel('EN_ATTENTE'), 'À vérifier');
    expect(qualityResultLabel('EN_COURS'), 'À vérifier');
  });
}
