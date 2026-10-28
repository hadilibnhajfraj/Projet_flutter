// lib/production_compliance/view/production_compliance_dialogs.dart
//
// Interface métier des refus du contrôle PROD 1 / PROD 2 :
//   - showProductionError : affiche l'écran « FICHES DE PRODUCTION MANQUANTES »
//     — la LISTE À PUCES de toutes les dates manquantes (missingDates[], jamais
//     une seule date) — avec le bouton « Demander une autorisation », ou un
//     simple message pour toute autre erreur ;
//   - showAuthorizationRequestDialog : fenêtre de demande (utilisateur,
//     production, date demandée, TOUTES les dates manquantes, motif
//     obligatoire) — envoie UNE SEULE demande couvrant toutes ces dates
//     (statut PENDING). Les dates ne sont jamais envoyées au backend : il les
//     recalcule lui-même à la réception de la demande.
// Le blocage réel est appliqué par le backend ; aucune autorisation n'est
// jamais créée depuis cet écran.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../service/production_compliance_service.dart';
import '../service/production_draft_archive_service.dart';

String _fmt(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  return d == null ? (iso?.toString() ?? '') : DateFormat('dd/MM/yyyy').format(d);
}

List<String> _dates(Map<String, dynamic> data) {
  final list = (data['missingDates'] as List?)?.whereType<Object>().map((e) => e.toString()).toList();
  if (list != null && list.isNotEmpty) return list;
  final single = data['missingDate']?.toString();
  return single == null ? const [] : [single];
}

String productionLabel(dynamic key) {
  final k = key?.toString() ?? '';
  if (k.startsWith('PROD') && k.length > 4) return 'PROD ${k.substring(4)}';
  return k;
}

/// Affiche l'erreur : dialogue métier si le backend exige une autorisation,
/// sinon message simple. Retourne true si un dialogue métier a été affiché.
Future<bool> showProductionError(BuildContext context, Object error, {String? prefix}) async {
  if (error is ProductionApiException && error.needsAuthorization) {
    await _showMissingDialog(context, error);
    return true;
  }
  if (error is ProductionApiException && error.isArchived) {
    await _showArchivedDialog(context, error);
    return true;
  }
  if (!context.mounted) return false;
  final msg = ProductionComplianceService.friendlyError(error, fr: Localizations.localeOf(context).languageCode == 'fr');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(prefix == null ? msg : '$prefix $msg'),
    backgroundColor: Colors.red.shade700,
    duration: const Duration(seconds: 6),
  ));
  return false;
}

Future<void> _showMissingDialog(BuildContext context, ProductionApiException e) async {
  final data = e.data ?? {};
  final dates = _dates(data)..sort();

  await showDialog<void>(
    context: context,
    builder: (ctx) => MissingProductionSheetsDialog(
      isMissingPreviousSheet: e.isMissingPreviousSheet,
      dates: dates,
      requestedDate: data['requestedDate']?.toString(),
      production: data['production']?.toString(),
      userEmail: AuthService().userEmail,
      onRequestAuthorization: () async {
        Navigator.of(ctx).pop();
        if (context.mounted) {
          await showAuthorizationRequestDialog(context, missingDates: dates, production: data['production']?.toString(), requestedDate: data['requestedDate']?.toString());
        }
      },
    ),
  );
}

/// Popup « FICHES DE PRODUCTION MANQUANTES » : en-tête fixe, contenu central
/// défilable (la liste des dates a sa propre zone à hauteur maximale) et pied
/// fixe avec ANNULER / DEMANDER UNE AUTORISATION — jamais plus haute que la
/// fenêtre, quel que soit le nombre de dates (toutes restent consultables).
class MissingProductionSheetsDialog extends StatefulWidget {
  final bool isMissingPreviousSheet;
  /// Dates manquantes (YYYY-MM-DD), déjà triées.
  final List<String> dates;
  final String? requestedDate;
  final String? production;
  final String? userEmail;
  final VoidCallback onRequestAuthorization;

  const MissingProductionSheetsDialog({
    super.key,
    required this.isMissingPreviousSheet,
    required this.dates,
    required this.onRequestAuthorization,
    this.requestedDate,
    this.production,
    this.userEmail,
  });

  @override
  State<MissingProductionSheetsDialog> createState() => _MissingProductionSheetsDialogState();
}

class _MissingProductionSheetsDialogState extends State<MissingProductionSheetsDialog> {
  final _datesScroll = ScrollController();

  @override
  void dispose() {
    _datesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final dates = widget.dates;
    final requested = _fmt(widget.requestedDate);
    final media = MediaQuery.of(context);
    // Hauteur réellement disponible (clavier et zones de sécurité déduits),
    // dont la popup n'occupe jamais plus de 88 %.
    final available = media.size.height - media.viewInsets.vertical - media.padding.vertical;
    final maxHeight = available * 0.88;
    // Zone des dates : bornée, pour laisser visibles le message et les boutons.
    final datesMaxHeight = (available * 0.35).clamp(96.0, 300.0);

    return Dialog(
      key: const ValueKey('missing-sheets-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── En-tête fixe ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.isMissingPreviousSheet
                      ? t(dates.length > 1 ? 'MISSING PRODUCTION SHEETS' : 'MISSING PRODUCTION SHEET')
                      : t('PREVIOUS DATE'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ]),
          ),
          // ── Contenu central défilable ─────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('missing-sheets-body'),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.isMissingPreviousSheet) ...[
                  if (requested.isNotEmpty) ...[
                    Text('${t('You cannot create the sheet of')} $requested'),
                    const SizedBox(height: 6),
                  ],
                  Text(t(dates.length > 1 ? 'because the following sheets are missing:' : 'because the following sheet is missing:')),
                  const SizedBox(height: 8),
                  if (dates.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${dates.length} ${t('fiches manquantes')}',
                        key: const ValueKey('missing-sheets-count'),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: datesMaxHeight),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: _datesScroll,
                        thumbVisibility: dates.length > 6,
                        child: ListView.builder(
                          key: const ValueKey('missing-sheets-dates'),
                          controller: _datesScroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                          itemCount: dates.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(children: [
                              const Text('•  '),
                              Text(_fmt(dates[i]), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text('${t('This date is in the past')} (${dates.isNotEmpty ? _fmt(dates.first) : requested}).'),
                  const SizedBox(height: 6),
                  Text(t('A backfill authorization is required.')),
                ],
                const SizedBox(height: 12),
                Text(t('An authorization request must be sent to the Super Admin to regularize these dates.')),
                const SizedBox(height: 4),
                Text('${productionLabel(widget.production)} · ${widget.userEmail ?? ''}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
              ]),
            ),
          ),
          // ── Pied fixe : boutons toujours visibles, passent à la ligne ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  key: const ValueKey('missing-sheets-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t('CANCEL')),
                ),
                FilledButton.icon(
                  key: const ValueKey('missing-sheets-request'),
                  onPressed: widget.onRequestAuthorization,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(t('REQUEST AN AUTHORIZATION')),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Fiche archivée automatiquement (brouillon > 2h sans finalisation, voir
/// production-draft-archive) : affiche le motif et propose "Demander le
/// désarchivage" — jamais de modification directe possible depuis ce dialogue.
Future<void> _showArchivedDialog(BuildContext context, ProductionApiException e) async {
  final t = AppLocalizations.of(context).translate;
  final ficheId = e.data?['ficheId']?.toString();
  final ficheType = e.data?['ficheType']?.toString();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.archive_rounded, color: Colors.orange, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Text(t('Automatically archived'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      ]),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Sheet archived after 8 hours without completion')),
          const SizedBox(height: 8),
          Text('${t('User')} : ${AuthService().userEmail ?? ''}', style: const TextStyle(fontSize: 12)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t('CANCEL'))),
        if (ficheId != null && ficheType != null)
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (context.mounted) {
                await showUnarchiveRequestDialog(context, ficheType: ficheType, ficheId: ficheId);
              }
            },
            icon: const Icon(Icons.unarchive_rounded, size: 18),
            label: Text(t('Request unarchive')),
          ),
      ],
    ),
  );
}

/// Fenêtre "Demande de désarchivage" — motif obligatoire, une seule demande
/// par fiche (le backend réutilise la demande PENDING existante le cas échéant).
Future<Map<String, dynamic>?> showUnarchiveRequestDialog(
  BuildContext context, {
  required String ficheType,
  required String ficheId,
}) async {
  final t = AppLocalizations.of(context).translate;
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  final reasonCtrl = TextEditingController();
  bool sending = false;
  String? err;
  Map<String, dynamic>? result;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      return AlertDialog(
        title: Text(t('Unarchive request')),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t('Fiche')} : $ficheType #${ficheId.substring(0, ficheId.length < 8 ? ficheId.length : 8)}'),
            const SizedBox(height: 4),
            Text('${t('User')} : ${AuthService().userEmail ?? ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: '${t('Reason')} *', border: const OutlineInputBorder()),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          TextButton(onPressed: sending ? null : () => Navigator.of(ctx).pop(), child: Text(t('CANCEL'))),
          FilledButton(
            onPressed: sending
                ? null
                : () async {
                    if (reasonCtrl.text.trim().isEmpty) {
                      setD(() => err = fr ? 'Le motif est obligatoire.' : 'A reason is required.');
                      return;
                    }
                    setD(() {
                      sending = true;
                      err = null;
                    });
                    try {
                      result = await ProductionDraftArchiveService.instance.createRequest(ficheType: ficheType, ficheId: ficheId, reason: reasonCtrl.text);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setD(() {
                        sending = false;
                        err = ProductionDraftArchiveService.friendlyError(e, fr: fr);
                      });
                    }
                  },
            child: sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('SEND REQUEST')),
          ),
        ],
      );
    }),
  );

  if (result != null && context.mounted) {
    final already = result!['_alreadyPending'] == true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(t('Request sent'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        ]),
        content: Text(already
            ? t('A request was already pending for these dates — it has been sent to the Super Admin.')
            : t('Your regularization request has been sent to the manager.')),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t('OK')))],
      ),
    );
  }
  return result;
}

/// Fenêtre « Demande de régularisation de production » — couvre TOUTES les
/// dates manquantes en une seule demande. Le motif est obligatoire. Les dates
/// affichées viennent du 403 déjà reçu (pour l'affichage uniquement) ; le
/// backend recalcule et fige les dates réellement couvertes à la création.
/// Retourne la demande créée (ou null si annulée).
Future<Map<String, dynamic>?> showAuthorizationRequestDialog(
  BuildContext context, {
  required List<String> missingDates,
  String? production,
  String? requestedDate,
}) async {
  final t = AppLocalizations.of(context).translate;
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  final dates = [...missingDates]..sort();
  final reasonCtrl = TextEditingController();
  bool sending = false;
  String? err;
  Map<String, dynamic>? result;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      return AlertDialog(
        title: Text(t('Regularization authorization request')),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t('User')} : ${AuthService().userEmail ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${t('Production')} : ${productionLabel(production)}'),
            if (requestedDate != null) ...[
              const SizedBox(height: 4),
              Text('${t('Requested date')} : ${_fmt(requestedDate)}'),
            ],
            const SizedBox(height: 10),
            Text(t('Missing dates') + ' :', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in dates)
                Chip(label: Text(_fmt(d)), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: '${t('Reason')} *', border: const OutlineInputBorder()),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          TextButton(onPressed: sending ? null : () => Navigator.of(ctx).pop(), child: Text(t('CANCEL'))),
          FilledButton(
            onPressed: sending
                ? null
                : () async {
                    if (reasonCtrl.text.trim().isEmpty) {
                      setD(() => err = fr ? 'Le motif est obligatoire.' : 'A reason is required.');
                      return;
                    }
                    setD(() {
                      sending = true;
                      err = null;
                    });
                    try {
                      result = await ProductionComplianceService.instance.createRequest(reason: reasonCtrl.text, requestedDate: requestedDate);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setD(() {
                        sending = false;
                        err = ProductionComplianceService.friendlyError(e, fr: fr);
                      });
                    }
                  },
            child: sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('SEND REQUEST')),
          ),
        ],
      );
    }),
  );

  if (result != null && context.mounted) {
    await _showRequestSentDialog(context, result!);
  }
  return result;
}

/// Popup de confirmation « ✅ Demande envoyée » — affiche les dates
/// effectivement couvertes par la demande créée en base (recalculées par le
/// backend, jamais la liste locale du dialogue précédent).
Future<void> _showRequestSentDialog(BuildContext context, Map<String, dynamic> result) async {
  final t = AppLocalizations.of(context).translate;
  final already = result['_alreadyPending'] == true;
  final emailFailed = result['emailStatus'] == 'FAILED';
  final sentDates = _dates(result)..sort();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Text(t('Request sent'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      ]),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(already
              ? t('A request was already pending for these dates — it has been sent to the Super Admin.')
              : t('Your regularization request has been sent to the manager.')),
          if (sentDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t('Requested dates') + ' :', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final d in sentDates)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [const Text('•  '), Text(_fmt(d), style: const TextStyle(fontWeight: FontWeight.w700))]),
              ),
          ],
          const SizedBox(height: 12),
          Text(t('You will be notified when the request is processed.')),
          if (emailFailed) ...[
            const SizedBox(height: 8),
            Text(t('The e-mail notification will be retried automatically.'), style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
          ],
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t('OK')))],
    ),
  );
}

String requestStatusLabel(BuildContext context, String status) {
  final t = AppLocalizations.of(context).translate;
  switch (status) {
    case 'PENDING':
      return t('Request sent to the Super Admin');
    case 'APPROVED':
      return t('Authorization granted');
    // Statut calculé côté backend (jamais persisté tel quel) : au moins une date de
    // la demande est régularisée, au moins une autre ne l'est pas encore.
    case 'PARTIALLY_USED':
      return t('Partially regularized');
    case 'REJECTED':
      return t('Request rejected');
    case 'USED':
      return t('Regularization completed');
    case 'EXPIRED':
      return t('Authorization expired');
    default:
      return status;
  }
}

Color requestStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return Colors.blue;
    case 'PARTIALLY_USED':
      return Colors.teal;
    case 'USED':
      return Colors.green;
    case 'REJECTED':
      return Colors.red;
    case 'EXPIRED':
      return Colors.grey;
    default:
      return Colors.orange;
  }
}
