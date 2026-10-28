// lib/forms/raw_material_request/raw_material_request_dialog.dart
//
// Popups « Demande de matières premières » :
//   - RawMaterialRequestDialog : le formulaire (5 matières) en popup,
//     affiché avant la création d'une fiche PROMESH / PROBAR et à la connexion.
//     ensureRawMaterialRequest() est appelée par les boutons « Nouvelle
//     fiche » juste avant la création : elle ne renvoie true que si aucune
//     demande n'est exigée, ou si la demande vient d'être enregistrée.
//   - showRawMaterialRequiredDialog : popup d'information « Créer la
//     demande / Annuler » qui redirige vers la page de demande (MÉLANGE, et
//     repli quand la vérification automatique échoue).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import 'raw_material_request_form.dart';
import 'raw_material_request_service.dart';

export 'raw_material_request_form.dart';

/// À appeler juste avant de créer une fiche. Renvoie true si la création
/// peut continuer, false si elle doit être abandonnée (popup annulée,
/// vérification impossible).
///
/// Seul le poste Matin peut être concerné : pour le poste du soir aucun
/// appel n'est fait et le parcours existant reste strictement inchangé.
/// Pour le Matin, le backend décide à partir du compte authentifié.
Future<bool> ensureRawMaterialRequest(
  BuildContext context, {
  required String module, // 'promesh' | 'probar'
  required String machine,
  required String poste,
  Future<bool> Function()? checkRequired,
  RawMaterialSubmit? submit,
}) async {
  if (poste != 'matin') return true;

  // Le backend décide (vendredi uniquement, heure du serveur).
  final RawMaterialRequirement req;
  try {
    req = checkRequired != null
        ? RawMaterialRequirement(required: await checkRequired())
        : await RawMaterialRequestService.instance.requirement(module: module, poste: poste);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Vérification de la demande de matières premières impossible : '
            '${RawMaterialRequestService.friendlyError(e)}'),
        backgroundColor: Colors.red.shade700,
      ));
    }
    return false;
  }
  if (!req.required) return true;
  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RawMaterialRequestDialog(
      module: module,
      machine: machine,
      poste: poste,
      submit: submit,
      deadlineAt: req.deadlineAt,
      deadlinePassed: req.deadlinePassed,
      rejection: req.rejected,
    ),
  );
  return ok == true;
}

class RawMaterialRequestDialog extends StatefulWidget {
  /// 'promesh' | 'probar' ; null pour la popup affichée à la connexion.
  final String? module;
  final String? machine;
  final String poste;

  /// Injection pour les tests ; par défaut, POST /raw-material-requests
  /// (ou PUT …/resubmit pour corriger une demande rejetée).
  final RawMaterialSubmit? submit;

  /// Échéance de validation (vendredi 14 h) renvoyée par le backend.
  final DateTime? deadlineAt;
  final bool deadlinePassed;

  /// Demande rejetée à corriger : valeurs rechargées, nouvelle soumission.
  final RawMaterialRejection? rejection;

  const RawMaterialRequestDialog({
    super.key,
    this.module,
    this.machine,
    required this.poste,
    this.submit,
    this.deadlineAt,
    this.deadlinePassed = false,
    this.rejection,
  });

  @override
  State<RawMaterialRequestDialog> createState() => _RawMaterialRequestDialogState();
}

class _RawMaterialRequestDialogState extends State<RawMaterialRequestDialog> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 5 lignes : le tableau défile verticalement entre l'en-tête et la zone
    // Validation, toujours visible. Écran étroit ou bas (en-tête et zone
    // Validation sur plusieurs lignes) : toute la popup défile, boutons en bas.
    final pin = size.height >= 520 && size.width >= 600;
    final header = RawMaterialRequestHeader(
      module: widget.module,
      machine: widget.machine,
      poste: widget.poste,
      subtitle: widget.module == null
          ? 'À valider avant de commencer la production du poste.'
          : 'À valider avant la création de la fiche de production.',
      trailing: IconButton(
        tooltip: rmT(context, 'Annuler'),
        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        icon: const Icon(Icons.close_rounded, color: kCrmTextSub),
      ),
    );
    final rejection = widget.rejection;
    final notice = RawMaterialDeadlineNotice(
      deadlineAt: widget.deadlineAt,
      deadlinePassed: widget.deadlinePassed,
      resubmission: rejection != null,
      rejectionComment: rejection?.comment,
    );
    final form = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: RawMaterialRequestForm(
        module: widget.module,
        machine: widget.machine,
        poste: widget.poste,
        initialItems: rejection?.items,
        submit: widget.submit ??
            (rejection == null ? null : (_, lines) => RawMaterialRequestService.instance.resubmit(rejection.id, lines: lines)),
        pinValidation: pin,
        onSubmittingChanged: (v) => setState(() => _submitting = v),
        onSaved: (_) => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    const padding = EdgeInsets.fromLTRB(20, 18, 12, 20);
    return PopScope(
      canPop: !_submitting,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: kCrmSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1080, maxHeight: size.height * 0.92),
          child: pin
              ? Padding(
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, const Divider(height: 28, color: kCrmBorder), notice, Flexible(child: form)],
                  ),
                )
              : SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, const Divider(height: 28, color: kCrmBorder), notice, form],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Popup d'information affichée quand une demande est exigée avant une
/// nouvelle fiche. Renvoie true pour « Créer la demande », false pour
/// « Annuler ». [error] : échec de la vérification automatique, affiché tel
/// quel (jamais masqué).
Future<bool> showRawMaterialRequiredDialog(BuildContext context, {String? module, String? error, DateTime? deadlineAt, bool deadlinePassed = false}) async {
  final accent = rawMaterialAccent(module);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: kCrmSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.inventory_2_rounded, color: accent, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                rmT(ctx, 'Demande de matières premières'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText),
              ),
              const SizedBox(height: 10),
              Text(
                rmT(ctx, 'Avant de créer votre fiche de production, vous devez renseigner et valider '
                    'votre demande de matières premières.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: kCrmTextSub),
              ),
              if (deadlineAt != null) ...[
                const SizedBox(height: 14),
                RawMaterialDeadlineNotice(deadlineAt: deadlineAt, deadlinePassed: deadlinePassed),
              ],
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const ValueKey('raw-material-check-error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kCrmWarning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kCrmWarning.withValues(alpha: 0.5)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, color: kCrmWarning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${rmT(ctx, 'La vérification automatique a échoué')} : $error',
                          style: const TextStyle(fontSize: 12.5, color: kCrmText)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                    child: Text(rmT(ctx, 'Annuler')),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('raw-material-create-request'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(rmT(ctx, 'Créer la demande')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result == true;
}
