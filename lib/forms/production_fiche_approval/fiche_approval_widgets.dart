// lib/forms/production_fiche_approval/fiche_approval_widgets.dart
//
// Affichage du statut de validation d'une fiche de production dans les
// écrans existants (listes, détails, grilles de modules) : badge, message
// (motif exact du refus et date de décision) et bandeau de correction avec
// nouvelle soumission. Rien n'est affiché pour une fiche hors circuit.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import 'fiche_approval_record.dart';
import 'fiche_approval_service.dart';

String faT(BuildContext context, String key) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)?.translate(key) ?? key;

String faDateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
String faDate(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

/// Libellé de la saisie existante (« Validé(e) ») d'une fiche soumise à
/// validation : « Saisie terminée », jamais « Validée » avant la décision.
String ficheSaisieLabel(BuildContext context, {required bool finished, required FicheApproval? approval, required String legacyLabel}) {
  if (!finished) return legacyLabel;
  return approval == null ? legacyLabel : faT(context, 'Saisie terminée');
}

class FicheApprovalBadge extends StatelessWidget {
  final String status;
  final bool compact;
  /// Libellés du module de validation (« En attente » / « Acceptée » /
  /// « Refusée ») au lieu de ceux des écrans du producteur.
  final bool decisionWording;
  const FicheApprovalBadge({super.key, required this.status, this.compact = false, this.decisionWording = false});

  static Widget? maybe(FicheApproval? approval, {bool compact = false}) =>
      approval == null ? null : FicheApprovalBadge(status: approval.status, compact: compact);

  @override
  Widget build(BuildContext context) {
    // Mapping explicite : un statut inconnu n'est jamais présenté comme une décision.
    final known = kFicheApprovalStatuses[status];
    final color = known?.$2 ?? kCrmTextSub;
    final label = known == null ? 'Statut inconnu' : (decisionWording ? kFicheDecisionLabels[status]! : known.$1);
    final icon = switch (status) {
      'APPROVED' => Icons.check_circle_rounded,
      'REJECTED' => Icons.cancel_rounded,
      'PENDING' => Icons.schedule_rounded,
      _ => Icons.help_outline_rounded,
    };
    return Container(
      key: ValueKey('fiche-approval-badge-$status'),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 12 : 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(faT(context, label),
              overflow: TextOverflow.ellipsis,
              style: tInter(fontSize: compact ? 10.5 : 11.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

/// Message de statut pour le créateur (et les autres lecteurs) d'une fiche.
class FicheApprovalNotice extends StatelessWidget {
  final FicheApproval approval;
  /// Bouton « Soumettre de nouveau » (fiche refusée, créateur uniquement).
  final Widget? action;
  /// Libellé du badge au vocabulaire du module de validation.
  final bool decisionWording;
  const FicheApprovalNotice({super.key, required this.approval, this.action, this.decisionWording = false});

  @override
  Widget build(BuildContext context) {
    String t(String k) => faT(context, k);
    final (_, color) = kFicheApprovalStatuses[approval.status] ?? ('', kCrmTextSub);
    final String text;
    if (approval.isRejected) {
      text = '${t('Fiche refusée par le responsable logistique. Motif :')} ${approval.rejectionComment ?? '—'}. '
          '${t('Veuillez corriger la fiche.')}';
    } else if (approval.isApproved) {
      text = t('Fiche validée par le responsable logistique.');
    } else {
      text = t('Fiche en attente de validation par le responsable logistique.');
    }
    final decided = approval.isPending ? null : approval.decidedAt ?? approval.rejectedAt;
    return Container(
      key: ValueKey('fiche-approval-notice-${approval.status}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FicheApprovalBadge(status: approval.status, decisionWording: decisionWording),
          if (approval.version > 1) ...[
            const SizedBox(width: 8),
            Text('${t('Soumission n°')} ${approval.version}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ],
        ]),
        const SizedBox(height: 8),
        Text(text, key: const ValueKey('fiche-approval-message'),
            style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: approval.isRejected ? kCrmDanger : kCrmText)),
        if (decided != null) ...[
          const SizedBox(height: 4),
          Text(
            '${t('Décision du')} ${faDateTime(decided)}${approval.decidedByEmail == null ? '' : ' — ${approval.decidedByEmail}'}',
            style: tInter(fontSize: 12, color: kCrmTextSub),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 10), action!],
      ]),
    );
  }
}

/// Bouton « Soumettre de nouveau » d'une fiche refusée, après correction.
/// N'annonce le succès qu'une fois la nouvelle soumission enregistrée.
class FicheResubmitButton extends StatefulWidget {
  final String ficheType;
  final String ficheId;
  final FicheApprovalApi? api;
  final ValueChanged<FicheApprovalItem> onResubmitted;
  const FicheResubmitButton({super.key, required this.ficheType, required this.ficheId, required this.onResubmitted, this.api});

  @override
  State<FicheResubmitButton> createState() => _FicheResubmitButtonState();
}

class _FicheResubmitButtonState extends State<FicheResubmitButton> {
  bool _busy = false;

  Future<void> _go() async {
    String t(String k) => faT(context, k);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Soumettre de nouveau la fiche ?')),
        content: Text(t('La fiche corrigée sera de nouveau soumise à la validation du responsable logistique. Le refus précédent reste dans l\'historique.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('Annuler'))),
          FilledButton(
            key: const ValueKey('confirm-resubmit'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Soumettre')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final item = await (widget.api ?? FicheApprovalService.instance).resubmit(widget.ficheType, widget.ficheId);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(t('Fiche soumise de nouveau au responsable logistique.')),
        backgroundColor: kCrmSuccess,
      ));
      widget.onResubmitted(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('${t('Échec de la nouvelle soumission :')} ${FicheApprovalService.friendlyError(e)}'),
        backgroundColor: kCrmDanger,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('fiche-resubmit'),
      onPressed: _busy ? null : _go,
      icon: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 16),
      label: Text(faT(context, 'Soumettre de nouveau')),
    );
  }
}
