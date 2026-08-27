// lib/forms/industrial/view/melange_form_screen.dart
//
// Fiche MÉLANGE — formulaire minimal "Suivi journalier" (§MODIFICATION —
// FICHE MÉLANGE, dernière simplification) :
//   • uniquement Date, Heure début, Heure fin, Quantité, PROMESH, Déchet,
//     Opérateur (lecture seule) — plus de "N° chute fibre", plus de
//     tableau/Totaux, plus de stepper ;
//   • après Save/Finish, navigue vers /melange/detail?id=<id> (au lieu de
//     rester sur le formulaire) ;
//   • double-soumission (double clic Save/Finish) bloquée par le flag
//     `_saving`, vérifié de façon synchrone AVANT tout appel réseau.
//
// Les fiches MÉLANGE créées avant ce ticket peuvent contenir en base
// (melangeData JSONB : ravitaillement/consommation/rapport/chuteFibre) des
// données que ce formulaire n'affiche plus et ne renvoie plus — elles
// restent consultables en lecture seule sur melange_details_screen.dart et
// ne sont jamais supprimées de la base par ce formulaire.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../theme/industrial_theme.dart';
import '../model/industrial_record_model.dart';
import '../service/industrial_record_service.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

// §MODIFICATION — FICHE MÉLANGE : valeurs EXACTES du dropdown PROMESH,
// imposées par le ticket — jamais une valeur inventée/normalisée.
const List<String> kMelangePromeshValues = [
  'PROMESH #1',
  'PROMESH #2',
  'PROMESH #3',
  'PROMESH #4',
];

// ─────────────────────────────────────────────────────────────────────────────
// MelangeFormScreen
// ─────────────────────────────────────────────────────────────────────────────
class MelangeFormScreen extends StatefulWidget {
  final String? id;
  const MelangeFormScreen({super.key, this.id});
  @override
  State<MelangeFormScreen> createState() => _MelangeFormScreenState();
}

class _MelangeFormScreenState extends State<MelangeFormScreen> {
  bool _saving = false;
  bool _loadingEdit = false;
  String? _recordId;

  // ── Suivi journalier ──────────────────────────────────────────────────────
  final _date        = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _heureDebut  = TextEditingController();
  final _heureFin    = TextEditingController();
  // §MODIFICATION — FICHE MÉLANGE : "Opérateur" n'est plus un champ
  // modifiable — ce contrôleur ne sert plus qu'à AFFICHER le nom de
  // l'utilisateur connecté (jamais envoyé au backend comme source de
  // vérité : le serveur dérive toujours l'opérateur de req.user/JWT).
  final _operateur   = TextEditingController();
  final _quantite    = TextEditingController();
  // §MODIFICATION — FICHE MÉLANGE : renommé depuis "Échantillon".
  final _dechet      = TextEditingController();
  String? _promesh;

  // ── Init / Dispose ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // §MODIFICATION — FICHE MÉLANGE : "Opérateur" affiché en lecture seule —
    // toujours l'utilisateur connecté pour une NOUVELLE fiche (en édition,
    // _loadForEdit ci-dessous affiche l'opérateur déjà enregistré sur la
    // fiche, jamais modifiable non plus).
    if (widget.id == null) {
      _operateur.text = AuthService().displayName;
    } else {
      _loadingEdit = true;
      _loadForEdit(widget.id!);
    }
  }

  // ── Chargement d'une fiche existante (mode édition) ─────────────────────────
  // Le Ravitaillement / la Consommation / le Rapport journalier / N° chute
  // fibre / Remarques & Signature d'une ancienne fiche ne sont plus affichés
  // ici (formulaire simplifié) mais restent conservés en base (voir
  // melange_details_screen.dart, lecture seule) — cette édition ne les
  // efface jamais (ils ne sont simplement pas reconstruits/renvoyés dans
  // `melangeData`, voir _save()).
  Future<void> _loadForEdit(String id) async {
    try {
      final r = await IndustrialRecordService.instance.fetchById(id);
      if (!mounted) return;
      final data = r.melangeData ?? const <String, dynamic>{};

      _recordId = r.id;
      _date.text = r.dateFiche ?? _date.text;
      _operateur.text = r.operateur ?? (data['operateur']?.toString() ?? '');
      // §MODIFICATION — FICHE MÉLANGE : préfère les colonnes structurées
      // (r.heureDebut/heureFin) — repli sur melangeData pour les fiches
      // créées avant ce ticket, qui n'ont pas encore ces colonnes.
      _heureDebut.text = r.heureDebut ?? data['heureDebut']?.toString() ?? '';
      _heureFin.text = r.heureFin ?? data['heureFin']?.toString() ?? '';
      _quantite.text = r.quantiteProduite?.toString() ?? '';
      _dechet.text = r.dechet ?? '';
      _promesh = (r.promesh != null && kMelangePromeshValues.contains(r.promesh)) ? r.promesh : null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppLocalizations.of(context).translate('Erreur de chargement')} : $e'),
              backgroundColor: kCrmDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingEdit = false);
    }
  }

  @override
  void dispose() {
    _date.dispose(); _heureDebut.dispose(); _heureFin.dispose();
    _operateur.dispose(); _quantite.dispose(); _dechet.dispose();
    super.dispose();
  }

  // §MODIFICATION — FICHE MÉLANGE : validations obligatoires avant
  // enregistrement — Date/Heure début/Heure fin/Quantité/PROMESH. Retourne
  // le premier message d'erreur rencontré, ou `null` si tout est valide.
  // Même règle heureFin >= heureDebut que côté backend (comparaison de
  // chaînes HH:mm zero-paddées, cohérente avec le TimePicker Flutter).
  String? _validate(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    if (_date.text.trim().isEmpty) return t('La date est obligatoire');
    if (_heureDebut.text.trim().isEmpty) return t('L\'heure de début est obligatoire');
    if (_heureFin.text.trim().isEmpty) return t('L\'heure de fin est obligatoire');
    if (_heureFin.text.compareTo(_heureDebut.text) < 0) {
      return t('L\'heure de fin doit être postérieure ou égale à l\'heure de début');
    }
    final qte = double.tryParse(_quantite.text.trim().replaceAll(',', '.'));
    if (qte == null || qte <= 0) return t('La quantité doit être un nombre supérieur à 0');
    if (_promesh == null || _promesh!.isEmpty) return t('PROMESH est obligatoire');
    return null;
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────────
  // §MODIFICATION — FICHE MÉLANGE : le flag `_saving` est vérifié EN PREMIER
  // et positionné via setState() de façon parfaitement synchrone, AVANT le
  // premier `await` — un double clic (Save puis Finish, ou double clic sur
  // le même bouton) sur les deux boutons du bas déclenche bien deux appels à
  // `_save()`, mais le second voit toujours `_saving == true` et sort
  // immédiatement : une seule fiche est jamais créée par soumission.
  Future<void> _save() async {
    if (_saving) return;
    final validationError = _validate(context);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: kCrmDanger),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final model = IndustrialRecordModel(
        id:          _recordId,
        module:      'melange',
        dateFiche:   _date.text.trim().isEmpty ? null : _date.text.trim(),
        // §MODIFICATION — FICHE MÉLANGE : envoyé pour affichage immédiat côté
        // client uniquement — le backend ignore toujours cette valeur et
        // dérive l'opérateur de req.user/JWT (voir
        // industrialRecord.service.js#resolveOperateurFromActor).
        operateur:   _operateur.text.trim().isEmpty ? null : _operateur.text.trim(),
        description: null,
        heureDebut:   _heureDebut.text.trim(),
        heureFin:     _heureFin.text.trim(),
        quantiteProduite: double.tryParse(_quantite.text.trim().replaceAll(',', '.')),
        promesh:      _promesh,
        dechet:       _dechet.text.trim().isEmpty ? null : _dechet.text.trim(),
        // §MODIFICATION — FICHE MÉLANGE : plus de sous-structure à envoyer
        // (ravitaillement/consommation/rapport/chuteFibre retirés du
        // formulaire) — melangeData n'a plus lieu d'être pour une nouvelle
        // fiche.
        melangeData: null,
        statut:      'enregistree',
      );

      final saved = _recordId == null
          ? await IndustrialRecordService.instance.create(model)
          : await IndustrialRecordService.instance.update(_recordId!, model);
      final savedId = saved.id ?? _recordId;
      _recordId = savedId;

      if (!mounted) return;
      // §MODIFICATION — FICHE MÉLANGE : après enregistrement, navigue vers
      // la page de détails de la fiche créée/modifiée au lieu de rester sur
      // le formulaire.
      if (savedId != null) {
        context.go('${MyRoute.melangeDetailScreen}?id=$savedId');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).translate('Fiche enregistrée')),
        backgroundColor: kMelangeColor,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger,
        duration: const Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(onBack: () => context.go(MyRoute.melangeHistoriqueScreen)),
          Expanded(
            child: _loadingEdit
                ? const Center(child: CircularProgressIndicator())
                : _SuiviJournalier(
                    date: _date, heureDebut: _heureDebut, heureFin: _heureFin,
                    operateur: _operateur, quantite: _quantite, dechet: _dechet,
                    promesh: _promesh,
                    onPromeshChanged: (v) => setState(() => _promesh = v),
                  ),
          ),
          _BottomNav(saving: _saving, onSave: _save),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: kCrmSurface,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        InkWell(onTap: onBack, borderRadius: BorderRadius.circular(8),
            child: Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(border: Border.all(color: kCrmBorder),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_back_rounded, size: 16, color: kCrmTextSub))),
        const SizedBox(width: 14),
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: kMelangeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.science_outlined, size: 20, color: kMelangeColor)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLocalizations.of(context).translate('Fiche MÉLANGE'),
              style: tInter(fontSize: 16, fontWeight: FontWeight.w900, color: kCrmText)),
          Text(AppLocalizations.of(context).translate('Saisie de production'),
              style: tInter(fontSize: 11, color: kCrmTextSub)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation — "Enregistrer" (Save) et "Terminer" (Finish) restent
// tous deux disponibles en permanence et déclenchent la même sauvegarde ;
// tous deux se désactivent dès le premier clic (voir `saving`).
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _BottomNav({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(color: kCrmSurface,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        const Spacer(),
        OutlinedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(AppLocalizations.of(context).translate('Enregistrer')),
          style: OutlinedButton.styleFrom(foregroundColor: kMelangeColor,
              side: BorderSide(color: kMelangeColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: saving ? null : onSave,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(AppLocalizations.of(context).translate('Terminer')),
            style: ElevatedButton.styleFrom(backgroundColor: kMelangeColor,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUIVI JOURNALIER — Date / Heure début-fin / Quantité-PROMESH / Déchet /
// Opérateur. §MODIFICATION — FICHE MÉLANGE : plus de N° chute fibre, plus
// de tableau, plus de bloc Totaux.
// ─────────────────────────────────────────────────────────────────────────────
class _SuiviJournalier extends StatelessWidget {
  final TextEditingController date, heureDebut, heureFin, operateur, quantite, dechet;
  final String? promesh;
  final ValueChanged<String?> onPromeshChanged;

  const _SuiviJournalier({
    required this.date, required this.heureDebut, required this.heureFin,
    required this.operateur, required this.quantite, required this.dechet,
    required this.promesh, required this.onPromeshChanged,
  });

  InputDecoration _dec(BuildContext context, String label, IconData icon, {bool required = false}) => InputDecoration(
    labelText: AppLocalizations.of(context).translate(label) + (required ? ' *' : ''),
    labelStyle: tInter(fontSize: 13, color: kCrmTextSub),
    prefixIcon: Icon(icon, size: 18, color: kMelangeColor),
    filled: true, fillColor: kCrmBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kMelangeColor, width: 1.5)),
  );

  // §MODIFICATION — FICHE MÉLANGE : DatePicker — jamais de saisie manuelle
  // libre (format toujours cohérent, garantit `dateFiche obligatoire`).
  Future<void> _pickDate(BuildContext context) async {
    final initial = DateTime.tryParse(date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) date.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  // §MODIFICATION — FICHE MÉLANGE : TimePicker — sortie toujours au format
  // HH:mm zero-paddé (même convention que la validation backend/Joi).
  Future<void> _pickTime(BuildContext context, TextEditingController ctrl) async {
    TimeOfDay initial = TimeOfDay.now();
    final parts = ctrl.text.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setLocalState) {
      // Un StatefulBuilder local suffit : date/heureDebut/heureFin sont déjà
      // des TextEditingController (le texte affiché se met à jour tout
      // seul) — ce setState ne sert qu'à rafraîchir l'icône/le style du
      // champ juste après un choix, sans remonter d'état au parent.
      //
      // §RESPONSIVE — MISSION CRM RESPONSIVE (§12) : Heure début/Heure fin et
      // Quantité/PROMESH passent de 2 colonnes (Row+Expanded) à 1 colonne
      // empilée en dessous de 700px — un champ par ligne, comme demandé pour
      // mobile, tout en gardant le layout desktop/tablette à 2 colonnes.
      final heureDebutField = TextField(
        controller: heureDebut,
        readOnly: true,
        onTap: () => _pickTime(context, heureDebut).then((_) => setLocalState(() {})),
        decoration: _dec(context, 'Heure début', Icons.schedule_rounded, required: true),
        style: tInter(fontSize: 14, color: kCrmText),
      );
      final heureFinField = TextField(
        controller: heureFin,
        readOnly: true,
        onTap: () => _pickTime(context, heureFin).then((_) => setLocalState(() {})),
        decoration: _dec(context, 'Heure fin', Icons.schedule_rounded, required: true),
        style: tInter(fontSize: 14, color: kCrmText),
      );
      final quantiteField = TextField(
        controller: quantite,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: _dec(context, 'Quantité', Icons.scale_outlined, required: true),
        style: tInter(fontSize: 14, color: kCrmText),
      );
      final promeshField = DropdownButtonFormField<String>(
        initialValue: promesh,
        items: [
          for (final v in kMelangePromeshValues) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: onPromeshChanged,
        decoration: _dec(context, 'PROMESH', Icons.factory_outlined, required: true),
        style: tInter(fontSize: 14, color: kCrmText),
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.assignment_outlined, title: 'Suivi journalier'),
          const SizedBox(height: 20),

          // ── Date / Heure début-fin / Quantité-PROMESH / Déchet /
          // Opérateur — ordre exact du mockup ────────────────────────────
          _Card(child: LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 500;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: date,
                readOnly: true,
                onTap: () => _pickDate(context).then((_) => setLocalState(() {})),
                decoration: _dec(context, 'Date', Icons.calendar_today_rounded, required: true),
                style: tInter(fontSize: 14, color: kCrmText),
              ),
              const SizedBox(height: 12),
              if (isMobile) ...[
                heureDebutField,
                const SizedBox(height: 12),
                heureFinField,
              ] else
                Row(children: [
                  Expanded(child: heureDebutField),
                  const SizedBox(width: 12),
                  Expanded(child: heureFinField),
                ]),
              const SizedBox(height: 12),
              if (isMobile) ...[
                quantiteField,
                const SizedBox(height: 12),
                promeshField,
              ] else
                Row(children: [
                  Expanded(child: quantiteField),
                  const SizedBox(width: 12),
                  Expanded(child: promeshField),
                ]),
              const SizedBox(height: 12),
              // §MODIFICATION — FICHE MÉLANGE : renommé depuis "Échantillon".
              TextField(
                controller: dechet,
                decoration: _dec(context, 'Déchet', Icons.delete_outline_rounded),
                style: tInter(fontSize: 14, color: kCrmText),
              ),
              const SizedBox(height: 12),
              // §MODIFICATION — FICHE MÉLANGE : Opérateur — lecture seule,
              // jamais un champ modifiable. Toujours l'utilisateur connecté
              // (voir _MelangeFormScreenState.initState/_loadForEdit).
              TextField(
                controller: operateur,
                readOnly: true,
                enabled: false,
                decoration: _dec(context, 'Opérateur', Icons.lock_outline_rounded),
                style: tInter(fontSize: 14, color: kCrmText),
              ),
            ]);
          })),
          const SizedBox(height: 20),
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: kMelangeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: kMelangeColor)),
      const SizedBox(width: 10),
      Text(AppLocalizations.of(context).translate(title), style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCrmSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,3))],
      ),
      child: child,
    );
  }
}
