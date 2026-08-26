// lib/forms/industrial/view/melange/melange_history_card.dart
//
// Carte "fiche historique" du module MÉLANGE — même pattern visuel que
// PROBAR (_ProbarFicheCard) / POR PROMESH (_PorPromeshCard) : icône + infos
// à gauche, badge de statut + actions (Voir / Modifier / Supprimer) à
// droite. Desktop = carte horizontale, mobile = infos empilées.
//
// §MODIFICATION — HISTORIQUE FICHES MÉLANGE : la fiche simplifiée ne
// contient plus que Date/Heure début/Heure fin/Quantité/PROMESH/Déchet/
// Opérateur/Statut/Date de création — Total, Ravitaillements, Consommation,
// Zone (anciens champs du tableau industriel / données calculées de
// l'ancien formulaire) ne sont plus affichés ici. Ces colonnes restent en
// base (utilisées par d'autres modules / anciennes fiches) — seul
// l'affichage dans CET historique est retiré.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/model/industrial_record_model.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import 'melange_summary.dart';

class MelangeHistoryStatus {
  final String label;
  final Color color;
  const MelangeHistoryStatus(this.label, this.color);

  static MelangeHistoryStatus of(IndustrialRecordModel model) {
    if (model.statutQualite == 'ok') return const MelangeHistoryStatus('OK', kCrmSuccess);
    if (model.statutQualite == 'nok') return const MelangeHistoryStatus('NOK', kCrmDanger);
    if (model.statut == 'brouillon') return const MelangeHistoryStatus('Brouillon', kCrmTextSub);
    return const MelangeHistoryStatus('Enregistrée', kCrmInfo);
  }
}

class MelangeHistoryCard extends StatelessWidget {
  final IndustrialRecordModel model;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MelangeHistoryCard({
    super.key,
    required this.model,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Vue liste : le backend renvoie déjà `melangeSummary` (léger) et
    // n'envoie `melangeData` (blob complet) que pour le détail/l'édition —
    // fromData() ne sert donc plus qu'en repli si l'API renvoie l'ancien
    // format complet.
    final summary = model.melangeData != null
        ? MelangeSummary.fromData(model.melangeData)
        : MelangeSummary.fromSummaryMap(model.melangeSummary);
    final status = MelangeHistoryStatus.of(model);
    final dateLabel = _formatDate(model.dateFiche);
    final createdLabel = _formatDateTime(model.createdAt);
    // §MODIFICATION — FICHE MÉLANGE : préfère les colonnes structurées
    // (model.heureDebut/heureFin) — repli sur le résumé (melangeData) pour
    // les fiches créées avant ce ticket.
    final heureDebut = (model.heureDebut?.isNotEmpty == true) ? model.heureDebut : summary.heureDebut;
    final heureFin = (model.heureFin?.isNotEmpty == true) ? model.heureFin : summary.heureFin;

    final infoContent = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: kMelangeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.science_outlined, color: kMelangeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(dateLabel, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
            if ((heureDebut ?? '').isNotEmpty || (heureFin ?? '').isNotEmpty)
              Text('${heureDebut?.isNotEmpty == true ? heureDebut : '—'} → ${heureFin?.isNotEmpty == true ? heureFin : '—'}',
                  style: tInter(fontSize: 12, color: kCrmTextSub)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      // §MODIFICATION — HISTORIQUE FICHES MÉLANGE : uniquement Opérateur/
      // PROMESH/Quantité/Déchet — Zone/Total/Ravitaillements/Consommations
      // (anciens champs calculés) retirés.
      Wrap(spacing: 16, runSpacing: 8, children: [
        if ((model.operateur ?? '').isNotEmpty) _chip(Icons.person_outline_rounded, model.operateur!),
        if ((model.promesh ?? '').isNotEmpty) _chip(Icons.factory_outlined, model.promesh!),
        if (model.quantiteProduite != null)
          _chip(Icons.scale_outlined,
              '${AppLocalizations.of(context).translate('Quantité')} : ${model.quantiteProduite}'),
        // §MODIFICATION — HISTORIQUE FICHES MÉLANGE : Déchet est une valeur
        // texte libre — affichée telle quelle, jamais transformée/parsée.
        if ((model.dechet ?? '').isNotEmpty)
          _chip(Icons.qr_code_2_outlined, '${AppLocalizations.of(context).translate('Déchet')} : ${model.dechet}'),
      ]),
      const SizedBox(height: 8),
      Text(
        '${AppLocalizations.of(context).translate('Créée le')} ${createdLabel ?? '—'}',
        style: tInter(fontSize: 11, color: kCrmTextSub),
      ),
    ]);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(AppLocalizations.of(context).translate(status.label),
          style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: status.color)),
    );

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: AppLocalizations.of(context).translate('Voir'),
        icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmTextSub),
        onPressed: onView,
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).translate('Modifier'),
        icon: const Icon(Icons.edit_outlined, size: 18, color: kCrmInfo),
        onPressed: onEdit,
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).translate('Supprimer'),
        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
        onPressed: onDelete,
      ),
    ]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCrmBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;
        if (isMobile) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            infoContent,
            const SizedBox(height: 14),
            badge,
            const SizedBox(height: 8),
            actions,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: infoContent),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            badge,
            const SizedBox(height: 8),
            actions,
          ]),
        ]);
      }),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: kCrmTextSub),
      const SizedBox(width: 4),
      Text(label, style: tInter(fontSize: 12, color: kCrmText)),
    ]);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : DateFormat('dd/MM/yyyy').format(d);
  }

  String? _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    return d == null ? raw : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }
}
