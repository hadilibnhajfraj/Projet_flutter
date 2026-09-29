// lib/quality_control/view/quality_control_history_screen.dart
//
// PRODUCTION / CONTRÔLE QUALITÉ — Historique des contrôles. Le backend
// limite déjà la liste aux contrôles de l'utilisateur connecté pour le rôle
// controle_qualite (admins : tous) — aucun filtrage de sécurité côté Flutter.

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/reports/view/report_widgets.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import '../model/quality_control_model.dart';
import '../service/quality_control_service.dart';
import 'quality_control_widgets.dart';

class QualityControlHistoryScreen extends StatefulWidget {
  const QualityControlHistoryScreen({super.key});

  @override
  State<QualityControlHistoryScreen> createState() => _QualityControlHistoryScreenState();
}

class _QualityControlHistoryScreenState extends State<QualityControlHistoryScreen> {
  final _hScroll = ScrollController();
  bool _loading = true;
  String? _error;
  String _status = '';
  List<QualityControlModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await QualityControlService.instance.fetchHistory(status: _status);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtProductionDate(String? v) {
    final d = DateTime.tryParse(v ?? '');
    return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
  }

  void _open(QualityControlModel c) => context.go('${MyRoute.qualityControlFormScreen}?id=${c.id}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                spacing: 12,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Historique des contrôles qualité', style: tInter(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText)),
                    const SizedBox(height: 4),
                    Text('Production / Contrôle qualité', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                  IndustrialBigButton(
                    label: 'Nouveau contrôle',
                    icon: Icons.add_rounded,
                    color: kQualityControlColor,
                    onTap: () => context.go(MyRoute.qualityControlFormScreen),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in const ['', 'EN_ATTENTE', 'EN_COURS', 'CONFORME', 'NON_CONFORME'])
                  ChoiceChip(
                    label: Text(s.isEmpty ? 'Tous' : kControlStatusLabels[s]!),
                    selected: _status == s,
                    onSelected: (_) {
                      setState(() => _status = s);
                      _load();
                    },
                  ),
              ]),
              const SizedBox(height: 16),
              ReportSection(
                title: 'Contrôles',
                icon: Icons.fact_check_outlined,
                subtitle: '${_items.length} contrôle(s)',
                children: [
                  if (_loading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Text('Erreur : $_error', style: tInter(color: kCrmDanger))
                  else if (_items.isEmpty)
                    const RpEmpty('Aucun contrôle qualité pour le moment')
                  else
                    _buildTable(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Scrollbar(
      controller: _hScroll,
      thumbVisibility: true,
      notificationPredicate: (n) => n.depth == 0,
      child: SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.touch,
          }),
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 40,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 56,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Heure')),
              DataColumn(label: Text('Production')),
              DataColumn(label: Text('Machine')),
              DataColumn(label: Text('Poste')),
              DataColumn(label: Text('Fiche')),
              DataColumn(label: Text('Date production')),
              DataColumn(label: Text('Contrôleur')),
              DataColumn(label: Text('Statut')),
              DataColumn(label: Text('Contrôlés'), numeric: true),
              DataColumn(label: Text('Non conformes'), numeric: true),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final c in _items)
                DataRow(cells: [
                  DataCell(Text(c.controlDate)),
                  DataCell(Text(c.controlTime)),
                  DataCell(Text(c.productionType,
                      style: TextStyle(fontWeight: FontWeight.w700, color: productionTypeColor(c.productionType)))),
                  DataCell(Text(c.machineLabel ?? '—')),
                  DataCell(Text(c.posteLabel ?? '—')),
                  DataCell(Text(c.ficheNumero ?? '—')),
                  DataCell(Text(_fmtProductionDate(c.productionDate))),
                  DataCell(Text(c.controllerEmail)),
                  DataCell(QualityStatusPill(c.status)),
                  DataCell(Text('${c.controlledCount} / ${c.totalCount}')),
                  DataCell(Tooltip(
                    message: c.nonConformParameters.join('\n'),
                    child: Text('${c.nonConformCount}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.nonConformCount > 0 ? kCrmDanger : null)),
                  )),
                  DataCell(TextButton(onPressed: () => _open(c), child: const Text('Voir'))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
