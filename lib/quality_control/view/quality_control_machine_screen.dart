// lib/quality_control/view/quality_control_machine_screen.dart
//
// Contrôle Qualité — page d'une MACHINE (/quality-control/promesh/machine/1).
//
// La fiche de contrôle qualité appartient à la MACHINE : « Nouveau contrôle qualité »
// ouvre directement le formulaire d'une nouvelle fiche pour CETTE machine
// (/quality-control/controle?type=promesh&machine=1) — aucune production à
// sélectionner : le contrôle qualité est indépendant de la production.
//
// Liste et statistiques : uniquement les fiches qualité de (ligne, machine)
// créées par les comptes controle_qualite — filtrage SQL côté backend
// (GET /quality-control?productionType=&machine=, GET /quality-control/stats).
// Fiche BROUILLON → « Modifier » ; fiche VALIDÉE → « Consulter » (lecture seule).

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

class QualityControlMachineScreen extends StatefulWidget {
  final String type; // PROMESH | PROBAR
  final String machine;
  const QualityControlMachineScreen({super.key, required this.type, required this.machine});

  @override
  State<QualityControlMachineScreen> createState() => _QualityControlMachineScreenState();
}

class _QualityControlMachineScreenState extends State<QualityControlMachineScreen> with QcSyncMixin {
  static const _pageSize = 20;

  final _svc = QualityControlService.instance;
  late final String _type = widget.type.toUpperCase();
  final bool _canCreate = AuthService().isControleQualite;

  int _page = 1;
  QualityControlPage? _controls; // fiches qualité de la machine (période)
  String? _controlsError;
  QualityStats? _stats;
  bool _statsFailed = false;

  String get _periodLabel => kQualityStatsPeriods.firstWhere((p) => p.$1 == qcPeriod, orElse: () => ('', '')).$2;

  @override
  void initState() {
    super.initState();
    _stats = _svc.cachedStats(qcPeriod);
    _loadAll();
  }

  Future<void> _loadAll() => Future.wait([_loadControls(), _loadStats()]);

  // Écriture ailleurs dans le module ou période modifiée : relecture API.
  @override
  Future<void> qcReload() {
    setState(() => _stats = _svc.cachedStats(qcPeriod));
    _page = 1;
    return _loadAll();
  }

  Future<void> _loadControls() async {
    final period = qcPeriod;
    try {
      final p = await _svc.fetchHistoryPage(productionType: _type, machine: widget.machine, page: _page, limit: _pageSize, period: period);
      if (mounted && period == qcPeriod) {
        setState(() {
          _controls = p;
          _controlsError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _controlsError = e.toString());
    }
  }

  Future<void> _loadStats() async {
    final period = qcPeriod;
    try {
      final s = await _svc.fetchStats(period: period);
      if (mounted && period == qcPeriod) {
        setState(() {
          _stats = s;
          _statsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  void _goToPage(int page) {
    _page = page;
    _loadControls();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(_type);
    final ms = _stats?.line(_type)?.machine(widget.machine);
    final last = ms?.lastControl;
    final statsLoading = _stats == null && !_statsFailed;
    String? v(int Function(QualityCounts c) pick) => statsLoading ? null : (ms == null ? '—' : qcFormatInt(pick(ms.counts)));

    return QcPage(
      onRefresh: _loadAll,
      children: [
        QcPageHeader(
          crumbs: [('Contrôle Qualité', QcPaths.root), (_type, QcPaths.line(_type)), ('Machine ${widget.machine}', null)],
          title: '$_type / Machine ${widget.machine}',
          subtitle: _canCreate
              ? 'Fiches de contrôle qualité de cette machine — créez une nouvelle fiche ou ouvrez une fiche existante.'
              : 'Fiches de contrôle qualité de cette machine.',
          icon: kMachineIcon,
          color: color,
          onBack: () => context.go(QcPaths.line(_type)),
          actions: [
            QcPeriodSelector(value: qcPeriod, onChanged: qcSetPeriod),
            if (_canCreate)
              FilledButton.icon(
                onPressed: () => context.go(QcPaths.newControl(_type, widget.machine)),
                style: FilledButton.styleFrom(backgroundColor: color),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau contrôle qualité'),
              ),
          ],
        ),
        if (!_canCreate) const QcReadOnlyNote(),
        qcGrid(columns: qcColumnsFor(190, max: 6), [
          QcKpiTile(icon: Icons.fact_check_outlined, label: 'Fiches qualité', value: v((c) => c.total), caption: _periodLabel, color: color),
          QcKpiTile(icon: Icons.format_list_numbered_rounded, label: 'Prélèvements', value: v((c) => c.releves), caption: 'dans ces contrôles qualité', color: kCrmTextSub),
          QcKpiTile(icon: Icons.check_circle_outline_rounded, label: 'Conformes', value: v((c) => c.conforme), color: kCrmSuccess),
          QcKpiTile(icon: Icons.cancel_outlined, label: 'Non conformes', value: v((c) => c.nonConforme), color: kCrmDanger),
          QcKpiTile(icon: Icons.schedule_rounded, label: 'À vérifier', value: v((c) => c.aVerifier), caption: 'brouillons', color: kCrmWarning),
          QcKpiTile(
            icon: Icons.calendar_today_outlined,
            label: 'Dernière fiche',
            value: statsLoading ? null : (last == null ? 'Aucune' : qcDateTime(last.controlDate, last.controlTime)),
            caption: last?.reference,
            color: kCrmTextSub,
          ),
          QcKpiTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Dernier résultat',
            value: statsLoading ? null : '—',
            valueWidget: last == null
                ? null
                : Padding(padding: const EdgeInsets.only(top: 2), child: QcStatusBadge(last.isValidated ? last.status : 'BROUILLON')),
            color: last == null ? kCrmTextSub : qualityStatusColor(last.isValidated ? last.status : 'BROUILLON'),
          ),
        ]),
        const SizedBox(height: 16),
        _controlsSection(color),
      ],
    );
  }

  // ── Fiches qualité de la machine ───────────────────────────────────────

  static const _cols = [('Référence', 14), ('Date / Heure', 14), ('Poste · prélèvements', 16), ('Contrôleur qualité', 12), ('Statut', 10), ('Résultat', 12), ('', 12)];

  Widget _cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: Alignment.centerLeft, child: child)),
      );

  Widget _controlsSection(Color color) {
    final page = _controls;
    return QcSection(
      icon: kQualityControlIcon,
      title: 'Contrôles qualité de cette machine',
      subtitle: page == null ? null : '${qcFormatInt(page.total)} fiche(s) qualité · $_periodLabel',
      color: color,
      trailing: TextButton(
        onPressed: () => context.go(QcPaths.historySearch('machine ${widget.machine}')),
        child: const Text('Historique'),
      ),
      children: [
        if (_controlsError != null)
          QcErrorBanner(_controlsError!, onRetry: _loadControls)
        else if (page == null)
          const QcSkeletonRows(rows: 5, height: 40)
        else if (page.items.isEmpty)
          QcEmptyState(
            _canCreate
                ? 'Aucune fiche qualité pour cette machine · $_periodLabel — « Nouveau contrôle qualité » pour en créer une'
                : 'Aucune fiche qualité pour cette machine · $_periodLabel',
            icon: Icons.fact_check_outlined,
          )
        else ...[
          // Petit écran : la table défile horizontalement (colonnes lisibles).
          LayoutBuilder(builder: (context, c) {
            const minWidth = 820.0;
            final rows = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(),
              for (final control in page.items) _row(control, color),
            ]);
            if (c.maxWidth >= minWidth) return rows;
            return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: rows));
          }),
          if (page.totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Page ${page.page} / ${page.totalPages}', style: tInter(fontSize: 12, color: kCrmTextSub)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _page < page.totalPages ? () => _goToPage(_page + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          for (final (label, flex) in _cols)
            _cell(
              flex,
              Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5)),
            ),
        ]),
      );

  Widget _row(QualityControlModel c, Color color) {
    final text = tInter(fontSize: 12.5, color: kCrmText);
    void open() => context.go(QcPaths.control(c.id));
    return InkWell(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          _cell(_cols[0].$2, Text(c.reference.isEmpty ? '—' : c.reference, style: text.copyWith(fontWeight: FontWeight.w700))),
          _cell(_cols[1].$2, Text(qcDateTime(c.controlDate, c.controlTime), style: text)),
          _cell(
            _cols[2].$2,
            Text(
              '${qualityPosteLabel(c.poste) ?? '—'} · ${c.readingsCount} prélèvement${c.readingsCount > 1 ? 's' : ''}${c.lastReadingTime == null ? '' : ' (${c.lastReadingTime})'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text,
            ),
          ),
          _cell(_cols[3].$2, Tooltip(message: c.controllerEmail, child: Text(qcControllerLabel(c.controllerEmail), overflow: TextOverflow.ellipsis, style: text))),
          _cell(_cols[4].$2, QcStatusBadge(c.isValidated ? 'VALIDE' : 'BROUILLON', dense: true)),
          _cell(_cols[5].$2, c.isValidated ? QcStatusBadge(c.status, dense: true) : Text('À vérifier', style: tInter(fontSize: 12, color: kQcAVerifierText))),
          _cell(
            _cols[6].$2,
            SizedBox(
              height: 32,
              // BROUILLON : modifiable ; VALIDÉ : lecture seule.
              child: FilledButton.tonalIcon(
                onPressed: open,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                icon: Icon(c.isValidated || !_canCreate ? Icons.lock_outline_rounded : Icons.edit_note_rounded, size: 16),
                label: Text(c.isValidated || !_canCreate ? 'Consulter' : 'Modifier', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
