// lib/quality_control/quality_control_routes.dart
//
// Module CONTRÔLE QUALITÉ — chemins et arbre de routes GoRouter, SANS
// dépendance vers les écrans (fabriques injectées par MyRoute) : l'arbre réel
// est ainsi testable sur la VM (test/quality_control_navigation_test.dart).
//
// /quality-control                       accueil (tableau de bord)
// /quality-control/promesh               machines PROMESH
// /quality-control/promesh/machine/:num  machine PROMESH
// /quality-control/probar                machines PROBAR
// /quality-control/probar/machine/:num   machine PROBAR
// /quality-control/history[?q=]          historique (recherche globale, export)
// /quality-control/comparison            comparaison qualité période A / B
// /quality-control/control/:id[?type=&machine=]  fiche qualité EXISTANTE (édition / lecture)
// /quality-control/control?type=&machine=        NOUVELLE fiche qualité d'une machine
// /quality-control/controle?…                    ancien chemin → redirigé (liens existants)
//
// CLÉS DE PAGE — cause de l'assertion `!keyReservation.contains(key)` : deux
// pages de la MÊME pile du Navigator portaient la même clé (parent et enfant
// imbriqués recevaient `ValueKey(state.uri.toString())` ; or `state.uri` est
// l'URL complète courante, identique pour toutes les routes de la pile).
// Ici chaque page a une clé CONSTANTE propre à sa route (qcPageKey*) : deux
// pages d'une même pile ne peuvent jamais partager une clé.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class QcPaths {
  static const root = '/quality-control';
  static const history = '/quality-control/history';
  static const comparison = '/quality-control/comparison';
  static const legacyHistory = '/quality-control/historique';
  static const form = '/quality-control/control';
  static const legacyForm = '/quality-control/controle';
  static const promesh = '/quality-control/promesh';
  static const probar = '/quality-control/probar';

  static String line(String type) => '$root/${type.toLowerCase()}';
  static String machine(String type, String machine) => '${line(type)}/machine/$machine';
  static String control(String id) => '$form/$id';
  static String newControl(String type, String machine) =>
      '$form?type=${type.toLowerCase()}&machine=${Uri.encodeQueryComponent(machine)}';
  static String historySearch(String query) =>
      query.trim().isEmpty ? history : '$history?q=${Uri.encodeQueryComponent(query.trim())}';
}

/// Lignes routées (chemins littéraux uniques). Les machines de chaque ligne
/// viennent du backend (GET /quality-control/config).
const kQcRoutedLines = ['PROMESH', 'PROBAR'];

const qcPageKeyHome = ValueKey<String>('qc-home');
const qcPageKeyHistory = ValueKey<String>('qc-history');
const qcPageKeyComparison = ValueKey<String>('qc-comparison');
ValueKey<String> qcPageKeyLine(String type) => ValueKey('qc-line-${type.toUpperCase()}');
ValueKey<String> qcPageKeyMachine(String type, String machine) => ValueKey('qc-machine-${type.toUpperCase()}-$machine');
ValueKey<String> qcPageKeyForm(String id) => ValueKey('qc-form-$id');
ValueKey<String> qcPageKeyNewForm(String type, String machine) => ValueKey('qc-form-new-${type.toUpperCase()}-$machine');

/// Fil d'Ariane global (en-tête de l'application) pour les routes du module :
/// (titre, parent, enfant) — null hors module.
(String, String, String)? qcBreadcrumb(String location) {
  if (location != QcPaths.root && !location.startsWith('${QcPaths.root}/')) return null;
  const module = 'Contrôle Qualité';
  final seg = location.substring(QcPaths.root.length).split('/').where((s) => s.isNotEmpty).toList();
  if (seg.isEmpty) return (module, module, 'Tableau de bord');
  final first = seg.first;
  if (first == 'history' || first == 'historique') return ('Historique', module, 'Historique');
  if (first == 'comparison') return ('Comparaison qualité', module, 'Comparaison qualité');
  if (first == 'control' || first == 'controle') return ('Contrôle Qualité', module, 'Contrôle Qualité');
  final line = first.toUpperCase();
  if (seg.length >= 3 && seg[1] == 'machine') return ('Machine ${seg[2]}', line, 'Machine ${seg[2]}');
  return (line, module, line);
}

/// Fabriques d'écrans injectées par le routeur de l'application.
class QcRouteScreens {
  final Widget Function() home;
  final Widget Function(String? query) history;
  final Widget Function() comparison;
  final Widget Function(String type) line;
  final Widget Function(String type, String machine) machine;
  final Widget Function(String controlId) form; // ÉDITION (id PostgreSQL)
  final Widget Function(String type, String machine) newForm; // CRÉATION (fiche d'une machine)

  const QcRouteScreens({
    required this.home,
    required this.history,
    required this.comparison,
    required this.line,
    required this.machine,
    required this.form,
    required this.newForm,
  });
}

GoRoute buildQualityControlRoute({
  required QcRouteScreens screens,
  required bool Function() canView,
  required String deniedRedirect,
}) {
  GoRoute lineRoute(String type) => GoRoute(
        path: type.toLowerCase(),
        pageBuilder: (context, state) => NoTransitionPage(key: qcPageKeyLine(type), child: screens.line(type)),
        routes: [
          GoRoute(
            path: 'machine/:num',
            pageBuilder: (context, state) {
              final num = state.pathParameters['num'] ?? '1';
              return NoTransitionPage(key: qcPageKeyMachine(type, num), child: screens.machine(type, num));
            },
          ),
        ],
      );

  return GoRoute(
    path: QcPaths.root,
    redirect: (context, state) => canView() ? null : deniedRedirect,
    pageBuilder: (context, state) => NoTransitionPage(key: qcPageKeyHome, child: screens.home()),
    routes: [
      GoRoute(
        path: 'history',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: qcPageKeyHistory, child: screens.history(state.uri.queryParameters['q'])),
      ),
      // Ancien chemin (liens existants) → nouveau, sans écran dupliqué.
      GoRoute(path: 'historique', redirect: (context, state) => QcPaths.history),
      GoRoute(
        path: 'comparison',
        pageBuilder: (context, state) => NoTransitionPage(key: qcPageKeyComparison, child: screens.comparison()),
      ),
      // Formulaire : basé sur type + machine (création) ou sur l'id de la
      // fiche (édition) — jamais sur une production.
      // Routes SŒURS (pas imbriquées) : une route enfant ferait construire
      // aussi la page de création sous la page d'édition.
      GoRoute(
        path: 'control',
        redirect: (context, state) {
          final q = state.uri.queryParameters;
          final create = (q['type'] ?? '').isNotEmpty && (q['machine'] ?? '').isNotEmpty;
          return create ? null : QcPaths.root;
        },
        pageBuilder: (context, state) {
          final type = state.uri.queryParameters['type']!.toUpperCase();
          final machine = state.uri.queryParameters['machine']!;
          return NoTransitionPage(key: qcPageKeyNewForm(type, machine), child: screens.newForm(type, machine));
        },
      ),
      GoRoute(
        path: 'control/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoTransitionPage(key: qcPageKeyForm(id), child: screens.form(id));
        },
      ),
      // Ancien chemin (?id= / ?type=&machine=) → nouveau, sans écran dupliqué.
      GoRoute(
        path: 'controle',
        redirect: (context, state) {
          final q = state.uri.queryParameters;
          if ((q['id'] ?? '').isNotEmpty) return QcPaths.control(q['id']!);
          if ((q['type'] ?? '').isNotEmpty && (q['machine'] ?? '').isNotEmpty) return QcPaths.newControl(q['type']!, q['machine']!);
          return QcPaths.root;
        },
      ),
      for (final type in kQcRoutedLines) lineRoute(type),
    ],
  );
}
