// Contrôle Qualité — Comparaison qualité dynamique et exports (VM).
//
// VRAIS écrans + VRAI service (Dio) ; le transport HTTP est un faux backend
// qui renvoie une réponse de comparaison au format exact de l'API et qui
// applique les filtres reçus (les calculs SQL eux-mêmes sont vérifiés côté
// backend : test/qualityControl.comparison.test.js). L'écran n'affiche que ce
// que la réponse contient : chaque test vérifie qu'il s'adapte aux données.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/model/quality_control_comparison.dart';
import 'package:dash_master_toolkit/quality_control/service/qc_file_saver_stub.dart';
import 'package:dash_master_toolkit/quality_control/service/quality_control_service.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_comparison_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_history_screen.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;

import 'fixtures/quality_control_config.dart';

double? _rate(int n, int d) => d == 0 ? null : (n / d * 10000).round() / 100;

Map<String, dynamic> _kpis(String start, String end, int total, int c, int nc, int av, {int pc = 0, int pnc = 0, int machines = 0, int releves = 0}) {
  final valides = c + nc;
  return {
    'start': start,
    'end': end,
    'total': total,
    'releves': releves,
    'conformes': c,
    'nonConformes': nc,
    'aVerifier': av,
    'valides': valides,
    'parametresControles': pc,
    'parametresNonConformes': pnc,
    'machinesControlees': machines,
    'tauxConformite': _rate(c, valides),
    'tauxNonConformite': _rate(nc, valides),
    'moyenneParametresControles': total == 0 ? null : (pc / total * 100).round() / 100,
    'moyenneParametresNonConformes': total == 0 ? null : (pnc / total * 100).round() / 100,
    'dataLevel': total == 0 ? 'none' : (total < 2 ? 'limited' : 'ok'),
  };
}

const _counts = ['total', 'releves', 'conformes', 'nonConformes', 'aVerifier', 'parametresControles', 'parametresNonConformes', 'machinesControlees'];

/// Même règle que le backend : aucune variation quand une période est vide.
Map<String, dynamic> _evo(Map<String, dynamic> a, Map<String, dynamic> b) {
  final comparable = (a['total'] as int) > 0 && (b['total'] as int) > 0;
  num? diff(String k) => !comparable || a[k] == null || b[k] == null ? null : (((b[k] as num) - (a[k] as num)) * 100).round() / 100;
  return {
    for (final k in _counts)
      k: {
        'absolue': comparable ? (b[k] as int) - (a[k] as int) : null,
        'relative': !comparable || (a[k] as int) == 0 ? null : (((b[k] as int) - (a[k] as int)) / (a[k] as int) * 10000).round() / 100,
      },
    for (final k in ['tauxConformite', 'tauxNonConformite']) k: {'points': diff(k)},
    for (final k in ['moyenneParametresControles', 'moyenneParametresNonConformes']) k: {'absolue': diff(k)},
  };
}

Map<String, dynamic> _param(String type, String key, String label, String section, String group, int ca, int nca, int cb, int ncb) {
  final ra = _rate(ca - nca, ca);
  final rb = _rate(cb - ncb, cb);
  return {
    'type': type,
    'key': key,
    'label': label,
    'section': section,
    'sectionLabel': section,
    'group': group,
    'periodA': {'controles': ca, 'nonConformes': nca, 'tauxConformite': ra},
    'periodB': {'controles': cb, 'nonConformes': ncb, 'tauxConformite': rb},
    'evolutionPoints': ra == null || rb == null ? null : ((rb - ra) * 100).round() / 100,
    'limited': ca > 0 && cb > 0 && (ca < 2 || cb < 2),
  };
}

/// Réponse au format de GET /quality-control/comparison, filtrée comme le
/// backend (ligne, machine, poste). [data] : 'ok', 'emptyA', 'empty',
/// 'limited'.
Map<String, dynamic> _comparison(Map<String, String> q, {String data = 'ok', int extraB = 0}) {
  final type = q['productionType'];
  final machine = q['machine'];
  final a = switch (data) {
    'emptyA' || 'empty' => _kpis('2024-01-01', '2024-01-31', 0, 0, 0, 0),
    'limited' => _kpis('2026-09-01', '2026-09-15', 1, 1, 0, 0, pc: 12, machines: 1, releves: 1),
    _ => _kpis('2026-09-01', '2026-09-15', 25, 20, 5, 0, pc: 300, pnc: 9, machines: 3, releves: 40),
  };
  final b = data == 'empty'
      ? _kpis('2024-02-01', '2024-02-29', 0, 0, 0, 0)
      : _kpis('2026-09-16', '2026-09-30', 31 + extraB, 25 + extraB, 6, 0, pc: 370, pnc: 8, machines: 4, releves: 52);
  final comparable = (a['total'] as int) > 0 && (b['total'] as int) > 0;
  final types = [for (final t in ['PROMESH', 'PROBAR']) if (type == null || type == t) t];
  final machines = [
    for (final (t, m, rate) in [('PROMESH', '1', 88.0), ('PROMESH', '2', 96.0), ('PROBAR', '1', 91.0)])
      if (types.contains(t) && (machine == null || machine == m)) (t, m, rate),
  ];
  final ranked = [...machines]..sort((x, y) => y.$3.compareTo(x.$3));
  final params = !comparable
      ? <Map<String, dynamic>>[]
      : [
          _param('PROMESH', 'treillis_qualite_intersections', 'QUALITÉ DES INTERSECTIONS', 'Assemblage', 'treillis', 8, 1, 10, 0),
          _param('PROMESH', 'treillis_positionnement_fils', 'POSITIONNEMENT DES FILS', 'Assemblage', 'treillis', 25, 1, 27, 3),
          _param('PROMESH', 'vitesse_tirage', 'VITESSE DE TIRAGE', 'Paramètres de ligne', 'releve', 20, 0, 22, 0),
          _param('PROBAR', 'diametre_bar', 'DIAMÈTRE DE LA BARRE', 'Barre', 'releve', 10, 2, 12, 1),
          _param('PROBAR', 'ovalisation', 'OVALISATION', 'Barre', 'releve', 1, 0, 1, 1),
        ].where((p) => types.contains(p['type'])).toList();
  final moved = params.where((p) => p['evolutionPoints'] != null && p['evolutionPoints'] != 0).toList();
  final messages = [
    if (data == 'empty') {'code': 'NO_DATA', 'text': 'Pas suffisamment de données pour cette analyse'},
    if ((a['total'] as int) == 0) {'code': 'NO_DATA_A', 'text': 'Aucune donnée disponible pour la période A'},
    if ((b['total'] as int) == 0) {'code': 'NO_DATA_B', 'text': 'Aucune donnée disponible pour la période B'},
    if (data == 'emptyA') {'code': 'INSUFFICIENT', 'text': 'Comparaison impossible : données insuffisantes'},
    if (data == 'limited') {'code': 'LIMITED_A', 'text': 'Données limitées : la période A ne contient qu\'un seul contrôle qualité'},
  ];
  return {
    'filters': {'productionType': type, 'machine': machine, 'poste': q['poste'], 'controller': q['controller'], 'result': q['result']},
    'options': {
      'controllers': [
        {'id': 'u-qc', 'email': 'controle_qualite@cbi-tunisia.com', 'label': 'Contrôle Qualité'},
      ],
    },
    'controleur': 'controle_qualite@cbi-tunisia.com',
    'dataStatus': data == 'ok' ? 'ok' : (data == 'emptyA' ? 'insufficient' : data),
    'messages': messages,
    'comparable': comparable,
    'periodA': a,
    'periodB': b,
    'evolution': _evo(a, b),
    'byType': [
      for (final t in types) {'type': t, 'label': t, 'periodA': a, 'periodB': b, 'evolution': _evo(a, b)},
    ],
    'byMachine': [
      for (final (t, m, _) in machines) {'type': t, 'machine': m, 'label': '$t · Machine $m', 'periodA': a, 'periodB': b, 'evolution': _evo(a, b)},
    ],
    'ranking': !comparable || machine != null || ranked.length < 2
        ? null
        : {
            'period': 'B',
            'machines': [
              for (final (t, m, rate) in ranked) {'type': t, 'machine': m, 'label': '$t · Machine $m', 'tauxConformite': rate, 'valides': 5},
            ],
          },
    'byShift': [
      for (final (p, label) in [('matin', 'Matin'), ('soir', 'Soir')])
        if (q['poste'] == null || q['poste'] == p) {'poste': p, 'label': label, 'periodA': a, 'periodB': b, 'evolution': _evo(a, b)},
    ],
    'shiftInsight': comparable && q['poste'] == null ? 'Le poste Soir présente un taux de non-conformité supérieur de 5,0 points au poste Matin sur la période B.' : null,
    'daily': {
      'periodA': comparable
          ? [
              {'date': '2026-09-01', 'total': 2, 'valides': 2, 'conformes': 2, 'nonConformes': 0, 'tauxConformite': 100},
              {'date': '2026-09-05', 'total': 2, 'valides': 2, 'conformes': 1, 'nonConformes': 1, 'tauxConformite': 50},
              {'date': '2026-09-10', 'total': 1, 'valides': 0, 'conformes': 0, 'nonConformes': 0, 'tauxConformite': null},
            ]
          : [],
      'periodB': (b['total'] as int) == 0
          ? []
          : [
              {'date': '2026-09-16', 'total': 5, 'valides': 5, 'conformes': 4, 'nonConformes': 1, 'tauxConformite': 80},
              {'date': '2026-09-20', 'total': 3, 'valides': 3, 'conformes': 3, 'nonConformes': 0, 'tauxConformite': 100},
            ],
    },
    'parameters': params,
    'improvements': moved.where((p) => (p['evolutionPoints'] as num) > 0).toList(),
    'attentionPoints': moved.where((p) => (p['evolutionPoints'] as num) < 0).toList(),
    'analysis': switch (data) {
      'empty' => ['Pas suffisamment de données pour cette analyse : aucun contrôle qualité sur les deux périodes.'],
      'emptyA' => ['Comparaison impossible : données insuffisantes (aucun contrôle qualité sur la période A).'],
      _ => [
          if (data == 'limited') 'Données limitées : la période A ne contient qu\'un seul contrôle qualité ; les écarts ne constituent pas une tendance fiable.',
          'Le nombre de contrôles qualité est passé de ${a['total']} à ${b['total']} (+24,0 %).',
          'Le taux de conformité est passé de 80,0 % à 80,6 % entre les deux périodes, soit une amélioration de 0,6 point.',
          'La diminution des non-conformités concerne principalement les paramètres « Assemblage » (2 → 1).',
        ],
    },
    'byParameter': [],
  };
}

class _FakeApi implements HttpClientAdapter {
  final requests = <Uri>[];
  String data = 'ok';
  int extraB = 0;

  ResponseBody _json(Object body) =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  ResponseBody _bytes(List<int> bytes) => ResponseBody.fromBytes(bytes, 200);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(o.uri);
    final path = o.uri.path;
    final format = o.uri.queryParameters['format'];
    if (path.endsWith('/quality-control/config')) return _json({'success': true, 'data': jsonDecode(kQualityControlConfig)});
    if (path.endsWith('/quality-control/comparison')) {
      return _json({'success': true, 'data': _comparison(o.uri.queryParameters, data: data, extraB: extraB)});
    }
    if (path.endsWith('/export')) {
      // xlsx = archive ZIP (PK) ; pdf = %PDF- ; csv = texte.
      return _bytes(format == 'pdf' ? utf8.encode('%PDF-1.3 test') : (format == 'csv' ? utf8.encode('Date;Heure\r\n') : [0x50, 0x4B, 3, 4, 0, 0]));
    }
    if (path.endsWith('/quality-control')) {
      return _json({'success': true, 'data': [], 'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1}});
    }
    return _json({'success': true, 'data': {}});
  }

  @override
  void close({bool force = false}) {}

  Map<String, String> get lastComparison => requests.lastWhere((u) => u.path.endsWith('/comparison')).queryParameters;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester tester, {double width = 1440}) async {
  tester.view.physicalSize = Size(width, 12000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: QualityControlComparisonScreen()));
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _compare(WidgetTester tester) async {
  await tester.tap(find.text('Comparer'));
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

/// Choisit [option] dans la liste déroulante qui affiche [current].
Future<void> _select(WidgetTester tester, String current, String option) async {
  await tester.tap(find.text(current).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String _isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late _FakeApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_cmp_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'controle_qualite', 'userEmail': 'controle_qualite@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    api = _FakeApi();
    ApiClient.instance.dio.httpClientAdapter = api;
    qcLastSavedFile = null;
  });

  group('règles d\'affichage (logique pure)', () {
    test('évolutions : nombres en %, taux en points, N/A si non calculable, jamais NaN', () {
      expect(qcFormatEvolution(QcKpiKind.count, const QcEvolution(absolue: 6, relative: 24)), '+6 (+24,0 %)');
      expect(qcFormatEvolution(QcKpiKind.count, const QcEvolution(absolue: -1, relative: -25)), '-1 (-25,0 %)');
      expect(qcFormatEvolution(QcKpiKind.count, const QcEvolution(absolue: 3, relative: null)), '+3 (N/A)');
      // Période vide : aucune variation (ni « +31 », ni « +100 % »).
      expect(qcFormatEvolution(QcKpiKind.count, const QcEvolution()), 'N/A');
      expect(qcFormatEvolution(QcKpiKind.rate, const QcEvolution(points: 5)), '+5,0 pt');
      expect(qcFormatEvolution(QcKpiKind.rate, const QcEvolution(points: 3.7), longPoints: true), '+3,7 points'); // points, pas %
      expect(qcFormatEvolution(QcKpiKind.rate, const QcEvolution(points: null)), 'N/A');
      expect(qcFormatPoints(-7, long: true), '-7,0 points');
      expect(qcFormatPoints(1, long: true), '+1,0 point');
      expect(qcFormatPoints(double.nan), 'N/A');
      expect(qcFormatKpi(QcKpiKind.rate, 80.65), '80,7 %');
      expect(qcFormatKpi(QcKpiKind.rate, null), 'N/A');
      expect(qcFormatKpi(QcKpiKind.rate, double.nan), 'N/A');
      expect(qcFormatKpi(QcKpiKind.count, 0), '0');
      expect(qcEvolutionSign(QcKpiKind.rate, const QcEvolution(points: -0.7)), -1);
      expect(kQcComparisonKpis, hasLength(12));
    });

    test('raccourcis de période (lundi 5 octobre 2026)', () {
      final now = DateTime(2026, 10, 5, 14, 30);
      String range(String preset) {
        final r = qcPeriodRange(preset, now)!;
        return '${_isoDay(r.$1)}→${_isoDay(r.$2)}';
      }

      expect(range('today'), '2026-10-05→2026-10-05');
      expect(range('week'), '2026-10-05→2026-10-11');
      expect(range('prevWeek'), '2026-09-28→2026-10-04');
      expect(range('month'), '2026-10-01→2026-10-31');
      expect(range('prevMonth'), '2026-09-01→2026-09-30');
      expect(range('quarter'), '2026-10-01→2026-12-31');
      expect(range('prevQuarter'), '2026-07-01→2026-09-30');
      expect(range('year'), '2026-01-01→2026-12-31');
      expect(range('prevYear'), '2025-01-01→2025-12-31');
      expect(qcPeriodRange('custom', now), isNull);
      // Passage d'année : janvier → décembre / 4e trimestre précédents.
      final jan = DateTime(2027, 1, 3); // dimanche
      expect(_isoDay(qcPeriodRange('prevMonth', jan)!.$1), '2026-12-01');
      expect(_isoDay(qcPeriodRange('prevQuarter', jan)!.$1), '2026-10-01');
      expect(_isoDay(qcPeriodRange('week', jan)!.$1), '2026-12-28');
      expect(kQcPeriodPresets.map((p) => p.$2), ['Aujourd\'hui', 'Cette semaine', 'Semaine précédente', 'Ce mois', 'Mois précédent', 'Ce trimestre', 'Trimestre précédent', 'Cette année', 'Année précédente', 'Personnalisé']);
    });

    test('réponse API → modèle (KPI, classement, paramètres, postes, analyse)', () {
      final c = QualityComparison.fromJson(_comparison(const {}));
      expect([c.a.total, c.a.conformes, c.a.nonConformes, c.b.total, c.a.machinesControlees, c.b.releves], [25, 20, 5, 31, 3, 52]);
      expect(c.a.tauxConformite, 80);
      expect(c.a.moyenneParametresControles, 12);
      expect(c.evolution['total']!.relative, 24);
      expect(c.evolution['tauxConformite']!.points, closeTo(0.65, 0.001));
      expect(c.comparable, isTrue);
      expect(c.ranking!.map((m) => m.label), ['PROMESH · Machine 2', 'PROBAR · Machine 1', 'PROMESH · Machine 1']);
      expect(c.byShift.map((s) => s.poste), ['matin', 'soir']);
      expect(c.improvements.map((p) => p.key), ['treillis_qualite_intersections', 'diametre_bar']);
      expect(c.attentionPoints.map((p) => p.key), ['treillis_positionnement_fils', 'ovalisation']);
      expect(c.parameters.firstWhere((p) => p.key == 'ovalisation').limited, isTrue);
      expect(c.dailyA.map((d) => d.tauxConformite), [100, 50, null]);
      expect(c.controllers.single.label, 'Contrôle Qualité');

      final noA = QualityComparison.fromJson(_comparison(const {}, data: 'emptyA'));
      expect(noA.a.tauxConformite, isNull);
      expect(noA.comparable, isFalse);
      expect(noA.dataStatus, 'insufficient');
      expect(noA.evolution['total']!.absolue, isNull);
      expect(noA.messages, ['Aucune donnée disponible pour la période A', 'Comparaison impossible : données insuffisantes']);
      expect(QualityComparison.fromJson(_comparison(const {}, data: 'empty')).isEmpty, isTrue);
    });

    test('noms des fichiers exportés', () {
      expect(qcHistoryExportFileName(productionType: 'PROMESH', machine: '1', from: '2026-09-01', to: '2026-09-30', ext: 'xlsx'),
          'Rapport_Controle_Qualite_PROMESH_Machine1_2026-09-01_2026-09-30.xlsx');
      expect(qcHistoryExportFileName(ext: 'pdf', now: DateTime(2026, 10, 1)), 'Rapport_Controle_Qualite_2026-10-01.pdf');
      expect(qcComparisonExportFileName('2026-09-01', '2026-09-30', 'xlsx'), 'Comparaison_Qualite_2026-09-01_2026-09-30.xlsx');
    });
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('TEST 1 — ${width.toInt()}px : KPI, variations, graphiques, paramètres, filtres, export', (tester) async {
      await _open(tester, width: width);

      // Requête initiale : mois précédent / mois en cours.
      final now = DateTime.now();
      expect(api.lastComparison['periodAStart'], _isoDay(DateTime(now.year, now.month - 1, 1)));
      expect(api.lastComparison['periodBEnd'], _isoDay(DateTime(now.year, now.month + 1, 0)));

      // 12 KPI : période A, période B, variation (valeurs de l'API).
      expect(find.text('Indicateurs'), findsOneWidget);
      for (final def in kQcComparisonKpis) {
        expect(find.text(def.label.toUpperCase()), findsOneWidget, reason: def.label);
      }
      expect(find.text('+6 (+24,0 %)'), findsWidgets); // contrôles
      expect(find.text('+0,7 point'), findsWidgets); // taux en POINTS
      expect(find.text('80,0 %'), findsWidgets);
      expect(find.text('Variation non calculée'), findsNothing);

      // Graphiques : barres (catégories), courbe (jours), barres de conformité.
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Évolution du taux de conformité'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      // Toutes les lignes : blocs séparés, classement des machines.
      expect(find.text('PROMESH / PROBAR'), findsOneWidget);
      expect(find.text('Classement des machines'), findsOneWidget);
      expect(find.text('Meilleure performance'), findsOneWidget);
      expect(find.text('Performance à surveiller'), findsOneWidget);
      expect(find.text('96,0 %'), findsWidgets);

      // Paramètres, améliorations, points d'attention, postes, analyse.
      expect(find.text('Évolution des paramètres'), findsOneWidget);
      expect(find.text('QUALITÉ DES INTERSECTIONS'), findsNWidgets(2)); // tableau + amélioration
      expect(find.text('Treillis GFRP · Assemblage'), findsNWidgets(2));
      expect(find.text('DIAMÈTRE DE LA BARRE'), findsNWidgets(2));
      expect(find.text('Améliorations'), findsOneWidget);
      expect(find.text('Points d\'attention'), findsOneWidget);
      expect(find.text('87,5 % → 100,0 %'), findsOneWidget);
      expect(find.text('+12,5 points'), findsOneWidget);
      expect(find.text('96,0 % → 88,9 %'), findsOneWidget);
      expect(find.text('-7,1 points'), findsOneWidget);
      expect(find.text('Données limitées'), findsNWidgets(2)); // ovalisation : 1 mesure par période
      expect(find.text('Matin / Soir'), findsOneWidget);
      expect(find.text('Le poste Soir présente un taux de non-conformité supérieur de 5,0 points au poste Matin sur la période B.'), findsOneWidget);
      expect(find.text('Analyse'), findsOneWidget);
      expect(find.text('Le taux de conformité est passé de 80,0 % à 80,6 % entre les deux périodes, soit une amélioration de 0,6 point.'), findsOneWidget);

      // Filtres appliqués aux deux périodes : raccourci, ligne, poste, résultat.
      await _select(tester, 'Mois précédent', 'Année précédente');
      await tester.tap(find.text('PROMESH').first);
      await tester.pump();
      await _select(tester, 'Tous les postes', 'Soir');
      await _select(tester, 'Tous les résultats', 'Non conforme');
      await _select(tester, 'Tous les contrôleurs', 'Contrôle Qualité');
      await _compare(tester);
      final q = api.lastComparison;
      expect(q['periodAStart'], '${now.year - 1}-01-01');
      expect(q['periodAEnd'], '${now.year - 1}-12-31');
      expect(q['productionType'], 'PROMESH');
      expect(q['poste'], 'soir');
      expect(q['result'], 'NON_CONFORME');
      expect(q['controller'], 'u-qc');
      // Un seul poste filtré : pas de comparaison Matin / Soir.
      expect(find.text('Matin / Soir'), findsNothing);

      // Export de la comparaison (Excel) : mêmes périodes et filtres.
      await tester.tap(find.text('Exporter la comparaison'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excel (.xlsx)'));
      await _settle(tester);
      final exportReq = api.requests.lastWhere((u) => u.path.endsWith('/comparison/export')).queryParameters;
      expect(exportReq['format'], 'xlsx');
      for (final k in ['periodAStart', 'periodAEnd', 'periodBStart', 'periodBEnd', 'productionType', 'poste', 'result', 'controller']) {
        expect(exportReq[k], q[k], reason: k);
      }
      expect(qcLastSavedFile!.name, 'Comparaison_Qualite_${now.year - 1}-01-01_${q['periodBEnd']}.xlsx');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TEST 2 — période A sans données : message, aucune variation, aucun graphique', (tester) async {
    api.data = 'emptyA';
    await _open(tester);
    expect(find.text('Aucune donnée disponible pour la période A'), findsOneWidget);
    expect(find.text('Comparaison impossible : données insuffisantes'), findsOneWidget);
    // Les chiffres de la période B restent lisibles, sans variation.
    expect(find.text('Indicateurs'), findsOneWidget);
    expect(find.text('31'), findsWidgets);
    expect(find.text('Variation non calculée'), findsNWidgets(12));
    expect(find.textContaining('+31'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
    for (final absent in ['Classement des machines', 'Évolution des paramètres', 'Améliorations', 'Points d\'attention', 'Matin / Soir', 'PROMESH / PROBAR']) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Comparaison impossible : données insuffisantes (aucun contrôle qualité sur la période A).'), findsOneWidget);
  });

  testWidgets('aucune donnée sur les deux périodes : « Pas suffisamment de données », aucun KPI', (tester) async {
    api.data = 'empty';
    await _open(tester);
    expect(find.text('Pas suffisamment de données pour cette analyse'), findsOneWidget);
    expect(find.text('Aucune donnée disponible pour la période A'), findsOneWidget);
    expect(find.text('Aucune donnée disponible pour la période B'), findsOneWidget);
    expect(find.text('Indicateurs'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('un seul contrôle sur une période : « Données limitées », analyse présentée avec réserve', (tester) async {
    api.data = 'limited';
    await _open(tester);
    expect(find.text('Données limitées : la période A ne contient qu\'un seul contrôle qualité'), findsOneWidget);
    expect(find.textContaining('les écarts ne constituent pas une tendance fiable'), findsOneWidget);
    expect(find.text('Indicateurs'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('TEST 3 — PROMESH : treillis GFRP, aucun paramètre PROBAR, pas de bloc inter-lignes', (tester) async {
    await _open(tester);
    await tester.tap(find.text('PROMESH').first);
    await tester.pump();
    await _compare(tester);
    expect(api.lastComparison['productionType'], 'PROMESH');
    expect(find.text('Treillis GFRP · Assemblage'), findsNWidgets(2));
    expect(find.text('POSITIONNEMENT DES FILS'), findsNWidgets(2)); // tableau + point d'attention
    expect(find.text('DIAMÈTRE DE LA BARRE'), findsNothing);
    expect(find.text('OVALISATION'), findsNothing);
    expect(find.text('PROMESH / PROBAR'), findsNothing);
  });

  testWidgets('TEST 4 — PROBAR : paramètres PROBAR, aucun paramètre treillis GFRP', (tester) async {
    await _open(tester);
    await tester.tap(find.text('PROBAR').first);
    await tester.pump();
    await _compare(tester);
    expect(api.lastComparison['productionType'], 'PROBAR');
    expect(find.text('DIAMÈTRE DE LA BARRE'), findsNWidgets(2));
    expect(find.text('OVALISATION'), findsNWidgets(2));
    expect(find.textContaining('Treillis GFRP ·'), findsNothing);
    expect(find.text('QUALITÉ DES INTERSECTIONS'), findsNothing);
    // Une seule machine PROBAR dans les données : pas de classement inventé.
    expect(find.text('Classement des machines'), findsNothing);
    expect(find.text('Comparaison par machine'), findsOneWidget);
    expect(find.textContaining('Classement non établi'), findsOneWidget);
  });

  testWidgets('TEST 5 — Machine 1 : son évolution, pas de classement ; machines proposées par la ligne', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Toutes machines'));
    await tester.pumpAndSettle();
    for (final m in ['Machine 1', 'Machine 2', 'Machine 3', 'Machine 4']) {
      expect(find.text(m), findsWidgets, reason: m);
    }
    await tester.tap(find.text('Machine 1').last);
    await tester.pumpAndSettle();
    await _compare(tester);
    expect(api.lastComparison['machine'], '1');
    expect(find.text('Évolution de la machine'), findsOneWidget);
    expect(find.text('Classement des machines'), findsNothing);
    expect(find.text('Meilleure performance'), findsNothing);
    expect(find.text('Machine 2'), findsNothing);
  });

  testWidgets('TEST 7 / 8 — contrôle créé, modifié ou validé : la comparaison est recalculée (aucun cache)', (tester) async {
    await _open(tester);
    final before = api.requests.where((u) => u.path.endsWith('/comparison')).length;
    expect(find.text('31'), findsWidgets);
    expect(find.text('32'), findsNothing);

    // Une écriture du module (création / modification / validation) incrémente
    // `revision` : l'écran relit l'API.
    api.extraB = 1;
    QualityControlService.instance.revision.value++;
    await _settle(tester);
    expect(api.requests.where((u) => u.path.endsWith('/comparison')).length, before + 1);
    expect(find.text('32'), findsWidgets);
    expect(find.text('+7 (+28,0 %)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Historique : « Exporter » envoie EXACTEMENT les filtres de l\'écran', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: QualityControlHistoryScreen()));
    await _settle(tester);
    await tester.tap(find.text('PROMESH').first); // filtre ligne
    await _settle(tester);
    await tester.tap(find.text('Non conforme').first); // filtre résultat
    await _settle(tester);
    final listQuery = api.requests.lastWhere((u) => u.path.endsWith('/quality-control')).queryParameters;

    for (final (label, format) in [('Excel (.xlsx)', 'xlsx'), ('PDF (A4)', 'pdf'), ('CSV (;)', 'csv')]) {
      await tester.tap(find.text('Exporter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await _settle(tester);
      final q = api.requests.lastWhere((u) => u.path.endsWith('/quality-control/export')).queryParameters;
      expect(q['format'], format);
      for (final k in ['productionType', 'status']) {
        expect(q[k], listQuery[k], reason: k); // mêmes filtres que la liste
      }
      expect(q['productionType'], 'PROMESH');
      expect(q['status'], 'NON_CONFORME');
      expect(qcLastSavedFile!.name, startsWith('Rapport_Controle_Qualite_PROMESH_'));
      expect(qcLastSavedFile!.name, endsWith('.$format'));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('English — comparison screen: no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    await _open(tester);
    for (final text in [
      'Quality comparison',
      'Periods and filters',
      'Indicators',
      'Machine ranking',
      'Best performance',
      'Parameter trends',
      'Improvements',
      'Points of attention',
      'Morning / Evening',
      'Analysis',
      'Compare',
      'Period A',
      'Previous month',
      'All shifts',
      'The compliance rate went from 80,0 % to 80,6 % between the two periods, an improvement of 0,6 point.',
      'The Evening shift has a non-compliance rate 5,0 points higher than the Morning shift over period B.',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Classement des machines'), findsNothing);
    expect(QcI18n.frenchResidue(), isEmpty);

    // États sans données : messages traduits eux aussi.
    api.data = 'emptyA';
    await tester.tap(find.text('Compare'));
    await _settle(tester);
    expect(find.text('No data available for period A'), findsOneWidget);
    expect(find.text('Comparison not possible: insufficient data'), findsOneWidget);
    expect(find.text('Change not computed'), findsNWidgets(12));
    expect(QcI18n.frenchResidue(), isEmpty);
  });
}
