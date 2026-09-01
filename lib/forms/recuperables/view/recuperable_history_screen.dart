// lib/forms/recuperables/view/recuperable_history_screen.dart
//
// Historique RÉCUPÉRABLES — cartes (machine, ligne, date, Waste/Finished
// Product, statut). Vert = module, Orange = en cours, Gris = clôturée.
//
// §MODIFICATION — CORRECTION AFFICHAGE RECOVERABLES HISTORY : la carte
// n'affiche plus que les DEUX valeurs de la fiche simplifiée (`waste`/
// `finishedProduct`, jamais additionnées) — "Clôture prévue", le nombre de
// lignes et le total "kg récupérable" issus de l'ancien système par diamètre
// (`recuperables`/`totalDechetKg`/`nombreLignes`) ne sont plus affichés ici.
// Ces champs restent inchangés dans le modèle/l'API et sur les AUTRES écrans
// (détail, stats, exports) — cette page est la SEULE modifiée par ce ticket.
// `waste`/`finishedProduct` sont `null` pour une fiche créée avant ce
// ticket : affichés comme `0.00 kg`, jamais une erreur.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/por_promesh/view/widgets/shimmer_box.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../theme/recuperable_theme.dart';
import '../model/recuperable_models.dart';
import '../service/recuperable_service.dart';

const _kStatutFilters = [
  ('all', 'Tous les statuts'),
  ('en_cours', 'En cours'),
  ('cloturee', 'Terminée'),
];

class RecuperableHistoryScreen extends StatefulWidget {
  const RecuperableHistoryScreen({super.key});

  @override
  State<RecuperableHistoryScreen> createState() => _RecuperableHistoryScreenState();
}

class _RecuperableHistoryScreenState extends State<RecuperableHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<RecuperableFicheModel> _all = [];
  String _statutFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await RecuperableService.instance.fetchAll();
      items.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      if (!mounted) return;
      setState(() => _all = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RecuperableFicheModel> get _filtered =>
      _statutFilter == 'all' ? _all : _all.where((f) => f.statut == _statutFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: IndustrialPageBody(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(AppLocalizations.of(context).translate('Historique Récupérables'),
                        style: tInter(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText)),
                  ),
                  IndustrialBigButton(
                    label: AppLocalizations.of(context).translate('Nouvelle fiche'),
                    icon: Icons.add_rounded,
                    color: kRecuperableColor,
                    onTap: () => context.go(MyRoute.recuperableFicheScreen),
                  ),
                ]),
                const SizedBox(height: 20),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final f in _kStatutFilters)
                    _FilterChip(label: f.$2, selected: _statutFilter == f.$1, onTap: () => setState(() => _statutFilter = f.$1)),
                ]),
                const SizedBox(height: 20),
                if (_loading)
                  const FicheCardSkeletonList()
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text('${AppLocalizations.of(context).translate('Erreur')} : $_error', style: tInter(color: kCrmDanger))),
                  )
                else if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.inbox_outlined, size: 48, color: kCrmTextSub.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(AppLocalizations.of(context).translate('Aucune fiche pour ces filtres'), style: tInter(fontSize: 14, color: kCrmTextSub)),
                      ]),
                    ),
                  )
                else
                  ..._filtered.map((f) => _FicheCard(
                        fiche: f,
                        onTap: () => context.go('${MyRoute.recuperableDetailScreen}?id=${f.id}'),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kRecuperableColor.withOpacity(0.12) : kCrmSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kRecuperableColor : kCrmBorder),
        ),
        child: Text(AppLocalizations.of(context).translate(label),
            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? kRecuperableColor : kCrmTextSub)),
      ),
    );
  }
}

class _FicheCard extends StatelessWidget {
  final RecuperableFicheModel fiche;
  final VoidCallback onTap;
  const _FicheCard({required this.fiche, required this.onTap});

  // §MODIFICATION — CORRECTION AFFICHAGE RECOVERABLES HISTORY (carte
  // compacte) : en-tête (icône + titre/date + badge statut, statut centré
  // verticalement sur cette ligne) puis, en dessous, Waste/Finished Product
  // en deux blocs "label au-dessus / valeur en dessous" — côte à côte quand
  // la largeur RÉELLEMENT disponible pour la carte le permet (LayoutBuilder
  // local, jamais une largeur fixe), empilés sinon. Purement visuel : aucune
  // donnée/logique/API touchée — toujours `fiche.waste`/`fiche.
  // finishedProduct` (jamais additionnés, jamais affichés en cas de `null`
  // grâce à `?? 0`), `fiche.isOpen` pour le badge, rien d'autre.
  @override
  Widget build(BuildContext context) {
    final statut = recuperableStatutInfo(fiche.statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statut.color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── En-tête : icône + titre/date (Expanded) + badge statut ──────
            Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: kRecuperableColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Text('♻️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fiche.module} · ${AppLocalizations.of(context).translate('Machine')} ${fiche.machine} · ${fiche.ligne} · ${fiche.posteLabel}',
                      style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
                  const SizedBox(height: 2),
                  Text('${AppLocalizations.of(context).translate('Date')} : ${_fmt(fiche.date)}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: statut.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(statut.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  // Libellé anglais demandé pour CETTE carte uniquement — ne
                  // touche pas `recuperableStatutInfo` (partagé avec le
                  // détail, qui garde ses libellés existants, inchangés).
                  Text(AppLocalizations.of(context).translate(fiche.isOpen ? 'In progress' : 'Completed'),
                      style: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: statut.color)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            // ── Waste / Finished Product — deux blocs distincts ─────────────
            LayoutBuilder(builder: (context, constraints) {
              final wasteBlock = _valueBlock(context, 'Waste', '${(fiche.waste ?? 0).toStringAsFixed(2)} kg');
              final finishedBlock = _valueBlock(context, 'Finished Product', '${(fiche.finishedProduct ?? 0).toStringAsFixed(2)} kg');
              final isNarrow = constraints.maxWidth < 360;
              return isNarrow
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      wasteBlock,
                      const SizedBox(height: 10),
                      finishedBlock,
                    ])
                  : Row(children: [
                      Expanded(child: wasteBlock),
                      const SizedBox(width: 16),
                      Expanded(child: finishedBlock),
                    ]);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _valueBlock(BuildContext context, String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context).translate(label), style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      const SizedBox(height: 2),
      Text(value, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
    ]);
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : DateFormat('dd/MM/yyyy').format(d);
  }
}
