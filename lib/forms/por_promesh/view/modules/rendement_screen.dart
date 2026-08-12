// lib/forms/por_promesh/view/modules/rendement_screen.dart
//
// Module Rendement — formulaire ProMesh à 3 champs obligatoires : taille de
// maille, quantité produite (m², jamais en kg), diamètre. Une seule carte,
// pas de grille dense de champs secondaires.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import '../../controller/por_promesh_controller.dart';
import 'module_scaffold.dart';

class RendementScreen extends StatefulWidget {
  final String machine;
  final String poste;
  final String ficheId;

  const RendementScreen({
    super.key,
    required this.machine,
    required this.poste,
    required this.ficheId,
  });

  @override
  State<RendementScreen> createState() => _RendementScreenState();
}

class _RendementScreenState extends State<RendementScreen> {
  late final PorPromeshController c;
  bool _loading = true;
  bool _saving = false;
  bool _nextBusy = false;
  // Valide les 3 champs du formulaire ProMesh (taille de maille, quantité
  // m², diamètre) — voir _save()/_saveAndNext().
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // `permanent: true` : ce controller est partagé par les 5 écrans-module
    // (et l'écran Informations générales) de la session machine/poste — il
    // ne doit jamais être supprimé par le dispose() d'un écran particulier.
    // Flutter construit l'écran suivant (initState) AVANT de détruire
    // l'écran précédent (dispose, différé en fin de frame) : si chaque écran
    // supprimait ce controller partagé en quittant, l'écran suivant — qui
    // l'a retrouvé via Get.find() et l'utilise déjà — se retrouvait avec des
    // TextEditingController disposés sous les pieds ("used after disposed").
    c = Get.isRegistered<PorPromeshController>()
        ? Get.find<PorPromeshController>()
        : Get.put(PorPromeshController(), permanent: true);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await c.bootstrapWithId(widget.machine, widget.poste, widget.ficheId);
    if (!mounted) return;
    if (c.isLocked.value || c.status.value == 'submitted') {
      context.go(_fichePath);
      return;
    }
    setState(() => _loading = false);
  }

  String get _fichePath =>
      '${MyRoute.productionPromeshRoot}/machine/${widget.machine}/poste/${widget.poste}/dashboard';
  String get _modulesPath =>
      '${MyRoute.productionPromeshRoot}/machine/${widget.machine}/poste/${widget.poste}/modules?ficheId=${widget.ficheId}';

  Future<void> _save() async {
    // Enregistrement de brouillon : affiche les erreurs de validation le
    // cas échéant (retour visuel immédiat) mais n'empêche jamais la
    // sauvegarde — même convention que les autres écrans-module (voir
    // module_scaffold.dart, "Enregistrer" doit rester disponible pour un
    // brouillon partiel).
    _formKey.currentState?.validate();
    setState(() => _saving = true);
    try {
      await c.saveDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('Rendement enregistré'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).translate('Erreur :')} $e'),
          backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _backRoute => _modulesPath;

  // Enregistre puis revient TOUJOURS à la page Modules de cette même fiche
  // (jamais vers un autre module, jamais vers la liste des fiches).
  Future<void> _saveAndNext() async {
    // "Suivant" valide d'abord les 3 champs ProMesh — aucune sauvegarde ni
    // navigation si le formulaire est invalide.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _nextBusy = true);
    try {
      await c.saveDraft();
      if (!mounted) return;
      context.go(_modulesPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).translate('Erreur :')} $e'),
          backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _nextBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Rendement',
      icon: Icons.speed_rounded,
      color: kPromeshColor,
      machine: widget.machine,
      poste: widget.poste,
      controller: c,
      backRoute: _backRoute,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      onNext: _saveAndNext,
      nextBusy: _nextBusy,
      child: Form(key: _formKey, child: _PromeshFieldsCard(controller: c)),
    );
  }
}

/// Formulaire ProMesh (3 champs) — remplace l'ancien "Quantité Produite"
/// (une seule mesure géante). Les 3 champs partagent le mécanisme de
/// sauvegarde existant du contrôleur PROMESH (aucune nouvelle API) :
///   • Taille de maille  → `controller.diametreMaille1` (déjà persisté,
///     jamais exposé dans une UI de saisie jusqu'ici).
///   • Quantité en m²    → `controller.productionM2` (champ Rendement
///     historique, déjà sauvegardé/rechargé).
///   • Diamètre          → `controller.diametreMaille2` (idem
///     diametreMaille1, réutilisé plutôt que d'ajouter une colonne backend).
class _PromeshFieldsCard extends StatelessWidget {
  final PorPromeshController controller;

  const _PromeshFieldsCard({required this.controller});

  static const double _mobileBreakpoint = 760;

  String? _validateRequired(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).translate('Champ requis');
    }
    return null;
  }

  String? _validatePositiveNumber(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).translate('Champ requis');
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return AppLocalizations.of(context).translate('Doit être un nombre supérieur à 0');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Ordre d'affichage demandé : Diamètre → Taille de maille → Quantité
    // (aucun changement de valeur/unité/validation/nom de champ backend —
    // uniquement l'ordre des _PromeshField dans cette liste).
    final fields = <Widget>[
      _PromeshField(
        icon: Icons.circle_outlined,
        label: 'Diamètre',
        isRequired: true,
        controller: controller.diametreMaille2,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        hintKey: 'Ex: 8',
        suffixText: 'mm',
        validator: (v) => _validatePositiveNumber(context, v),
      ),
      _PromeshField(
        icon: Icons.grid_4x4_rounded,
        label: 'Taille de maille pour ProMesh',
        isRequired: true,
        controller: controller.diametreMaille1,
        keyboardType: TextInputType.text,
        hintKey: 'Ex: 50 x 50',
        suffixText: 'mm',
        validator: (v) => _validateRequired(context, v),
      ),
      _PromeshField(
        icon: Icons.square_foot_rounded,
        label: 'Quantité en m² pour ProMesh',
        isRequired: true,
        controller: controller.productionM2,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        hintKey: 'Ex: 1250',
        suffixText: 'm²',
        validator: (v) => _validatePositiveNumber(context, v),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kPromeshColor.withOpacity(0.3), width: 1.4),
        boxShadow: [
          BoxShadow(color: kPromeshColor.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _mobileBreakpoint;
        if (isNarrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 22),
              fields[i],
            ],
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: fields[i]),
          ],
        ]);
      }),
    );
  }
}

/// Un champ ProMesh — icône dans un bloc bleu clair, label (+ étoile rouge
/// si obligatoire), champ de saisie avec placeholder et suffixe d'unité.
class _PromeshField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hintKey;
  final String suffixText;
  final String? Function(String?) validator;

  const _PromeshField({
    required this.icon,
    required this.label,
    required this.isRequired,
    required this.controller,
    required this.keyboardType,
    required this.hintKey,
    required this.suffixText,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: kPromeshColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: kPromeshColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: AppLocalizations.of(context).translate(label),
              style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText),
              children: isRequired
                  ? [TextSpan(text: ' *', style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmDanger))]
                  : null,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kPromeshColor),
        validator: validator,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: kCrmBg,
          hintText: AppLocalizations.of(context).translate(hintKey),
          hintStyle: tInter(fontSize: 14, fontWeight: FontWeight.w600, color: kCrmTextSub),
          suffixText: suffixText,
          suffixStyle: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmTextSub),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmBorder)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPromeshColor, width: 1.6)),
          errorBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmDanger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmDanger, width: 1.6)),
        ),
      ),
    ]);
  }
}
