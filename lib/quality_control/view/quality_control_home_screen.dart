// lib/quality_control/view/quality_control_home_screen.dart
//
// Module CONTRÔLE QUALITÉ — tableau de bord (/quality-control). Hiérarchie :
// en-tête (période) → blocs PROMESH (bleu) / PROBAR (orange) avec leurs
// statistiques et leurs machines intégrées → derniers contrôles →
// statistiques générales (répartition par ligne) → actions rapides.
//
// Données : GET /quality-control/config (lignes + machines, celles du module
// Production — aucune inventée), GET /quality-control/stats (UNE requête pour
// tous les compteurs), GET /quality-control?limit=8 (derniers contrôles).
// Aucun chiffre en dur : une donnée indisponible s'affiche "—".

import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_sync.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

// Chemins du module (compatibilité des imports existants).
String qcLinePath(String type) => QcPaths.line(type);
String qcMachinePath(String type, String machine) => QcPaths.machine(type, machine);
String qcControlPath(String id) => QcPaths.control(id);

/// Flux de création : choix de la machine de [line], puis formulaire d'une
/// NOUVELLE fiche qualité de cette machine (production optionnelle).
Future<void> showQcNewControlDialog(BuildContext context, QualityProductionLine line, {QualityLineStats? stats}) async {
  final color = productionTypeColor(line.type);
  final machine = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      title: Row(children: [
        Icon(Icons.add_circle_outline_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text('Nouveau contrôle qualité ${line.label}', style: tInter(fontSize: 17, fontWeight: FontWeight.w800))),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Choisissez la machine : une nouvelle fiche qualité sera créée pour elle.', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          const SizedBox(height: 12),
          for (final m in line.machines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QcMachineTile(
                type: line.type,
                machine: m,
                stats: stats?.machine(m),
                onOpen: () => Navigator.of(ctx).pop(m),
              ),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler'))],
    ),
  );
  if (machine != null && context.mounted) context.go(QcPaths.newControl(line.type, machine));
}

class QualityControlHomeScreen extends StatefulWidget {
  const QualityControlHomeScreen({super.key});

  @override
  State<QualityControlHomeScreen> createState() => _QualityControlHomeScreenState();
}

class _QualityControlHomeScreenState extends State<QualityControlHomeScreen> with QcSyncMixin {
  final _svc = QualityControlService.instance;
  final bool _canCreate = AuthService().isControleQualite;

  QualityConfig? _config;
  QualityStats? _stats;
  List<QualityControlModel>? _recent;
  String? _configError;
  String? _statsError;
  String? _recentError;

  String get _period => qcPeriod;

  @override
  void initState() {
    super.initState();
    _stats = _svc.cachedStats(_period);
    _loadAll();
  }

  Future<void> _loadAll({bool refresh = false}) async {
    await Future.wait([_loadConfig(refresh: refresh), _loadStats(), _loadRecent()]);
  }

  // Écriture ailleurs dans le module ou période modifiée : relecture API
  // (statistiques + derniers contrôles), jamais de calcul local.
  @override
  Future<void> qcReload() {
    setState(() {
      _stats = _svc.cachedStats(_period); // null → squelettes pendant le chargement
      _statsError = null;
    });
    return Future.wait([_loadStats(), _loadRecent()]);
  }

  Future<void> _loadConfig({bool refresh = false}) async {
    try {
      final c = await _svc.fetchConfig(refresh: refresh);
      if (mounted) {
        setState(() {
          _config = c;
          _configError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _configError = e.toString());
    }
  }

  Future<void> _loadStats() async {
    final period = _period;
    try {
      final s = await _svc.fetchStats(period: period);
      if (mounted && period == _period) {
        setState(() {
          _stats = s;
          _statsError = null;
        });
      }
    } catch (e) {
      if (mounted && period == _period) setState(() => _statsError = e.toString());
    }
  }

  // Derniers contrôles qualité de la MÊME période que les compteurs.
  Future<void> _loadRecent() async {
    final period = _period;
    try {
      final page = await _svc.fetchHistoryPage(limit: 8, period: period);
      if (mounted && period == _period) {
        setState(() {
          _recent = page.items;
          _recentError = null;
        });
      }
    } catch (e) {
      if (mounted && period == _period) setState(() => _recentError = e.toString());
    }
  }

  void _setPeriod(String p) => qcSetPeriod(p);

  String get _periodLabel => kQualityStatsPeriods.firstWhere((p) => p.$1 == _period, orElse: () => ('', '')).$2;

  bool get _statsUnavailable => _stats == null && _statsError != null;

  // Hiérarchie : en-tête de page → PROMESH + PROBAR (statistiques + machines
  // intégrées) → derniers contrôles → statistiques générales → actions
  // rapides. Le filtre de période (en-tête) pilote toute la page.
  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return QcPage(
      onRefresh: () => _loadAll(refresh: true),
      children: [
        QcPageHeader(
          title: 'Contrôle Qualité',
          subtitle: 'Suivez les contrôles qualité PROMESH et PROBAR et accédez rapidement aux machines.',
          actions: [
            QcPeriodSelector(value: _period, onChanged: _setPeriod),
            OutlinedButton.icon(
              onPressed: () => context.go(QcPaths.history),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Historique'),
            ),
          ],
        ),
        if (_configError != null) QcErrorBanner('Configuration indisponible : $_configError', onRetry: () => _loadConfig(refresh: true)),
        if (_statsError != null) QcErrorBanner('Statistiques indisponibles : $_statsError', onRetry: _loadStats),
        _linesDashboard(),
        const SizedBox(height: 20),
        _recentSection(),
        _GeneralStats(stats: _stats, unavailable: _statsUnavailable, periodLabel: _periodLabel),
        _QuickActions(config: _config, stats: _stats, canCreate: _canCreate),
      ],
    );
  }

  // ── 1. PROMESH + PROBAR ────────────────────────────────────────────────

  Widget _linesDashboard() {
    final config = _config;
    return LayoutBuilder(builder: (context, c) {
      final sideBySide = c.maxWidth >= 1000;
      List<Widget> blocks;
      if (config == null) {
        blocks = const [QcSkeleton(height: 420, radius: kQcRadius), QcSkeleton(height: 420, radius: kQcRadius)];
      } else {
        blocks = [
          for (final line in config.productionLines)
            _LineBlock(
              line: line,
              stats: _stats?.line(line.type),
              statsUnavailable: _statsUnavailable,
              periodLabel: _periodLabel,
              canCreate: _canCreate,
              compact: sideBySide,
            ),
        ];
      }
      if (!sideBySide || blocks.length != 2) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < blocks.length; i++) ...[if (i > 0) const SizedBox(height: 16), blocks[i]],
        ]);
      }
      // Pas d'IntrinsicHeight (incompatible avec les LayoutBuilder des
      // grilles) : les deux blocs ont la même structure, donc la même hauteur.
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: blocks[0]),
        const SizedBox(width: 16),
        Expanded(child: blocks[1]),
      ]);
    });
  }

  // ── 2. Derniers contrôles qualité ──────────────────────────────────────────────

  Widget _recentSection() => QcSection(
        icon: Icons.history_rounded,
        title: 'Derniers contrôles qualité',
        subtitle: _canCreate ? 'Vos contrôles qualité les plus récents, toutes lignes' : 'Contrôles qualité les plus récents, toutes lignes',
        trailing: TextButton.icon(
          onPressed: () => context.go(QcPaths.history),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Tout l\'historique'),
        ),
        children: [
          if (_recentError != null)
            QcErrorBanner(_recentError!, onRetry: _loadRecent)
          else
            QcControlsTable(controls: _recent ?? const [], loading: _recent == null),
        ],
      );
}

// ═══ Bloc ligne (identité couleur + statistiques + machines) ════════════

class _LineBlock extends StatelessWidget {
  final QualityProductionLine line;
  final QualityLineStats? stats;
  final bool statsUnavailable;
  final String periodLabel;
  final bool canCreate;
  final bool compact; // côte à côte : machines en 2 × 2

  const _LineBlock({
    required this.line,
    required this.stats,
    required this.statsUnavailable,
    required this.periodLabel,
    required this.canCreate,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(line.type);
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    String? v(int Function(QualityCounts c) pick) => stats != null ? qcFormatInt(pick(stats!.counts)) : (statsUnavailable ? '—' : null);
    final rate = stats?.counts.conformityRate;

    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(kCrmSurface, color, 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Identité de la ligne + statistiques principales (dans le bandeau)
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, dark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: CustomPaint(
            painter: QcLineTexturePainter(line.type),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(11)),
                    child: Icon(productionTypeIcon(line.type), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(line.label, style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6)),
                      Text('Contrôle qualité ${line.label}', style: tInter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                  if (rate != null) _RateRing(rate: rate),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _bannerFigure('Machines', qcFormatInt(line.machines.length)),
                  _bannerFigure('Contrôles qualité', v((c) => c.total)),
                  _bannerFigure('Conformes', v((c) => c.conforme)),
                  _bannerFigure('Non conformes', v((c) => c.nonConforme)),
                ]),
              ]),
            ),
          ),
        ),
        // ── Machines intégrées au bloc
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(children: [
            Icon(kMachineIcon, size: 16, color: color),
            const SizedBox(width: 6),
            Text('MACHINES ${line.label}', style: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: dark, letterSpacing: 0.6)),
            const Spacer(),
            if (periodLabel.isNotEmpty) Text(periodLabel, style: tInter(fontSize: 11, color: kCrmTextSub)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: line.machines.isEmpty
              ? const QcEmptyState('Aucune machine configurée', icon: kMachineIcon)
              : qcGrid(columns: compact ? qcColumnsFor(230, max: 2) : qcColumnsFor(200, max: 4), gap: 8, [
                  for (final m in line.machines)
                    _BlockMachine(
                      type: line.type,
                      machine: m,
                      stats: stats?.machine(m),
                      unavailable: statsUnavailable,
                    ),
                ]),
        ),
        // ── Accès à la ligne
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: color.withValues(alpha: 0.18)))),
          child: Row(children: [
            if (stats != null && stats!.counts.aVerifier > 0) ...[
              const Icon(Icons.schedule_rounded, size: 15, color: kQcAVerifierText),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${stats!.counts.aVerifier} à vérifier',
                    overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kQcAVerifierText)),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => context.go(QcPaths.line(line.type)),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text('Voir la ligne', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ),
            if (canCreate) ...[
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => showQcNewControlDialog(context, line, stats: stats),
                style: FilledButton.styleFrom(backgroundColor: color, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Nouveau contrôle qualité'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _bannerFigure(String label, String? value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (value == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: SizedBox(width: 36, height: 18))
            else
              Text(value, maxLines: 1, style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tInter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.82))),
          ]),
        ),
      );
}

/// Taux de conformité de la ligne (contrôles qualité validés) dans le bandeau.
class _RateRing extends StatelessWidget {
  final double rate;
  const _RateRing({required this.rate});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: qcT('Taux de conformité (contrôles qualité validés)'),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: rate,
                strokeWidth: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                color: Colors.white,
              ),
            ),
            Text('${(rate * 100).round()}%', style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      );
}

/// Machine dans son bloc : compteur de la période, dernier contrôle,
/// dernier résultat, ouvrir.
class _BlockMachine extends StatelessWidget {
  final String type;
  final String machine;
  final QualityMachineStats? stats;
  final bool unavailable;

  const _BlockMachine({required this.type, required this.machine, required this.stats, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(type);
    final last = stats?.lastControl;
    final loading = stats == null && !unavailable;
    void open() => context.go(QcPaths.machine(type, machine));
    // Bordure non uniforme (liseré couleur à gauche) : arrondi par découpe,
    // jamais `borderRadius` sur une bordure non uniforme (interdit).
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: kCrmSurface,
        child: InkWell(
          onTap: open,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 3),
                top: const BorderSide(color: kCrmBorder),
                right: const BorderSide(color: kCrmBorder),
                bottom: const BorderSide(color: kCrmBorder),
              ),
            ),
            child: Row(children: [
              Icon(kMachineIcon, size: 20, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text('Machine $machine',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                    ),
                    const SizedBox(width: 6),
                    if (loading)
                      const QcSkeleton(width: 26, height: 12)
                    else
                      Text(unavailable ? '—' : '${stats!.counts.total} ctrl',
                          style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
                  ]),
                  const SizedBox(height: 3),
                  if (loading)
                    const QcSkeleton(width: 90, height: 12)
                  else if (last == null)
                    Text(unavailable ? '—' : 'Aucun contrôle qualité', style: tInter(fontSize: 11, color: kCrmTextSub))
                  else
                    Row(children: [
                      QcStatusBadge(last.isValidated ? last.status : 'BROUILLON', dense: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(last.controlDate.length >= 5 ? last.controlDate.substring(0, 5) : last.controlDate,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, color: kCrmTextSub)),
                      ),
                    ]),
                ]),
              ),
              IconButton(
                tooltip: qcT('Ouvrir Machine $machine'),
                visualDensity: VisualDensity.compact,
                onPressed: open,
                icon: Icon(Icons.arrow_forward_rounded, size: 18, color: color),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══ Statistiques générales ═════════════════════════════════════════════

class _GeneralStats extends StatelessWidget {
  final QualityStats? stats;
  final bool unavailable;
  final String periodLabel;
  const _GeneralStats({required this.stats, required this.unavailable, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final s = stats;
    String? v(int Function(QualityStats s) pick) => s != null ? qcFormatInt(pick(s)) : (unavailable ? '—' : null);
    final rate = s?.totals.conformityRate;
    return QcSection(
      icon: Icons.insights_rounded,
      title: 'Statistiques générales',
      subtitle: periodLabel,
      children: [
        qcGrid(columns: qcColumnsFor(190, max: 6), [
          QcKpiTile(icon: Icons.fact_check_outlined, label: 'Total contrôles qualité', value: v((s) => s.totals.total)),
          // Compté à part : une fiche à 3 prélèvements reste UN contrôle.
          QcKpiTile(icon: Icons.format_list_numbered_rounded, label: 'Prélèvements', value: v((s) => s.totals.releves), caption: 'dans ces contrôles qualité', color: kCrmTextSub),
          QcKpiTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Conformes',
            value: v((s) => s.totals.conforme),
            caption: rate == null ? null : '${(rate * 100).toStringAsFixed(1)} % des validés',
            color: kCrmSuccess,
          ),
          QcKpiTile(icon: Icons.cancel_outlined, label: 'Non conformes', value: v((s) => s.totals.nonConforme), color: kCrmDanger),
          QcKpiTile(icon: Icons.schedule_rounded, label: 'À vérifier', value: v((s) => s.totals.aVerifier), color: kCrmWarning),
          QcKpiTile(
            icon: kMachineIcon,
            label: 'Machines actives',
            value: s != null ? '${s.machinesActives} / ${s.machines}' : (unavailable ? '—' : null),
            caption: 'au moins un contrôle qualité',
            color: kCrmTextSub,
          ),
        ]),
        if (s != null && s.lines.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('RÉPARTITION PAR LIGNE', style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          for (final l in s.lines) _LineSplitBar(line: l),
        ],
      ],
    );
  }
}

/// Barre de répartition conforme / non conforme / à vérifier d'une ligne.
class _LineSplitBar extends StatelessWidget {
  final QualityLineStats line;
  const _LineSplitBar({required this.line});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final c = line.counts;
    final color = productionTypeColor(line.type);
    Widget seg(int n, Color col) => n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(color: col));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 92, child: QcLineChip(line.type, dense: true)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: c.total == 0
                  ? Container(color: kCrmBorder)
                  : Row(children: [seg(c.conforme, kCrmSuccess), seg(c.nonConforme, kCrmDanger), seg(c.aVerifier, kCrmWarning)]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 170,
          child: Text(
            c.total == 0 ? 'Aucun contrôle qualité' : '${c.conforme} C · ${c.nonConforme} NC · ${c.aVerifier} à vérifier',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.total == 0 ? kCrmTextSub : color),
          ),
        ),
      ]),
    );
  }
}

// ═══ Actions rapides ════════════════════════════════════════════════════

class _QuickActions extends StatelessWidget {
  final QualityConfig? config;
  final QualityStats? stats;
  final bool canCreate;
  const _QuickActions({required this.config, required this.stats, required this.canCreate});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final lines = config?.productionLines ?? const <QualityProductionLine>[];
    Widget action(
        {required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
        bool filled = false}) {
      return Material(
        color: filled ? color : kCrmSurface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: filled ? color : kCrmBorder),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: filled ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 20, color: filled ? Colors.white : color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: filled ? Colors.white : kCrmText)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tInter(fontSize: 11.5, color: filled ? Colors.white.withValues(alpha: 0.85) : kCrmTextSub)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: filled ? Colors.white : kCrmTextSub),
            ]),
          ),
        ),
      );
    }

    return QcSection(
      icon: Icons.bolt_rounded,
      title: 'Actions rapides',
      children: [
        if (config == null)
          const QcSkeletonRows(rows: 1, height: 60)
        else ...[
          if (!canCreate) const QcReadOnlyNote(text: 'Consultation seule — la saisie est réservée au rôle Contrôle Qualité.'),
          qcGrid(columns: qcColumnsFor(260, max: 3), [
            for (final line in lines)
              action(
                icon: canCreate ? Icons.add_rounded : productionTypeIcon(line.type),
                title: canCreate ? 'Nouveau contrôle qualité ${line.label}' : 'Voir ${line.label}',
                subtitle: canCreate ? 'Choisir la machine — nouvelle fiche qualité' : '${line.machines.length} machines',
                color: productionTypeColor(line.type),
                filled: true,
                onTap: canCreate
                    ? () => showQcNewControlDialog(context, line, stats: stats?.line(line.type))
                    : () => context.go(QcPaths.line(line.type)),
              ),
            action(
              icon: Icons.history_rounded,
              title: 'Historique complet',
              subtitle: 'Rechercher et filtrer les contrôles qualité',
              color: kCrmText,
              onTap: () => context.go(QcPaths.history),
            ),
          ]),
        ],
      ],
    );
  }
}
