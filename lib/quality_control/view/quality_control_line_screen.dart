// lib/quality_control/view/quality_control_line_screen.dart
//
// Contrôle Qualité — page d'une ligne (/quality-control/promesh | /probar) :
// indicateurs de la ligne, cartes machines (contrôles, dernier contrôle,
// dernier résultat), derniers contrôles de la ligne.
//
// Machines : GET /quality-control/config (celles du module Production).
// Compteurs : GET /quality-control/stats?period=all (une requête, en cache).

import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_home_screen.dart' show showQcNewControlDialog;
import 'quality_control_sync.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

class QualityControlLineScreen extends StatefulWidget {
  final String type; // PROMESH | PROBAR
  const QualityControlLineScreen({super.key, required this.type});

  @override
  State<QualityControlLineScreen> createState() => _QualityControlLineScreenState();
}

class _QualityControlLineScreenState extends State<QualityControlLineScreen> with QcSyncMixin {
  final _svc = QualityControlService.instance;
  final bool _canCreate = AuthService().isControleQualite;
  late final String _type = widget.type.toUpperCase();

  QualityConfig? _config;
  QualityStats? _stats;
  List<QualityControlModel>? _recent;
  String? _error;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _stats = _svc.cachedStats(qcPeriod);
    _load();
  }

  // Écriture ailleurs dans le module ou période modifiée : relecture API.
  @override
  Future<void> qcReload() {
    setState(() => _stats = _svc.cachedStats(qcPeriod));
    return _load();
  }

  String get _periodLabel => kQualityStatsPeriods.firstWhere((p) => p.$1 == qcPeriod, orElse: () => ('', '')).$2;

  Future<void> _load({bool refresh = false}) async {
    await Future.wait([
      () async {
        try {
          final c = await _svc.fetchConfig(refresh: refresh);
          if (mounted) {
            setState(() {
              _config = c;
              _error = null;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _error = e.toString());
        }
      }(),
      () async {
        try {
          final period = qcPeriod;
          final s = await _svc.fetchStats(period: period);
          if (mounted && period == qcPeriod) {
            setState(() {
              _stats = s;
              _statsError = null;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _statsError = e.toString());
        }
      }(),
      () async {
        try {
          final period = qcPeriod;
          final p = await _svc.fetchHistoryPage(productionType: _type, limit: 8, period: period);
          if (mounted && period == qcPeriod) setState(() => _recent = p.items);
        } catch (_) {
          if (mounted) setState(() => _recent = const []);
        }
      }(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(_type);
    final line = _config?.line(_type);
    final lineStats = _stats?.line(_type);
    String? v(int Function(QualityCounts c) pick) =>
        lineStats != null ? qcFormatInt(pick(lineStats.counts)) : (_statsError != null ? '—' : null);

    return QcPage(
      onRefresh: () => _load(refresh: true),
      children: [
        QcPageHeader(
          crumbs: [('Contrôle Qualité', QcPaths.root), (_type, null)],
          title: _type,
          subtitle: 'Choisissez une machine pour consulter ou créer un contrôle qualité.',
          icon: productionTypeIcon(_type),
          color: color,
          onBack: () => context.go(QcPaths.root),
          actions: [
            QcPeriodSelector(value: qcPeriod, onChanged: qcSetPeriod),
            OutlinedButton.icon(
              onPressed: () => context.go(QcPaths.historySearch(_type)),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Historique'),
            ),
            if (_canCreate && line != null)
              FilledButton.icon(
                onPressed: () => showQcNewControlDialog(context, line, stats: lineStats),
                style: FilledButton.styleFrom(backgroundColor: color),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau contrôle qualité'),
              ),
          ],
        ),
        if (_error != null) QcErrorBanner('Configuration indisponible : $_error', onRetry: () => _load(refresh: true)),
        if (_statsError != null) QcErrorBanner('Statistiques indisponibles : $_statsError', onRetry: () => _load(refresh: true)),
        if (!_canCreate) const QcReadOnlyNote(),
        qcGrid(columns: qcColumnsFor(200, max: 5), [
          QcKpiTile(
            icon: kMachineIcon,
            label: 'Machines',
            value: line == null ? (_error != null ? '—' : null) : qcFormatInt(line.machines.length),
            color: color,
          ),
          QcKpiTile(icon: Icons.fact_check_outlined, label: 'Contrôles qualité', value: v((c) => c.total), caption: _periodLabel, color: color),
          QcKpiTile(icon: Icons.format_list_numbered_rounded, label: 'Prélèvements', value: v((c) => c.releves), caption: 'dans ces contrôles qualité', color: kCrmTextSub),
          QcKpiTile(icon: Icons.check_circle_outline_rounded, label: 'Conformes', value: v((c) => c.conforme), color: kCrmSuccess),
          QcKpiTile(icon: Icons.cancel_outlined, label: 'Non conformes', value: v((c) => c.nonConforme), color: kCrmDanger),
          QcKpiTile(icon: Icons.schedule_rounded, label: 'À vérifier', value: v((c) => c.aVerifier), color: kCrmWarning),
        ]),
        const SizedBox(height: 16),
        QcSection(
          icon: kMachineIcon,
          title: 'Machines $_type',
          subtitle: line == null ? null : '${line.machines.length} machines · contrôles qualité : $_periodLabel · dernier contrôle qualité : toutes périodes',
          color: color,
          children: [
            if (_config == null && _error == null)
              qcGrid(columns: qcColumnsFor(240, max: 4), [for (var i = 0; i < 4; i++) const QcSkeleton(height: 190, radius: kQcRadius)])
            else if (line == null)
              QcEmptyState('Ligne de production inconnue : $_type', icon: Icons.error_outline_rounded)
            else
              qcGrid(columns: qcColumnsFor(240, max: 4), [
                for (final m in line.machines)
                  QcMachineCard(
                    type: _type,
                    machine: m,
                    stats: lineStats?.machine(m),
                    statsUnavailable: _stats == null && _statsError != null,
                    onOpen: () => context.go(QcPaths.machine(_type, m)),
                  ),
              ]),
          ],
        ),
        QcSection(
          icon: Icons.history_rounded,
          title: 'Derniers contrôles qualité $_type',
          subtitle: _periodLabel,
          trailing: TextButton(onPressed: () => context.go(QcPaths.historySearch(_type)), child: const Text('Tout voir')),
          children: [
            QcControlsTable(
              controls: _recent ?? const [],
              loading: _recent == null,
              emptyText: 'Aucun contrôle qualité $_type pour le moment',
            ),
          ],
        ),
      ],
    );
  }
}
