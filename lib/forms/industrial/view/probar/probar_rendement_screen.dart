// lib/forms/industrial/view/probar/probar_rendement_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import '../../controller/probar_controller.dart';
import 'probar_module_scaffold.dart';

class ProbarRendementScreen extends StatefulWidget {
  final String machine;
  final String poste;
  final String ficheId;
  const ProbarRendementScreen({
    super.key,
    required this.machine,
    required this.poste,
    required this.ficheId,
  });

  @override
  State<ProbarRendementScreen> createState() => _ProbarRendementScreenState();
}

class _ProbarRendementScreenState extends State<ProbarRendementScreen> {
  late final ProbarController c;
  bool _loading = true;
  bool _saving = false;
  // Valide les 2 champs du formulaire ProBar (quantité en mètres, diamètre)
  // — voir _save()/_saveAndReturnToModules().
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    c = Get.isRegistered<ProbarController>()
        ? Get.find<ProbarController>()
        : Get.put(ProbarController(), permanent: true);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await c.bootstrapWithId(widget.machine, widget.poste, widget.ficheId);
    if (!mounted) return;
    if (c.isLocked.value) {
      context.go(_fichePath);
      return;
    }
    setState(() => _loading = false);
  }

  String get _base => '${MyRoute.productionProbarRoot}/machine/${widget.machine}/poste/${widget.poste}';
  String get _fichePath => '$_base/dashboard';
  String get _modulesPath => '$_base/modules?ficheId=${widget.ficheId}';

  Future<void> _save() async {
    if (_saving) return;
    // Enregistrement de brouillon : affiche les erreurs de validation le cas
    // échéant (retour visuel immédiat) mais n'empêche jamais la sauvegarde —
    // même convention que les autres écrans-module.
    _formKey.currentState?.validate();
    setState(() => _saving = true);
    try {
      await c.saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).translate('Rendement enregistré')),
              backgroundColor: kCrmSuccess,
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'),
            backgroundColor: kCrmDanger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Enregistre puis revient TOUJOURS à la page Modules de cette même fiche
  // (jamais vers un autre module, jamais vers la liste des fiches) —
  // conserve machine+poste, donc l'identité de la fiche (recordId reste
  // dans le ProbarController singleton).
  Future<void> _saveAndReturnToModules() async {
    if (_saving) return;
    // "Suivant" valide d'abord les 2 champs ProBar — aucune sauvegarde ni
    // navigation si le formulaire est invalide.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await c.saveDraft();
      if (mounted) context.go(_modulesPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'),
            backgroundColor: kCrmDanger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProbarModuleScaffold(
      title: AppLocalizations.of(context).translate('Rendement'),
      icon: Icons.speed_rounded,
      color: kProbarColor,
      machine: widget.machine,
      poste: widget.poste,
      backRoute: _modulesPath,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      onNext: _saveAndReturnToModules,
      nextLabel: AppLocalizations.of(context).translate('Suivant'),
      nextIcon: Icons.arrow_forward_rounded,
      controller: c,
      child: Form(key: _formKey, child: _RendementBody(c: c)),
    );
  }
}

class _RendementBody extends StatelessWidget {
  final ProbarController c;
  const _RendementBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context).translate('Production du poste'),
          style: tInter(fontSize: 16, fontWeight: FontWeight.w900, color: kCrmText)),
      const SizedBox(height: 6),
      Text(
          AppLocalizations.of(context)
              .translate('Saisissez la quantité produite en m² pour ce poste.'),
          style: tInter(fontSize: 13, color: kCrmTextSub)),
      const SizedBox(height: 28),
      _ProbarOutputFieldsCard(c: c),
    ]);
  }
}

String? _requiredPositiveNumberValidator(BuildContext context, String? value) {
  if (value == null || value.trim().isEmpty) {
    return AppLocalizations.of(context).translate('Champ requis');
  }
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null || parsed <= 0) {
    return AppLocalizations.of(context).translate('Doit être un nombre supérieur à 0');
  }
  return null;
}

/// Formulaire Output ProBar (2 champs) — remplace l'ancien "Quantité
/// produite" (une seule mesure géante en m²). Réutilise le mécanisme de
/// sauvegarde existant du contrôleur ProBar (aucune nouvelle API) :
///   • Quantité en mètres → `c.productionM2` (champ Rendement historique,
///     déjà sauvegardé/rechargé via `quantiteProduite`).
///   • Diamètre           → `c.diameterController` (nouveau, stocké dans le
///     JSON compact `description`, clé `dia` — voir ProbarController).
class _ProbarOutputFieldsCard extends StatelessWidget {
  final ProbarController c;
  const _ProbarOutputFieldsCard({required this.c});

  static const double _mobileBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    // Ordre d'affichage demandé : Diamètre → Quantité (aucun changement de
    // valeur/unité/validation/placeholder/icône/nom de champ backend —
    // uniquement l'ordre des _ProbarOutputField dans cette liste).
    final fields = <Widget>[
      _ProbarOutputField(
        icon: Icons.circle_outlined,
        label: 'Diamètre',
        controller: c.diameterController,
        hintKey: 'Ex: 12',
        suffixText: AppLocalizations.of(context).translate('mm'),
        validator: (v) => _requiredPositiveNumberValidator(context, v),
      ),
      _ProbarOutputField(
        icon: Icons.straighten_rounded,
        label: 'Quantité en mètres pour ProBar',
        controller: c.productionM2,
        hintKey: 'Ex: 1250',
        suffixText: AppLocalizations.of(context).translate('m'),
        validator: (v) => _requiredPositiveNumberValidator(context, v),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kProbarColor.withOpacity(0.3), width: 1.4),
        boxShadow: [
          BoxShadow(color: kProbarColor.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 10)),
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

/// Un champ Output ProBar — icône dans un bloc orange clair, label + étoile
/// rouge (obligatoire), champ de saisie avec placeholder et suffixe d'unité.
class _ProbarOutputField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hintKey;
  final String suffixText;
  final String? Function(String?) validator;

  const _ProbarOutputField({
    required this.icon,
    required this.label,
    required this.controller,
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
          decoration: BoxDecoration(color: kProbarColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: kProbarColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: AppLocalizations.of(context).translate(label),
              style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText),
              children: [
                TextSpan(text: ' *', style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmDanger)),
              ],
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kProbarColor),
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
              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kProbarColor, width: 1.6)),
          errorBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmDanger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCrmDanger, width: 1.6)),
        ),
      ),
    ]);
  }
}
