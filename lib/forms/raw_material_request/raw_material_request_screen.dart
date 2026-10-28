// lib/forms/raw_material_request/raw_material_request_screen.dart
//
// Page « Demande de matières premières » (route RawMaterialPaths.request,
// déclarée dans my_route.dart qui fournit les destinations retour/suite) — cible du bouton « Créer la demande »
// de la popup d'information. Même formulaire que la popup
// (RawMaterialRequestForm) ; après enregistrement confirmé par le backend,
// confirmation puis retour au parcours de production.
//
// checkMelangeRawMaterialRequest() : contrôle appelé avant toute nouvelle
// fiche MÉLANGE (bouton de l'historique et ouverture du formulaire vide).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import 'raw_material_request_dialog.dart';
import 'raw_material_request_login_prompt.dart' show kRawMaterialLoginEmails, normalizeEmail;
import 'raw_material_request_paths.dart';
import 'raw_material_request_service.dart';

typedef RawMaterialRequirementCheck = Future<RawMaterialRequirement> Function();

enum RawMaterialGateResult { proceed, redirected, cancelled }

/// Avant une nouvelle fiche MÉLANGE : si une demande est exigée (backend :
/// production_1, poste Matin), popup « Créer la demande / Annuler ».
/// Les autres comptes passent sans aucun appel réseau.
Future<RawMaterialGateResult> checkMelangeRawMaterialRequest(
  BuildContext context, {
  required String returnTo,
  Future<String?> Function()? loadEmail,
  RawMaterialRequirementCheck? checkRequirement,
}) async {
  final email = normalizeEmail(await (loadEmail ?? () async => AuthService().userEmail)());
  if (!kRawMaterialLoginEmails.contains(email)) return RawMaterialGateResult.proceed;

  String? error;
  RawMaterialRequirement? r;
  try {
    r = await (checkRequirement ?? () => RawMaterialRequestService.instance.requirement(module: 'melange'))();
    if (!r.required) return RawMaterialGateResult.proceed;
  } catch (e) {
    // Jamais masquée : affichée dans la popup, qui permet quand même d'ouvrir le formulaire.
    error = RawMaterialRequestService.friendlyError(e);
  }
  if (!context.mounted) return RawMaterialGateResult.cancelled;
  final create = await showRawMaterialRequiredDialog(context,
      module: 'melange', error: error, deadlineAt: r?.deadlineAt, deadlinePassed: r?.deadlinePassed ?? false);
  if (!create || !context.mounted) return RawMaterialGateResult.cancelled;
  context.go(rawMaterialRequestPath(module: 'melange', returnTo: returnTo));
  return RawMaterialGateResult.redirected;
}

class RawMaterialRequestScreen extends StatefulWidget {
  /// Module de la fiche à venir ('melange') ; null : demande générale
  /// (ouverte depuis la connexion).
  final String? module;

  /// Page d'origine (« Annuler », « Retour »).
  final String returnTo;

  /// Suite du parcours de production après enregistrement.
  final String continueTo;
  final String continueLabel;

  /// Injections pour les tests.
  final RawMaterialRequirementCheck? checkRequirement;
  final RawMaterialSubmit? submit;
  final Future<Map<String, dynamic>> Function(String id)? loadRequest;

  const RawMaterialRequestScreen({
    super.key,
    this.module,
    required this.returnTo,
    required this.continueTo,
    required this.continueLabel,
    this.checkRequirement,
    this.submit,
    this.loadRequest,
  });

  @override
  State<RawMaterialRequestScreen> createState() => _RawMaterialRequestScreenState();
}

enum _Stage { loading, form, notNeeded, saved }

class _RawMaterialRequestScreenState extends State<RawMaterialRequestScreen> {
  _Stage _stage = _Stage.loading;
  String _poste = 'matin';
  String? _checkError;
  DateTime? _savedAt;
  // Échéance et éventuel rejet à corriger, tels que renvoyés par le backend.
  RawMaterialRequirement? _req;
  // Demande enregistrée, relue depuis le backend (affichée en lecture seule).
  Map<String, dynamic>? _request;
  String? _reloadError;

  Future<Map<String, dynamic>> _load(String id) =>
      (widget.loadRequest ?? RawMaterialRequestService.instance.fetchById)(id);

  String get _returnTo => widget.returnTo;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.loading;
      _checkError = null;
    });
    try {
      final r = await (widget.checkRequirement ??
          () => widget.module == null
              ? RawMaterialRequestService.instance.sessionRequirement()
              : RawMaterialRequestService.instance.requirement(module: widget.module!))();
      // Demande déjà enregistrée et non utilisée : on recharge ses valeurs.
      // Jamais de formulaire vierge à la place : pas de 2e demande.
      Map<String, dynamic>? pending;
      String? reloadError;
      if (!r.required && r.pendingRequestId != null) {
        try {
          pending = await _load(r.pendingRequestId!);
        } catch (e) {
          reloadError = RawMaterialRequestService.friendlyError(e);
        }
      }
      if (!mounted) return;
      setState(() {
        _req = r;
        _poste = r.poste ?? _poste;
        _request = pending;
        _reloadError = reloadError;
        _stage = r.required ? _Stage.form : _Stage.notNeeded;
      });
    } catch (e) {
      // Vérification impossible : le formulaire reste accessible (poste
      // Matin, règle métier de production_1) ; le backend revérifie tout à
      // l'enregistrement et toute erreur est affichée.
      if (!mounted) return;
      setState(() {
        _checkError = RawMaterialRequestService.friendlyError(e);
        _stage = _Stage.form;
      });
    }
  }

  // Enregistrement confirmé par le backend : on relit la demande en base
  // pour afficher exactement ce qui a été enregistré.
  Future<void> _onSaved(Map<String, dynamic>? created) async {
    Map<String, dynamic>? reloaded = created;
    String? reloadError;
    final id = created?['id']?.toString();
    if (id != null) {
      try {
        reloaded = await _load(id);
      } catch (e) {
        reloadError = RawMaterialRequestService.friendlyError(e);
      }
    }
    if (!mounted) return;
    setState(() {
      _savedAt = DateTime.now();
      _request = reloaded;
      _reloadError = reloadError;
      _stage = _Stage.saved;
    });
  }

  void _continueProduction() => context.go(widget.continueTo);

  // Tableau en lecture seule de la demande enregistrée.
  Widget _savedTable() => Padding(
        key: ValueKey('raw-material-saved-table-${_request?['id']}'),
        padding: const EdgeInsets.only(bottom: 4),
        child: RawMaterialRequestForm(
          module: widget.module,
          poste: _poste,
          readOnly: true,
          initialItems: _request?['items'] as List<dynamic>?,
          onSaved: (_) {},
          onCancel: () {},
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accent = rawMaterialAccent(widget.module);
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: IndustrialPageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: kCrmSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCrmBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RawMaterialRequestHeader(
                    module: widget.module,
                    poste: _poste,
                    subtitle: 'Renseignez et validez votre demande avant de créer votre fiche de production.',
                  ),
                  const Divider(height: 28, color: kCrmBorder),
                  switch (_stage) {
                    _Stage.loading => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    _Stage.form => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_checkError != null) _checkErrorBanner(),
                        RawMaterialDeadlineNotice(
                          deadlineAt: _req?.deadlineAt,
                          deadlinePassed: _req?.deadlinePassed ?? false,
                          resubmission: _req?.rejected != null,
                          rejectionComment: _req?.rejected?.comment,
                        ),
                        RawMaterialRequestForm(
                          module: widget.module,
                          poste: _poste,
                          initialItems: _req?.rejected?.items,
                          submit: widget.submit ??
                              (_req?.rejected == null
                                  ? null
                                  : (_, lines) => RawMaterialRequestService.instance.resubmit(_req!.rejected!.id, lines: lines)),
                          onSaved: _onSaved,
                          onCancel: () => context.go(_returnTo),
                        ),
                      ]),
                    _Stage.notNeeded when _request != null => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _savedTable(),
                        _result(
                          icon: Icons.task_alt_rounded,
                          color: accent,
                          title: rmT(context, 'Demande déjà enregistrée'),
                          text: rmT(context, 'La demande de ce vendredi est déjà soumise : elle vaut pour toutes les fiches du jour.'),
                        ),
                      ]),
                    _Stage.notNeeded when _reloadError != null => _result(
                        icon: Icons.error_outline_rounded,
                        color: kCrmDanger,
                        title: rmT(context, 'Demande déjà enregistrée'),
                        text: '${rmT(context, 'Relecture de la demande impossible')} : $_reloadError',
                      ),
                    _Stage.notNeeded => _result(
                        icon: Icons.task_alt_rounded,
                        color: accent,
                        title: rmT(context, 'Aucune nouvelle demande nécessaire'),
                        text: rmT(
                            context,
                            'Une demande validée est déjà disponible pour votre prochaine fiche de production, '
                            'ou votre compte et votre poste ne sont pas concernés.'),
                      ),
                    _Stage.saved => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_request?['items'] is List) _savedTable(),
                        if (_reloadError != null)
                          Text('${rmT(context, 'Relecture de la demande impossible')} : $_reloadError',
                              style: const TextStyle(color: kCrmDanger, fontSize: 13)),
                        _result(
                        key: const ValueKey('raw-material-saved'),
                        icon: Icons.check_circle_rounded,
                        color: kCrmSuccess,
                        title: rmT(context, 'Demande enregistrée'),
                        text: '${rmT(context, 'Votre demande de matières premières a été enregistrée le')} '
                            '${DateFormat('dd/MM/yyyy HH:mm').format(_savedAt!)}. '
                            '${rmT(context, 'Vous pouvez maintenant créer votre fiche de production.')}',
                        ),
                      ]),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkErrorBanner() => Container(
        key: const ValueKey('raw-material-check-error'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCrmWarning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kCrmWarning.withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: kCrmWarning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${rmT(context, 'La vérification automatique a échoué')} : $_checkError\n'
              '${rmT(context, 'Vous pouvez saisir la demande : son enregistrement sera vérifié par le serveur.')}',
              style: const TextStyle(fontSize: 13, color: kCrmText),
            ),
          ),
          TextButton(onPressed: _check, child: Text(rmT(context, 'Réessayer'))),
        ]),
      );

  Widget _result({Key? key, required IconData icon, required Color color, required String title, required String text}) {
    final continueLabel = rmT(context, widget.continueLabel);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Icon(icon, color: color, size: 56),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kCrmText)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: kCrmTextSub)),
        const SizedBox(height: 22),
        Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 10, children: [
          OutlinedButton(
            onPressed: () => context.go(_returnTo),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            child: Text(rmT(context, 'Retour')),
          ),
          FilledButton.icon(
            key: const ValueKey('raw-material-continue'),
            onPressed: _continueProduction,
            style: FilledButton.styleFrom(
              backgroundColor: rawMaterialAccent(widget.module),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(continueLabel),
          ),
        ]),
      ]),
    );
  }
}
