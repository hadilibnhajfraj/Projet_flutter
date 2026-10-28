// lib/production_dashboard/view/production_dashboard_screen.dart
//
// TABLEAU DE BORD INDUSTRIEL (/production/dashboard, et accueil des comptes
// de production : /por-promesh/dashboard) — repérer en quelques secondes ce
// qui demande une action, sans parcourir plusieurs écrans :
//   1. alertes et problèmes détectés (prioritaires, en tête) ;
//   2. KPI : total des fiches, PROMESH, PROBAR, demandes de matières premières ;
//   3. production par type (anneau) et statuts de validation des fiches ;
//   4. production par jour (quantités, une échelle par unité) ;
//   5. état des machines, dernières fiches, dernières demandes de matières ;
//   6. quantités et déchets, évolution des déchets, accès rapides.
//
// Données : GET /production-records/dashboard (UN appel, agrégations SQL,
// périmètre appliqué par le backend) + les API existantes des demandes de
// matières premières et du contrôle de conformité (sources secondaires,
// chacune signalée « indisponible » en cas d'erreur — jamais un zéro inventé).
// Aucune décision n'est prise ici : les actions ouvrent les écrans existants
// (validation des fiches, demandes de matières premières), qui revérifient
// les droits. Temps réel : rechargement sur les événements Socket.IO des
// fiches et des demandes (notifications existantes inchangées).
//
// Couleurs : PROMESH bleu, PROBAR orange ; statuts acceptée vert, en attente
// orange, refusée rouge. Unités différentes (m², ml, kg) : jamais additionnées.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as fm show Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart' show FicheApprovalPaths;
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_paths.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart' show qcIsoFromDate;
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

import '../model/production_dashboard_model.dart';
import '../production_dashboard_routes.dart';
import '../service/industrial_dashboard_sources.dart';
import '../service/production_dashboard_service.dart';

const Color kProductionColor = Color(0xFF0F766E); // accent du module (ni PROMESH ni PROBAR)
const Color _kValidee = Color(0xFF047857);
const Color _kBrouillon = Color(0xFFB45309);
const Color _kArchivee = Color(0xFF64748B);
const Color _kAccepted = Color(0xFF16A34A);
const Color _kPending = Color(0xFFEA580C);
const Color _kRejected = Color(0xFFDC2626);
const Color _kNeutral = Color(0xFF64748B);

Color _lineColor(String type) => type == 'probar' ? kProbarColor : kPromeshColor;
IconData _lineIcon(String type) => type == 'probar' ? Icons.view_week_outlined : Icons.grid_on_rounded;
Color _statusColor(String? statut) => switch (statut) {
      'validee' => _kValidee,
      'archivee' => _kArchivee,
      _ => _kBrouillon,
    };
String _shortDate(String iso) => iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;
String _two(int v) => v.toString().padLeft(2, '0');
String _dateTime(DateTime? d) => d == null ? '—' : '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
String _pct(int part, int total) => total <= 0 ? '—' : '${prodFormatNumber(part * 100 / total, maxDecimals: 1)} %';

/// Badge de statut d'une fiche : Brouillon / Validée / Archivée.
class ProductionStatusBadge extends StatelessWidget {
  final String? statut;
  const ProductionStatusBadge(this.statut, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(statut);
    final icon = switch (statut) {
      'validee' => Icons.check_circle_outline_rounded,
      'archivee' => Icons.inventory_2_outlined,
      _ => Icons.edit_note_rounded,
    };
    return _Pill(label: prodStatusLabel(statut), color: color, icon: icon);
  }
}

/// Décision de validation : Acceptée / En attente / Refusée / Hors circuit.
class ProductionApprovalBadge extends StatelessWidget {
  final ProductionApproval? approval;
  const ProductionApprovalBadge(this.approval, {super.key});

  @override
  Widget build(BuildContext context) => switch (approval?.status) {
        'APPROVED' => const _Pill(label: 'Acceptée', color: _kAccepted, icon: Icons.verified_outlined),
        'PENDING' => const _Pill(label: 'En attente', color: _kPending, icon: Icons.hourglass_top_rounded),
        'REJECTED' => const _Pill(label: 'Refusée', color: _kRejected, icon: Icons.block_rounded),
        _ => const _Pill(label: 'Hors circuit', color: _kNeutral, icon: Icons.remove_circle_outline_rounded),
      };
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Pill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}

enum _Severity { critical, warning, info }

class _Alert {
  final _Severity severity;
  final IconData icon;
  final String title;
  final int? count;
  final String description;
  final String? actionLabel;
  final VoidCallback? onTap;
  final String key;
  const _Alert(this.key, {required this.severity, required this.icon, required this.title, this.count, required this.description, this.actionLabel, this.onTap});
}

class ProductionDashboardScreen extends StatefulWidget {
  /// Sources secondaires (demandes de matières premières, conformité) —
  /// remplaçables dans les tests.
  final IndustrialDashboardSources? sources;
  final IndustrialDashboardAccess? access;
  /// Sections propres à une page d'accueil (ex. autres modules), affichées
  /// avant les accès rapides.
  final List<Widget> extraSections;
  /// Rafraîchissement temps réel (Socket.IO) — désactivable dans les tests.
  final bool realtime;

  const ProductionDashboardScreen({super.key, this.sources, this.access, this.extraSections = const [], this.realtime = true});

  @override
  State<ProductionDashboardScreen> createState() => _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  final _svc = ProductionDashboardService.instance;
  late final IndustrialDashboardSources _sources = widget.sources ?? ApiIndustrialDashboardSources();
  late final IndustrialDashboardAccess _access = widget.access ?? IndustrialDashboardAccess.fromAuth();

  String _period = 'year';
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  String? _error;
  ProductionDashboard? _data;
  DashboardSource<RawMaterialOverview>? _raw;
  DashboardSource<int?>? _missing;
  DashboardSource<int>? _requests;
  int _seq = 0;
  Timer? _debounce;

  static const _events = ['production-fiche-approval:updated', 'raw-material-request:updated'];

  @override
  void initState() {
    super.initState();
    if (widget.realtime) {
      for (final e in _events) {
        SocketService.instance.on(e, _onRealtime);
      }
    }
    _load();
  }

  @override
  void dispose() {
    if (widget.realtime) {
      for (final e in _events) {
        SocketService.instance.off(e, _onRealtime);
      }
    }
    _debounce?.cancel();
    super.dispose();
  }

  // Fiche décidée / soumise, demande créée ou traitée : données relues
  // (regroupées si plusieurs événements arrivent ensemble).
  void _onRealtime(dynamic _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    // Période personnalisée : rien n'est demandé tant que les deux dates
    // ne sont pas choisies et cohérentes.
    if (_period == 'custom') {
      if (_start == null || _end == null) return;
      if (_start!.isAfter(_end!)) {
        setState(() => _error = 'La date de début doit précéder la date de fin.');
        return;
      }
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Sources secondaires en parallèle (indépendantes de la période).
    final raw = _sources.rawMaterials(_access);
    final missing = _sources.missingProductionSheets();
    final requests = _sources.pendingProductionRequests(_access);
    try {
      final d = await _svc.fetch(
        period: _period,
        startDate: _start == null ? null : qcIsoFromDate(_start!),
        endDate: _end == null ? null : qcIsoFromDate(_end!),
      );
      if (mounted && seq == _seq) setState(() => _data = d);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    final results = await Future.wait<Object>([raw, missing, requests]);
    if (!mounted || seq != _seq) return; // réponse d'un chargement périmé
    setState(() {
      _raw = results[0] as DashboardSource<RawMaterialOverview>;
      _missing = results[1] as DashboardSource<int?>;
      _requests = results[2] as DashboardSource<int>;
      _loading = false;
    });
  }

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: qcT(start ? 'Date début' : 'Date fin'),
      cancelText: qcT('Annuler'),
      confirmText: qcT('Valider'),
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context);
    final d = _data;
    return QcPage(
      onRefresh: _load,
      children: [
        QcPageHeader(
          title: 'Tableau de bord industriel',
          subtitle: 'Vue globale de la production PROMESH/PROBAR et suivi des activités',
          icon: Icons.factory_outlined,
          color: kProductionColor,
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('prod-refresh'),
              onPressed: _loading ? null : _load,
              style: OutlinedButton.styleFrom(foregroundColor: kCrmText, side: const BorderSide(color: kCrmBorder), minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        _periodBar(d),
        if (_error != null) QcErrorBanner(_error!, onRetry: _load),
        if (_loading && d == null) const QcSkeletonRows(rows: 6, height: 52),
        if (d != null) ...[
          _alertsSection(d),
          _kpiRow(d),
          _pair(_typeSection(d), _approvalSection(d)),
          _dailySection(d),
          _machinesSection(d),
          _recentSection(d),
          if (_raw != null && !_raw!.forbidden) _rawSection(),
          _pair(_quantitiesSection(d), _wasteChart(d)),
          ...widget.extraSections,
          _quickLinks(),
        ],
      ],
    );
  }

  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 1000) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
      });

  // ── Période ────────────────────────────────────────────────────────────

  Widget _periodBar(ProductionDashboard? d) {
    Widget dateField(String label, DateTime? value, bool start) => InkWell(
          key: ValueKey('prod-date-${start ? 'start' : 'end'}'),
          onTap: () => _pick(start: start),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: kProductionColor),
              const SizedBox(width: 8),
              Text(label, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
              const SizedBox(width: 6),
              fm.Text(value == null ? '—' : prodFormatDate(qcIsoFromDate(value)), style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
            ]),
          ),
        );
    final range = d == null || d.periodStart == null ? null : '${prodFormatDate(d.periodStart)} → ${prodFormatDate(d.periodEnd)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: qcCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Icon(Icons.date_range_rounded, size: 18, color: kProductionColor),
          Text('Période', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
            child: Wrap(children: [
              for (final (key, label) in kProductionPeriods)
                InkWell(
                  key: ValueKey('prod-period-$key'),
                  onTap: () => _setPeriod(key),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: key == _period ? kCrmSurface : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                    child: Text(label, style: tInter(fontSize: 12.5, fontWeight: key == _period ? FontWeight.w800 : FontWeight.w500, color: key == _period ? kProductionColor : kCrmTextSub)),
                  ),
                ),
            ]),
          ),
          if (_period == 'custom') ...[
            dateField('Date début', _start, true),
            dateField('Date fin', _end, false),
          ],
          if (range != null) fm.Text(range, key: const ValueKey('prod-period-range'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
          // Indépendant de la période choisie.
          if (d != null)
            Text(qcT('Aujourd\'hui : {} fiche(s)').replaceFirst('{}', '${d.productionsToday}'),
                key: const ValueKey('prod-today'), style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmTextSub)),
        ]),
        if (_period == 'custom' && (_start == null || _end == null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Choisissez une date de début et une date de fin.', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ),
        if (d != null && d.ownScope)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Périmètre : vos propres fiches de production.', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ),
      ]),
    );
  }

  // ── Navigation (écrans existants ; le backend revérifie les droits) ────

  /// Ouvre la fiche sur son écran existant (aucun nouvel écran de saisie).
  void _openFiche(String type, String? machine, String? poste, String recordId) {
    if (machine == null || machine.isEmpty || poste == null || poste.isEmpty) {
      context.go(ProdPaths.records);
    } else if (type == 'probar') {
      context.go(ProdPaths.probarFiche(machine, poste, recordId));
    } else {
      context.go(ProdPaths.promeshFiche(machine, poste, recordId));
    }
  }

  void _openValidation([String? ficheId]) => context.go(ficheId == null ? FicheApprovalPaths.root : '${FicheApprovalPaths.root}?fiche=$ficheId');

  /// Fiches refusées à corriger (toutes dates) : motif, décideur, date.
  Future<void> _showRejected(ProductionDashboard d) => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          key: const ValueKey('prod-rejected-dialog'),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                child: Row(children: [
                  const Icon(Icons.block_rounded, color: _kRejected, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Fiches refusées à corriger', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText))),
                  IconButton(tooltip: qcT('Fermer'), onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(qcT('{} fiche(s) refusée(s), toutes dates — les plus récentes').replaceFirst('{}', '${d.alerts.fichesRefusees}'),
                    style: tInter(fontSize: 12, color: kCrmTextSub)),
              ),
              const Divider(height: 18),
              Flexible(
                child: d.alerts.rejected.isEmpty
                    ? const QcEmptyState('Aucune fiche refusée', icon: Icons.verified_outlined)
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        itemCount: d.alerts.rejected.length,
                        separatorBuilder: (_, __) => const Divider(height: 18),
                        itemBuilder: (_, i) {
                          final r = d.alerts.rejected[i];
                          return Column(key: ValueKey('prod-rejected-${r.id}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              QcLineChip(r.type.toUpperCase(), dense: true),
                              const SizedBox(width: 8),
                              Expanded(child: fm.Text(r.numero ?? '—', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText))),
                              fm.Text(prodFormatDate(r.date), style: tInter(fontSize: 12, color: kCrmTextSub)),
                            ]),
                            const SizedBox(height: 6),
                            Text('Motif du refus', style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
                            fm.Text(r.approval.comment ?? '—', style: tInter(fontSize: 13, color: kQcNonConformeText)),
                            const SizedBox(height: 4),
                            fm.Text(
                              '${qcT('Refusée par')} ${r.approval.decidedByEmail ?? '—'} · ${_dateTime(r.approval.decidedAt)} · ${qcT('Producteur')} : ${prodUserLabel(r.userEmail)}',
                              style: tInter(fontSize: 11.5, color: kCrmTextSub),
                            ),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _openFiche(r.type, r.machine, r.poste, r.recordId);
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text('Ouvrir la fiche'),
                              ),
                              if (_access.canViewFicheApprovals)
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openValidation('${r.type}:${r.recordId}');
                                  },
                                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                                  label: const Text('Voir dans Validation des fiches'),
                                ),
                            ]),
                          ]);
                        },
                      ),
              ),
            ]),
          ),
        ),
      );

  // ── Alertes ────────────────────────────────────────────────────────────

  List<_Alert> _alerts(ProductionDashboard d) {
    final out = <_Alert>[];
    if (d.alerts.fichesRefusees > 0) {
      out.add(_Alert('rejected',
          severity: _Severity.critical,
          icon: Icons.block_rounded,
          title: 'Fiches refusées à corriger',
          count: d.alerts.fichesRefusees,
          description: 'Refusées par le responsable : le motif est consultable, la fiche doit être corrigée puis soumise de nouveau.',
          actionLabel: 'Voir les motifs',
          onTap: () => _showRejected(d)));
    }
    final missing = _missing?.data;
    if (missing != null && missing > 0) {
      out.add(_Alert('missing',
          severity: _Severity.critical,
          icon: Icons.event_busy_rounded,
          title: 'Fiches de production manquantes',
          count: missing,
          description: 'Jours de production sans fiche enregistrée : une autorisation peut être nécessaire pour régulariser.',
          actionLabel: 'Saisir une fiche',
          onTap: () => context.go(ProdPaths.promesh)));
    }
    final raw = _raw?.data;
    if (raw != null && raw.isValidator && raw.overdue > 0) {
      out.add(_Alert('raw-overdue',
          severity: _Severity.critical,
          icon: Icons.alarm_rounded,
          title: 'Demandes de matières premières en retard',
          count: raw.overdue,
          description: 'Échéance de validation dépassée.',
          actionLabel: 'Traiter',
          onTap: () => context.go(RawMaterialPaths.toValidate)));
    }
    if (raw != null && raw.pending > 0) {
      out.add(_Alert('raw-pending',
          severity: _Severity.warning,
          icon: Icons.inventory_2_outlined,
          title: 'Demandes de matières premières en attente',
          count: raw.pending,
          description: raw.isValidator ? 'À accepter ou refuser.' : 'Vos demandes en attente de validation par le responsable.',
          actionLabel: raw.isValidator ? 'Traiter' : 'Voir',
          onTap: () => context.go(raw.isValidator ? RawMaterialPaths.toValidate : RawMaterialPaths.tracking)));
    }
    if (d.alerts.fichesEnAttente > 0) {
      out.add(_Alert('pending',
          severity: _Severity.warning,
          icon: Icons.hourglass_top_rounded,
          title: 'Fiches en attente de validation',
          count: d.alerts.fichesEnAttente,
          description: _access.isFicheApprovalValidator ? 'À accepter ou refuser.' : 'En attente de la décision du responsable.',
          actionLabel: _access.canViewFicheApprovals ? (_access.isFicheApprovalValidator ? 'Traiter' : 'Voir') : null,
          onTap: _access.canViewFicheApprovals ? () => _openValidation() : null));
    }
    final requests = _requests?.data;
    if (requests != null && requests > 0) {
      out.add(_Alert('requests',
          severity: _Severity.warning,
          icon: Icons.fact_check_outlined,
          title: 'Demandes d\'autorisation Production en attente',
          count: requests,
          description: 'Demandes de régularisation des producteurs à traiter.',
          actionLabel: 'Traiter',
          onTap: () => context.go(ProdPaths.productionRequests)));
    }
    // Sources indisponibles : signalées, jamais remplacées par zéro.
    for (final (key, label, source) in [
      ('raw', 'Demandes de matières premières', _raw),
      ('missing', 'Fiches manquantes', _missing),
      ('requests', 'Demandes d\'autorisation Production', _requests),
    ]) {
      if (source?.error != null) {
        out.add(_Alert('error-$key', severity: _Severity.info, icon: Icons.cloud_off_rounded, title: qcT('Données indisponibles : {}').replaceFirst('{}', qcT(label)), description: source!.error!));
      }
    }
    return out..sort((a, b) => a.severity.index.compareTo(b.severity.index));
  }

  Widget _alertsSection(ProductionDashboard d) {
    final alerts = _alerts(d);
    final actionable = alerts.where((a) => a.severity != _Severity.info).length;
    return QcSection(
      key: const ValueKey('prod-alerts'),
      icon: Icons.notification_important_outlined,
      title: 'Alertes et problèmes détectés',
      subtitle: 'Éléments à traiter, toutes dates, triés par priorité',
      color: actionable > 0 ? _kRejected : _kAccepted,
      children: [
        if (_raw == null)
          const QcSkeletonRows(rows: 2, height: 40)
        else if (alerts.isEmpty)
          Row(key: const ValueKey('prod-alerts-none'), children: [
            const Icon(Icons.check_circle_outline_rounded, color: _kAccepted, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Aucun problème détecté : aucune fiche refusée ou en attente, aucune demande en attente.', style: tInter(fontSize: 13, color: kCrmText))),
          ])
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1000 ? 2 : 1;
            final w = (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final a in alerts) SizedBox(width: w, child: _alertTile(a))]);
          }),
      ],
    );
  }

  Widget _alertTile(_Alert a) {
    final color = switch (a.severity) {
      _Severity.critical => _kRejected,
      _Severity.warning => _kPending,
      _Severity.info => _kNeutral,
    };
    return Material(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey('prod-alert-${a.key}'),
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: color, width: 4))),
          child: Row(children: [
            Icon(a.icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(a.title, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                const SizedBox(height: 2),
                Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
              ]),
            ),
            if (a.count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: fm.Text('${a.count}', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
            if (a.actionLabel != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: a.onTap,
                style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                child: Text(a.actionLabel!),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── KPI ────────────────────────────────────────────────────────────────

  String _evolution(ProductionDashboard d) {
    final p = d.previous;
    if (p == null) return qcT('Toutes périodes');
    if (p.actives == 0) return qcT('Aucune fiche sur la période précédente');
    final diff = d.approval.actives - p.actives;
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
    final rate = prodFormatNumber(diff.abs() * 100 / p.actives, maxDecimals: 1);
    return qcT('{} % vs période précédente ({})').replaceFirst('{}', '$sign$rate').replaceFirst('{}', '${p.actives}');
  }

  Widget _kpiRow(ProductionDashboard d) {
    final total = d.approval.actives;
    final raw = _raw;
    final (rawValue, rawCaption, rawColor) = switch (raw) {
      null => (null, null, _kPending),
      DashboardSource(forbidden: true) => ('—', qcT('Non accessible avec votre profil'), _kNeutral),
      DashboardSource(error: final String _) => ('—', qcT('Données indisponibles'), _kNeutral),
      DashboardSource(data: final RawMaterialOverview o) => (
          '${o.pending}',
          o.isValidator
              ? (o.overdue > 0 ? qcT('{} à valider, dont {} en retard').replaceFirst('{}', '${o.pending}').replaceFirst('{}', '${o.overdue}') : qcT('En attente de validation'))
              : qcT('Vos demandes en attente de validation'),
          o.overdue > 0 ? _kRejected : (o.pending > 0 ? _kPending : _kAccepted),
        ),
      _ => ('—', null, _kNeutral),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: qcGrid(columns: (w) => w >= 1000 ? 4 : (w >= 560 ? 2 : 1), [
        QcKpiTile(
          key: const ValueKey('prod-kpi-total'),
          icon: Icons.description_outlined,
          label: 'Total des fiches',
          value: '$total',
          caption: _evolution(d),
          color: kProductionColor,
        ),
        QcKpiTile(
          key: const ValueKey('prod-kpi-promesh'),
          icon: Icons.grid_on_rounded,
          label: 'Fiches PROMESH',
          value: '${d.promesh.actives}',
          caption: qcT('{} du total').replaceFirst('{}', _pct(d.promesh.actives, total)),
          color: kPromeshColor,
        ),
        QcKpiTile(
          key: const ValueKey('prod-kpi-probar'),
          icon: Icons.view_week_outlined,
          label: 'Fiches PROBAR',
          value: '${d.probar.actives}',
          caption: qcT('{} du total').replaceFirst('{}', _pct(d.probar.actives, total)),
          color: kProbarColor,
        ),
        QcKpiTile(
          key: const ValueKey('prod-kpi-raw'),
          icon: Icons.inventory_2_outlined,
          label: 'Demandes de matières premières',
          value: rawValue,
          caption: rawCaption,
          color: rawColor,
        ),
      ]),
    );
  }

  // ── Production par type (anneau) ───────────────────────────────────────

  Widget _legendRow(String label, int value, int total, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
          fm.Text('$value', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(width: 10),
          SizedBox(width: 58, child: fm.Text(_pct(value, total), textAlign: TextAlign.right, style: tInter(fontSize: 12, color: kCrmTextSub))),
        ]),
      );

  Widget _typeSection(ProductionDashboard d) {
    final total = d.approval.actives;
    return QcSection(
      key: const ValueKey('prod-type'),
      icon: Icons.donut_large_rounded,
      title: 'Production par type',
      subtitle: 'Nombre de fiches sur la période (hors archivées)',
      color: kProductionColor,
      children: [
        if (total == 0)
          const QcEmptyState('Aucune fiche sur cette période', icon: Icons.donut_large_rounded)
        else
          LayoutBuilder(builder: (context, c) {
            final donut = SizedBox(
              width: 150,
              height: 150,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(
                  key: const ValueKey('prod-chart-type'),
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 46,
                    startDegreeOffset: -90,
                    sections: [
                      for (final (value, color) in [(d.promesh.actives, kPromeshColor), (d.probar.actives, kProbarColor)])
                        if (value > 0) PieChartSectionData(value: value.toDouble(), color: color, radius: 22, showTitle: false),
                    ],
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  fm.Text('$total', style: tInter(fontSize: 24, fontWeight: FontWeight.w900, color: kCrmText)),
                  Text('fiches', style: tInter(fontSize: 11, color: kCrmTextSub)),
                ]),
              ]),
            );
            final legend = Column(mainAxisSize: MainAxisSize.min, children: [
              _legendRow('PROMESH', d.promesh.actives, total, kPromeshColor),
              _legendRow('PROBAR', d.probar.actives, total, kProbarColor),
              if (d.archivees > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(qcT('{} fiche(s) archivée(s) non comptée(s)').replaceFirst('{}', '${d.archivees}'), style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                ),
            ]);
            if (c.maxWidth < 420) return Column(children: [donut, const SizedBox(height: 12), legend]);
            return Row(children: [donut, const SizedBox(width: 24), Expanded(child: legend)]);
          }),
      ],
    );
  }

  // ── Statuts de validation ──────────────────────────────────────────────

  Widget _approvalRow(String id, String label, int value, int total, Color color, {String? caption, VoidCallback? onTap, String? actionLabel}) => InkWell(
        key: ValueKey('prod-approval-$id'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(label, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText))),
              fm.Text('$value', style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 10),
              SizedBox(width: 58, child: fm.Text(_pct(value, total), textAlign: TextAlign.right, style: tInter(fontSize: 12, color: kCrmTextSub))),
              if (actionLabel != null) ...[
                const SizedBox(width: 6),
                Text(actionLabel, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ],
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: total > 0 ? (value / total).clamp(0, 1).toDouble() : 0, minHeight: 6, backgroundColor: kCrmBorder, color: color),
            ),
            if (caption != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(caption, style: tInter(fontSize: 11, color: kCrmTextSub))),
          ]),
        ),
      );

  Widget _approvalSection(ProductionDashboard d) {
    final a = d.approval;
    return QcSection(
      key: const ValueKey('prod-approval'),
      icon: Icons.fact_check_outlined,
      title: 'Statuts des fiches',
      subtitle: 'Validation des fiches de la période (hors archivées)',
      color: kProductionColor,
      children: [
        if (a.actives == 0)
          const QcEmptyState('Aucune fiche sur cette période', icon: Icons.fact_check_outlined)
        else ...[
          _approvalRow('accepted', 'Acceptées', a.acceptees, a.actives, _kAccepted),
          _approvalRow('pending', 'En attente', a.enAttente, a.actives, _kPending,
              onTap: _access.canViewFicheApprovals && a.enAttente > 0 ? () => _openValidation() : null),
          _approvalRow('rejected', 'Refusées', a.refusees, a.actives, _kRejected,
              onTap: d.alerts.fichesRefusees > 0 ? () => _showRejected(d) : null, actionLabel: d.alerts.fichesRefusees > 0 ? 'Motifs' : null),
          _approvalRow('outside', 'Hors circuit de validation', a.horsCircuit, a.actives, _kNeutral,
              caption: 'Fiches enregistrées avant la mise en place de la validation : ni acceptées ni refusées.'),
        ],
      ],
    );
  }

  // ── Production par jour ────────────────────────────────────────────────

  FlTitlesData _titles({required Widget Function(double) bottom, double interval = 1, bool left = true}) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: left,
            reservedSize: 46,
            getTitlesWidget: (v, meta) => v == meta.max || v == meta.min && v != 0
                ? const SizedBox.shrink()
                : fm.Text(prodFormatNumber(v, maxDecimals: 0), style: tInter(fontSize: 10, color: kCrmTextSub)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: interval,
            getTitlesWidget: (v, meta) => v != v.roundToDouble() ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 6), child: bottom(v)),
          ),
        ),
      );

  FlGridData get _grid => FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6));
  FlBorderData get _border => FlBorderData(show: true, border: const Border(bottom: BorderSide(color: kCrmBorder)));

  Widget _legend(List<(String, Color)> items) => Wrap(spacing: 14, runSpacing: 4, children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label, style: tInter(fontSize: 12, color: kCrmText)),
          ]),
      ]);

  /// Barres d'une ligne : quantité validée par jour (un axe, une unité).
  Widget _dailyBars(ProductionLineStats l, List<(String, double)> days) {
    final color = _lineColor(l.type);
    final maxY = days.fold<double>(0, (m, d) => d.$2 > m ? d.$2 : m);
    final interval = (days.length / 8).ceilToDouble().clamp(1, double.infinity).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Expanded(child: fm.Text('${l.label} (${l.unit})', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
      ]),
      const SizedBox(height: 8),
      if (days.isEmpty)
        const QcEmptyState('Aucune production validée sur cette période', icon: Icons.bar_chart_rounded)
      else
        SizedBox(
          height: 210,
          child: BarChart(
            key: ValueKey('prod-chart-daily-${l.type}'),
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.15,
              minY: 0,
              gridData: _grid,
              borderData: _border,
              titlesData: _titles(interval: interval, bottom: (v) => fm.Text(_shortDate(days[v.toInt().clamp(0, days.length - 1)].$1), style: tInter(fontSize: 10, color: kCrmTextSub))),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => kCrmText,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${prodFormatDate(days[group.x].$1)}\n${prodFormatQuantity(rod.toY, l.unit)}',
                    tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: days[i].$2, color: color, width: days.length > 20 ? 6 : 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ]),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _dailySection(ProductionDashboard d) => QcSection(
        icon: Icons.bar_chart_rounded,
        title: 'Production par jour',
        subtitle: 'Quantité des fiches validées, par date de production · une échelle par ligne (m² et ml ne sont pas comparables)',
        color: kProductionColor,
        children: [
          _pair(
            _dailyBars(d.promesh, [for (final x in d.daily) if (x.promesh > 0) (x.date, x.promesh)]),
            _dailyBars(d.probar, [for (final x in d.daily) if (x.probar > 0) (x.date, x.probar)]),
          ),
        ],
      );

  // ── État des machines ──────────────────────────────────────────────────

  Widget _machinesSection(ProductionDashboard d) {
    final rows = [for (final l in d.lines) for (final m in l.machines) (l, m)];
    Widget activity(ProductionMachineStats m) => m.active
        ? const _Pill(label: 'Activité sur la période', color: _kAccepted, icon: Icons.play_circle_outline_rounded)
        : const _Pill(label: 'Aucune fiche sur la période', color: _kNeutral, icon: Icons.pause_circle_outline_rounded);
    Widget link(ProductionLineStats l, ProductionMachineStats m) => TextButton(
          key: ValueKey('prod-machine-link-${l.type}-${m.machine}'),
          onPressed: () => context.go(ProdPaths.machine(l.type, m.machine)),
          style: TextButton.styleFrom(foregroundColor: _lineColor(l.type), padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
          child: const Text('Voir les fiches'),
        );
    return QcSection(
      key: const ValueKey('prod-machines'),
      icon: kMachineIcon,
      title: 'État des machines',
      subtitle: 'Activité de chaque machine sur la période',
      color: kProductionColor,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: kCrmBorder.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: kCrmTextSub),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Aucun état de machine (marche, arrêt, panne) n\'est enregistré dans l\'application : l\'activité est déduite des fiches de la période, sans conclure qu\'une machine est à l\'arrêt.',
                  style: tInter(fontSize: 11.5, color: kCrmTextSub)),
            ),
          ]),
        ),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(children: [
              for (final (l, m) in rows)
                Container(
                  key: ValueKey('prod-machine-${l.type}-${m.machine}'),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Icon(kMachineIcon, size: 17, color: _lineColor(l.type)),
                      Text('Machine ${m.machine}', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                      QcLineChip(l.label, dense: true),
                      activity(m),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(qcT('{} fiche(s)').replaceFirst('{}', '${m.fiches}'), style: tInter(fontSize: 12, color: kCrmTextSub)),
                      fm.Text(prodFormatQuantity(m.quantite, l.unit), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText)),
                      fm.Text('${qcT('Dernière production')} : ${prodFormatDate(m.lastDate)}', style: tInter(fontSize: 12, color: kCrmTextSub)),
                      link(l, m),
                    ]),
                  ]),
                ),
            ]);
          }
          const columns = <(String, int)>[('Machine', 3), ('Type', 2), ('Activité', 4), ('Fiches', 2), ('Quantité validée', 3), ('Dernière production', 3), ('Dernière saisie', 3), ('Actions', 3)];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _tableHeader(columns),
            for (final (l, m) in rows)
              Container(
                key: ValueKey('prod-machine-${l.type}-${m.machine}'),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
                child: Row(children: [
                  _cell(3, Row(children: [
                    Icon(kMachineIcon, size: 16, color: _lineColor(l.type)),
                    const SizedBox(width: 6),
                    Flexible(child: Text('Machine ${m.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmText))),
                  ])),
                  _cell(2, QcLineChip(l.label, dense: true)),
                  _cell(4, activity(m)),
                  _cell(2, _value('${m.fiches}', strong: true)),
                  _cell(3, _value(prodFormatQuantity(m.quantite, l.unit))),
                  _cell(3, _value(prodFormatDate(m.lastDate))),
                  _cell(3, _value(_dateTime(m.lastActivityAt))),
                  _cell(3, link(l, m)),
                ]),
              ),
          ]);
        }),
      ],
    );
  }

  // ── Tableaux ───────────────────────────────────────────────────────────

  Widget _cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: Alignment.centerLeft, child: child)));

  fm.Text _value(String text, {bool strong = false, Color color = kCrmText}) =>
      fm.Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: color));

  Widget _tableHeader(List<(String, int)> columns) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
        child: Row(children: [
          for (final (label, flex) in columns)
            _cell(flex, Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.5))),
        ]),
      );

  // ── Dernières fiches de production ─────────────────────────────────────

  List<Widget> _ficheActions(ProductionRecentRow r) => [
        TextButton(
          key: ValueKey('prod-recent-open-${r.id}'),
          onPressed: () => _openFiche(r.type, r.machine, r.poste, r.recordId),
          style: TextButton.styleFrom(foregroundColor: kProductionColor, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
          child: const Text('Voir'),
        ),
        if (r.approval?.status == 'REJECTED')
          TextButton(
            key: ValueKey('prod-recent-reason-${r.id}'),
            onPressed: () => _showReason(r),
            style: TextButton.styleFrom(foregroundColor: _kRejected, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
            child: const Text('Motif'),
          ),
        if (r.approval?.status == 'PENDING' && _access.isFicheApprovalValidator)
          TextButton(
            key: ValueKey('prod-recent-decide-${r.id}'),
            onPressed: () => _openValidation('${r.type}:${r.recordId}'),
            style: TextButton.styleFrom(foregroundColor: _kPending, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
            child: const Text('Traiter'),
          ),
      ];

  Future<void> _showReason(ProductionRecentRow r) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('prod-reason-dialog'),
          title: Text('Motif du refus', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              fm.Text(r.numero ?? '—', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 8),
              fm.Text(r.approval?.comment ?? '—', style: tInter(fontSize: 13.5, color: kQcNonConformeText)),
              const SizedBox(height: 8),
              fm.Text('${qcT('Refusée par')} ${r.approval?.decidedByEmail ?? '—'} · ${_dateTime(r.approval?.decidedAt)}', style: tInter(fontSize: 12, color: kCrmTextSub)),
            ]),
          ),
          actions: [
            if (_access.canViewFicheApprovals)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openValidation('${r.type}:${r.recordId}');
                },
                child: const Text('Voir dans Validation des fiches'),
              ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
          ],
        ),
      );

  Widget _recentSection(ProductionDashboard d) {
    const columns = <(String, int)>[('Numéro de fiche', 5), ('Type', 3), ('Machine', 3), ('Producteur', 4), ('Date de production', 3), ('Statut', 5), ('Actions', 4)];
    Widget status(ProductionRecentRow r) => Wrap(spacing: 4, runSpacing: 4, children: [
          ProductionApprovalBadge(r.approval),
          if (r.statut != 'validee') ProductionStatusBadge(r.statut),
        ]);
    return QcSection(
      key: const ValueKey('prod-recent'),
      icon: Icons.history_rounded,
      title: 'Dernières fiches de production',
      subtitle: 'Les fiches les plus récentes de la période, toutes lignes',
      color: kProductionColor,
      trailing: TextButton.icon(
        key: const ValueKey('prod-recent-all'),
        onPressed: () => context.go(ProdPaths.records),
        style: TextButton.styleFrom(foregroundColor: kProductionColor),
        icon: const Icon(Icons.list_alt_rounded, size: 16),
        label: const Text('Voir toutes'),
      ),
      children: [
        if (d.recent.isEmpty)
          const QcEmptyState('Aucune fiche sur cette période', icon: Icons.history_rounded)
        else
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 900) {
              return Column(children: [
                for (final r in d.recent)
                  Container(
                    key: ValueKey('prod-recent-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        QcLineChip(r.ligne, dense: true),
                        const SizedBox(width: 8),
                        Expanded(child: _value(r.numero ?? '—', strong: true)),
                      ]),
                      const SizedBox(height: 4),
                      fm.Text(
                        '${r.machine == null ? '—' : qcT('Machine {}').replaceFirst('{}', r.machine!)} · ${prodUserLabel(r.userEmail)} · ${prodFormatDate(r.date)}',
                        style: tInter(fontSize: 12, color: kCrmTextSub),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: status(r)), ..._ficheActions(r)]),
                    ]),
                  ),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _tableHeader(columns),
              for (final r in d.recent)
                Container(
                  key: ValueKey('prod-recent-${r.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
                  child: Row(children: [
                    _cell(5, _value(r.numero ?? '—', strong: true)),
                    _cell(3, QcLineChip(r.ligne, dense: true)),
                    _cell(3, r.machine == null ? _value('—') : Text('Machine ${r.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText))),
                    _cell(4, Tooltip(message: r.userEmail ?? '', child: _value(prodUserLabel(r.userEmail)))),
                    _cell(3, _value(prodFormatDate(r.date))),
                    _cell(5, status(r)),
                    _cell(4, Wrap(children: _ficheActions(r))),
                  ]),
                ),
            ]);
          }),
      ],
    );
  }

  // ── Dernières demandes de matières premières ───────────────────────────

  String _materials(RawMaterialRequestRecord r) => r.items.isEmpty
      ? '—'
      : r.items.map((i) => '${i.label} : ${prodFormatQuantity(i.quantiteDemandee, i.unite)}').join(' · ');

  String? _validator(RawMaterialRequestRecord r) => r.validatedByEmail ?? r.rejectedByEmail ?? r.eveningHandledByEmail;

  Widget _rawSection() {
    final source = _raw!;
    final o = source.data;
    bool isPending(RawMaterialRequestRecord r) => r.status == 'PENDING_VALIDATION' || r.status == 'SUBMITTED';
    List<Widget> actions(RawMaterialRequestRecord r) => [
          if (isPending(r) && o!.isValidator)
            TextButton(
              key: ValueKey('prod-raw-process-${r.id}'),
              onPressed: () => context.go('${RawMaterialPaths.tracking}?id=${r.id}'),
              style: TextButton.styleFrom(foregroundColor: _kPending, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
              child: const Text('Traiter'),
            )
          else
            TextButton(
              key: ValueKey('prod-raw-open-${r.id}'),
              onPressed: () => context.go('${RawMaterialPaths.tracking}?id=${r.id}'),
              style: TextButton.styleFrom(foregroundColor: kProductionColor, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
              child: const Text('Voir'),
            ),
        ];
    Widget status(RawMaterialRequestRecord r) {
      final color = rawMaterialStatusColor(r.status);
      return _Pill(label: rawMaterialStatusLabel(r.status), color: color, icon: isPending(r) ? Icons.hourglass_top_rounded : Icons.circle_outlined);
    }

    const columns = <(String, int)>[('Numéro', 4), ('Demandeur', 3), ('Date et heure', 3), ('Poste', 2), ('Matières demandées', 7), ('Statut', 4), ('Validateur', 4), ('Actions', 2)];
    return QcSection(
      key: const ValueKey('prod-raw'),
      icon: Icons.inventory_2_outlined,
      title: 'Dernières demandes de matières premières',
      subtitle: 'Les demandes les plus récentes, toutes dates',
      color: kProductionColor,
      trailing: TextButton.icon(
        onPressed: () => context.go(RawMaterialPaths.tracking),
        style: TextButton.styleFrom(foregroundColor: kProductionColor),
        icon: const Icon(Icons.list_alt_rounded, size: 16),
        label: const Text('Voir toutes'),
      ),
      children: [
        if (source.error != null)
          QcErrorBanner(qcT('Demandes de matières premières indisponibles : {}').replaceFirst('{}', source.error!), onRetry: _load)
        else if (o == null || o.latest.isEmpty)
          const QcEmptyState('Aucune demande de matières premières pour le moment', icon: Icons.inventory_2_outlined)
        else
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 900) {
              return Column(children: [
                for (final r in o.latest)
                  Container(
                    key: ValueKey('prod-raw-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: _value(r.requestNumber, strong: true)), status(r)]),
                      const SizedBox(height: 4),
                      fm.Text('${prodUserLabel(r.userEmail)} · ${_dateTime(r.createdAt?.toLocal())} · ${qcT(rawMaterialPosteLabel(r.poste))}', style: tInter(fontSize: 12, color: kCrmTextSub)),
                      const SizedBox(height: 4),
                      fm.Text(_materials(r), style: tInter(fontSize: 12.5, color: kCrmText)),
                      Row(children: [
                        Expanded(child: fm.Text('${qcT('Validateur')} : ${_validator(r) ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmTextSub))),
                        ...actions(r),
                      ]),
                    ]),
                  ),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _tableHeader(columns),
              for (final r in o.latest)
                Container(
                  key: ValueKey('prod-raw-${r.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
                  child: Row(children: [
                    _cell(4, _value(r.requestNumber, strong: true)),
                    _cell(3, Tooltip(message: r.userEmail, child: _value(prodUserLabel(r.userEmail)))),
                    _cell(3, _value(_dateTime(r.createdAt?.toLocal()))),
                    _cell(2, Text(rawMaterialPosteLabel(r.poste), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmText))),
                    _cell(7, Tooltip(message: _materials(r), child: fm.Text(_materials(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmText)))),
                    _cell(4, status(r)),
                    _cell(4, Tooltip(message: _validator(r) ?? '', child: _value(prodUserLabel(_validator(r))))),
                    _cell(2, Wrap(children: actions(r))),
                  ]),
                ),
            ]);
          }),
      ],
    );
  }

  // ── Quantités et déchets ───────────────────────────────────────────────

  String _rate(ProductionLineStats l) => l.tauxDechets == null ? 'N/A' : prodFormatNumber(l.tauxDechets);

  Widget _stat(String label, String value, {String? unit}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        fm.Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
        if (unit != null) fm.Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, color: kCrmTextSub)),
      ]);

  Widget _quantitiesSection(ProductionDashboard d) => QcSection(
        key: const ValueKey('prod-quantities'),
        icon: Icons.straighten_rounded,
        title: 'Quantités et déchets',
        subtitle: 'Quantités des fiches validées · chaque ligne dans son unité',
        color: kProductionColor,
        children: [
          for (final l in d.lines)
            Container(
              key: ValueKey('prod-line-${l.type}'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(_lineIcon(l.type), size: 17, color: _lineColor(l.type)),
                  const SizedBox(width: 8),
                  Expanded(child: fm.Text(l.label, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText))),
                  TextButton.icon(
                    onPressed: () => context.go(l.type == 'probar' ? ProdPaths.probarSummary : ProdPaths.promeshSummary),
                    style: TextButton.styleFrom(foregroundColor: _lineColor(l.type), minimumSize: const Size(0, 30)),
                    icon: const Icon(Icons.summarize_outlined, size: 16),
                    label: const Text('Résumé'),
                  ),
                ]),
                const SizedBox(height: 6),
                qcGrid(columns: (w) => w >= 420 ? 4 : 2, gap: 12, [
                  _stat('Fiches validées', '${l.validees}'),
                  _stat('Quantité', prodFormatNumber(l.quantite), unit: l.unit),
                  _stat('Déchets', prodFormatNumber(l.dechets), unit: l.wasteUnit),
                  _stat('Taux de déchets', _rate(l), unit: l.tauxDechetsUnit),
                ]),
              ]),
            ),
        ],
      );

  /// Évolution des déchets (kg) : une courbe par ligne, même unité.
  Widget _wasteChart(ProductionDashboard d) {
    final days = [for (final x in d.daily) if (x.dechetsPromesh > 0 || x.dechetsProbar > 0) x];
    final maxY = days.fold<double>(0, (m, x) => [m, x.dechetsPromesh, x.dechetsProbar].reduce((a, b) => a > b ? a : b));
    LineChartBarData line(Color color, double Function(ProductionDay) value) => LineChartBarData(
          spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), value(days[i]))],
          color: color,
          barWidth: 2,
          dotData: FlDotData(getDotPainter: (s, p, bar, i) => FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: kCrmSurface)),
        );
    return QcSection(
      icon: Icons.show_chart_rounded,
      title: 'Évolution des déchets',
      subtitle: 'Déchets déclarés par jour (kg)',
      color: kProductionColor,
      trailing: _legend(const [('PROMESH', kPromeshColor), ('PROBAR', kProbarColor)]),
      children: [
        if (days.isEmpty)
          const QcEmptyState('Aucun déchet déclaré sur cette période', icon: Icons.show_chart_rounded)
        else
          SizedBox(
            height: 210,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 12),
              child: LineChart(
                key: const ValueKey('prod-chart-waste'),
                LineChartData(
                  minX: 0,
                  maxX: days.length <= 1 ? 1 : (days.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY * 1.15,
                  gridData: _grid,
                  borderData: _border,
                  titlesData: _titles(
                    interval: (days.length / 6).ceilToDouble().clamp(1, double.infinity).toDouble(),
                    bottom: (v) => v.toInt() >= days.length ? const SizedBox.shrink() : fm.Text(_shortDate(days[v.toInt()].date), style: tInter(fontSize: 10, color: kCrmTextSub)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => kCrmText,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.barIndex == 0 ? 'PROMESH' : 'PROBAR'} · ${prodFormatDate(days[s.spotIndex].date)} · ${prodFormatQuantity(s.y, 'kg')}',
                            tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [line(kPromeshColor, (x) => x.dechetsPromesh), line(kProbarColor, (x) => x.dechetsProbar)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Accès rapides ──────────────────────────────────────────────────────

  Widget _quickLinks() {
    Widget link(String id, IconData icon, String title, String caption, Color color, String route) => Material(
          color: kCrmSurface,
          borderRadius: BorderRadius.circular(kQcRadius),
          child: InkWell(
            key: ValueKey('prod-link-$id'),
            onTap: () => context.go(route),
            borderRadius: BorderRadius.circular(kQcRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(kQcRadius), border: Border.all(color: kCrmBorder)),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                    Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: kCrmTextSub, size: 20),
              ]),
            ),
          ),
        );
    return QcSection(
      icon: Icons.bolt_rounded,
      title: 'Accès rapides',
      color: kProductionColor,
      children: [
        qcGrid(columns: (w) => w >= 1000 ? 3 : (w >= 560 ? 2 : 1), [
          link('new-promesh', Icons.add_circle_outline_rounded, 'Nouvelle fiche PROMESH', 'Choisir la machine et le poste', kPromeshColor, ProdPaths.promesh),
          link('new-probar', Icons.add_circle_outline_rounded, 'Nouvelle fiche PROBAR', 'Choisir la machine et le poste', kProbarColor, ProdPaths.probar),
          link('summary-promesh', Icons.summarize_outlined, 'Résumé PROMESH', 'Production Summary et export', kPromeshColor, ProdPaths.promeshSummary),
          link('summary-probar', Icons.summarize_outlined, 'Résumé PROBAR', 'Production Summary et export', kProbarColor, ProdPaths.probarSummary),
          link('records', Icons.list_alt_rounded, 'Fiches de production', 'Historique PROMESH et PROBAR, filtres', kProductionColor, ProdPaths.records),
          link('summary', Icons.analytics_outlined, 'Résumé Production', 'Toutes lignes, par diamètre', kProductionColor, ProdPaths.summary),
        ]),
      ],
    );
  }
}
