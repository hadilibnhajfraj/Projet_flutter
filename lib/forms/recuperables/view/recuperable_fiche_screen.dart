// lib/forms/recuperables/view/recuperable_fiche_screen.dart
//
// Écran "Récupérables Traités" (Recoverables Processed) — formulaire
// industriel pensé pour un opérateur qui ne maîtrise pas l'informatique :
// en-tête (Date/Module/Machine/Ligne/Poste/Opérateur) TOUJOURS visible (fixe,
// hors zone de défilement) au-dessus de DEUX champs INDÉPENDANTS : Waste (kg)
// et Finished Product (kg) — jamais additionnés entre eux.
//
// §MODIFICATION — FICHE RECOVERABLES PROCESSED SIMPLIFIÉE : la grille par
// diamètre (Ø6-Ø28) est supprimée de cet écran de saisie — plus aucune
// logique diameter/diameterId/diameterMm/wasteByDiameter/
// finishedProductByDiameter/recoverableByDiameter ici. Les anciennes fiches
// (déjà enregistrées avec un détail par diamètre) ne sont ni supprimées ni
// modifiées — elles restent consultables telles quelles dans l'historique/le
// détail (voir recuperable_detail_screen.dart, inchangé, qui affiche encore
// `recuperables`/`kRecuperableDiametres` pour ces fiches-là).
//
// §MODIFICATION — SUPPRESSION "WASTE + FINISHED PRODUCT" : le champ combiné
// et son total ont été retirés de cet écran — `RecuperableFicheModel.
// wasteFinishedProduct` (modèle + backend) reste inchangé pour ne pas
// affecter les fiches qui l'ont déjà renseigné, mais n'est plus alimenté.
//
// §MODIFICATION — AJOUT FINISHED PRODUCT : `finishedProduct` est une valeur
// INDÉPENDANTE de `waste` (jamais une somme, jamais le même champ que
// l'ancien "Waste + Finished Product") — nouvelle colonne dédiée côté
// backend (voir migration 20260828000100), NULL pour toute fiche créée avant
// ce ticket. Aucune validation obligatoire ici non plus — un champ vide vaut
// 0. "Enregistrer" sauvegarde `waste`/`finishedProduct` en un seul appel ;
// "Terminer" clôture définitivement la fiche — comportement des deux boutons
// inchangé.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../theme/recuperable_theme.dart';
import '../model/recuperable_models.dart';
import '../service/recuperable_service.dart';

class RecuperableFicheScreen extends StatefulWidget {
  final String? id;
  const RecuperableFicheScreen({super.key, this.id});

  @override
  State<RecuperableFicheScreen> createState() => _RecuperableFicheScreenState();
}

class _RecuperableFicheScreenState extends State<RecuperableFicheScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _terminating = false;
  String? _error;
  RecuperableFicheModel? _fiche;

  // ── En-tête (verrouillé dès que la fiche existe) ──────────────────────────
  bool get _headerLocked => _fiche?.id != null;

  final _dateCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
  DateTime _date = DateTime.now();
  String _module = kRecuperableModules.first;
  String _machine = kRecuperableMachines.first;
  String _ligne = kRecuperableLignes.first;
  String _poste = kRecuperablePostes.first.$1;

  // ── Waste (kg) / Finished Product (kg) — deux valeurs indépendantes ───────
  final _wasteCtrl = TextEditingController();
  final _finishedProductCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _wasteCtrl.dispose();
    _finishedProductCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fiche = await RecuperableService.instance.fetchById(widget.id!);
      if (!mounted) return;
      _applyFiche(fiche);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFiche(RecuperableFicheModel fiche) {
    _module = fiche.module;
    _machine = fiche.machine;
    _ligne = fiche.ligne;
    _poste = fiche.poste;
    final d = DateTime.tryParse(fiche.date);
    if (d != null) {
      _date = d;
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(d);
    }
    // §MODIFICATION — FICHE RECOVERABLES PROCESSED SIMPLIFIÉE : `waste`/
    // `finishedProduct` sont `null` pour une fiche créée avant ce ticket
    // (jamais dérivés de `recuperables` — les notions restent indépendantes)
    // — champs vides (donc 0) dans ce cas, jamais d'erreur.
    _wasteCtrl.text = (fiche.waste == null || fiche.waste == 0) ? '' : _fmtNum(fiche.waste!);
    _finishedProductCtrl.text =
        (fiche.finishedProduct == null || fiche.finishedProduct == 0) ? '' : _fmtNum(fiche.finishedProduct!);
    setState(() => _fiche = fiche);
  }

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double _parse(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  double get _totalWaste => _parse(_wasteCtrl);
  double get _totalFinishedProduct => _parse(_finishedProductCtrl);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  Future<void> _save({bool silent = false}) async {
    setState(() => _saving = true);
    try {
      final model = RecuperableFicheModel(
        module: _module,
        machine: _machine,
        ligne: _ligne,
        poste: _poste,
        date: DateFormat('yyyy-MM-dd').format(_date),
        operateur: AuthService().displayName,
        waste: _parse(_wasteCtrl),
        finishedProduct: _parse(_finishedProductCtrl),
      );
      final saved = await RecuperableService.instance.saveFiche(model);
      if (!mounted) return;
      _applyFiche(saved);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).translate(saved.reused && _fiche == null ? 'Fiche existante rouverte' : 'Fiche enregistrée')),
          backgroundColor: kRecuperableColor,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _terminer() async {
    // On enregistre d'abord les dernières valeurs saisies pour ne rien perdre.
    await _save(silent: true);
    if (_fiche?.id == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AppLocalizations.of(context).translate('Terminer cette fiche ?')),
        content: Text(AppLocalizations.of(context).translate('Elle ne pourra plus être modifiée, supprimée, ni recevoir de nouvelles données.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRecuperableColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).translate('Terminer')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _terminating = true);
    try {
      await RecuperableService.instance.terminerFiche(_fiche!.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).translate('Fiche terminée')),
        backgroundColor: kRecuperableColor,
      ));
      context.go(MyRoute.recuperableHistoriqueScreen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _terminating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildTopBar(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${AppLocalizations.of(context).translate('Erreur')} : $_error', style: tInter(color: kCrmDanger)),
                      ),
                    // ── Informations générales — reste visible en permanence ──
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildWasteInputs(),
                      const SizedBox(height: 16),
                      _buildTotals(),
                      const SizedBox(height: 20),
                      _buildButtons(),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(children: [
      InkWell(
        onTap: () => context.go(MyRoute.recuperableHistoriqueScreen),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(border: Border.all(color: kCrmBorder), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.arrow_back_rounded, size: 16, color: kCrmTextSub),
        ),
      ),
      const SizedBox(width: 12),
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kRecuperableColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: const Text('♻️', style: TextStyle(fontSize: 20)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(AppLocalizations.of(context).translate('Récupérables Traités'), style: tInter(fontSize: 18, fontWeight: FontWeight.w900, color: kCrmText)),
      ),
    ]);
  }

  Widget _buildHeaderCard() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kRecuperableColor.withOpacity(0.3), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: _headerFields(isMobile))
          : Wrap(spacing: 18, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: _headerFields(isMobile)),
    );
  }

  List<Widget> _headerFields(bool isMobile) {
    Widget wrap(Widget child) => isMobile ? Padding(padding: const EdgeInsets.only(bottom: 12), child: child) : child;

    if (_headerLocked) {
      return [
        wrap(_lockedTile(Icons.event_outlined, 'Date', _dateCtrl.text)),
        wrap(_lockedTile(Icons.category_outlined, 'Module', _module)),
        wrap(_lockedTile(Icons.precision_manufacturing_outlined, 'Machine', '${AppLocalizations.of(context).translate('Machine')} $_machine')),
        wrap(_lockedTile(Icons.linear_scale_rounded, 'Ligne', _ligne)),
        wrap(_lockedTile(Icons.schedule_rounded, 'Poste',
            AppLocalizations.of(context).translate(kRecuperablePostes.firstWhere((p) => p.$1 == _poste).$2))),
        wrap(_lockedTile(Icons.person_outline_rounded, 'Opérateur', _fiche?.operateur ?? AuthService().displayName)),
      ];
    }

    return [
      wrap(_dateField()),
      wrap(_choiceField('Module', kRecuperableModules, _module, (v) => setState(() => _module = v))),
      wrap(_choiceField('Machine', kRecuperableMachines, _machine, (v) => setState(() => _machine = v), prefix: 'Machine ')),
      wrap(_choiceField('Ligne', kRecuperableLignes, _ligne, (v) => setState(() => _ligne = v))),
      wrap(_choiceField('Poste', kRecuperablePostes.map((p) => p.$1).toList(), _poste, (v) => setState(() => _poste = v),
          labelOf: (v) => kRecuperablePostes.firstWhere((p) => p.$1 == v).$2)),
      wrap(_lockedTile(Icons.person_outline_rounded, 'Opérateur', AuthService().displayName)),
    ];
  }

  Widget _lockedTile(IconData icon, String label, String value) {
    return SizedBox(
      width: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: kCrmTextSub),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(context).translate(label), style: tInter(fontSize: 10, color: kCrmTextSub)),
            Text(value, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _dateField() {
    return SizedBox(
      width: 170,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context).translate('Date'), style: tInter(fontSize: 10, color: kCrmTextSub)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickDate,
          child: Row(children: [
            Icon(Icons.event_outlined, size: 15, color: kRecuperableColor),
            const SizedBox(width: 6),
            Text(_dateCtrl.text, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
          ]),
        ),
      ]),
    );
  }

  Widget _choiceField(String label, List<String> options, String value, ValueChanged<String> onChanged,
      {String prefix = '', String Function(String)? labelOf}) {
    return SizedBox(
      width: 190,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context).translate(label), style: tInter(fontSize: 10, color: kCrmTextSub)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final o in options)
            _ChoiceChip(
              label: prefix.isNotEmpty
                  ? '${AppLocalizations.of(context).translate(prefix.trim())} $o'
                  : AppLocalizations.of(context).translate(labelOf?.call(o) ?? o),
              selected: value == o,
              color: kRecuperableColor,
              onTap: () => onChanged(o),
            ),
        ]),
      ]),
    );
  }

  // §MODIFICATION — AJOUT FINISHED PRODUCT : deux champs INDÉPENDANTS
  // (jamais combinés) — côte à côte quand l'espace le permet (desktop/
  // tablette ≥700px), empilés verticalement sur mobile (§RESPONSIVE du
  // ticket), toujours via Expanded/Column — jamais de largeur fixe, jamais
  // de RenderFlex overflow.
  Widget _buildWasteInputs() {
    final locked = _fiche != null && !_fiche!.isOpen;
    final isMobile = MediaQuery.of(context).size.width < 700;
    final wasteField = _wasteInputCard(label: 'Waste (kg)', ctrl: _wasteCtrl, locked: locked);
    final finishedProductField = _wasteInputCard(label: 'Finished Product (kg)', ctrl: _finishedProductCtrl, locked: locked);
    return isMobile
        ? Column(children: [wasteField, const SizedBox(height: 12), finishedProductField])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: wasteField),
            const SizedBox(width: 12),
            Expanded(child: finishedProductField),
          ]);
  }

  Widget _wasteInputCard({required String label, required TextEditingController ctrl, required bool locked}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCrmBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context).translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmTextSub)),
        const SizedBox(height: 10),
        _numberCell(ctrl, locked),
      ]),
    );
  }

  Widget _numberCell(TextEditingController ctrl, bool locked) {
    if (locked) {
      return Text(ctrl.text.trim().isEmpty ? '0' : ctrl.text, style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText));
    }
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      style: tInter(fontSize: 16, fontWeight: FontWeight.w700, color: kCrmText),
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: tInter(fontSize: 16, color: const Color(0xFFCBD5E1)),
        filled: true,
        fillColor: kCrmBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kRecuperableColor, width: 1.5)),
      ),
    );
  }

  // §MODIFICATION — AJOUT FINISHED PRODUCT : deux totaux INDÉPENDANTS —
  // "Total Waste" calculé uniquement à partir de Waste, "Total Finished
  // Product" uniquement à partir de Finished Product (jamais additionnés).
  Widget _buildTotals() {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final cards = [
      _totalCard('Total Waste', '${_totalWaste.toStringAsFixed(2)} kg', kRecuperableColor),
      _totalCard('Total Finished Product', '${_totalFinishedProduct.toStringAsFixed(2)} kg', kCrmPrimary),
    ];
    return isMobile
        ? Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
        : Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]);
  }

  Widget _totalCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context).translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmTextSub)),
        const SizedBox(height: 6),
        Text(value, style: tInter(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _buildButtons() {
    if (_fiche != null && !_fiche!.isOpen) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kRecuperableClosed.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: kRecuperableClosed),
          const SizedBox(width: 10),
          Expanded(child: Text(AppLocalizations.of(context).translate('Cette fiche est terminée — lecture seule.'), style: tInter(fontSize: 12.5, color: kCrmTextSub))),
        ]),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;
    final saveBtn = IndustrialBigButton(
      label: AppLocalizations.of(context).translate(_saving ? 'Enregistrement…' : 'Enregistrer'),
      icon: Icons.save_outlined,
      color: kRecuperableColor,
      outlined: true,
      onTap: (_saving || _terminating) ? null : () => _save(),
    );
    final finishBtn = IndustrialBigButton(
      label: AppLocalizations.of(context).translate(_terminating ? 'Finalisation…' : 'Terminer'),
      icon: Icons.check_circle_outline_rounded,
      color: kRecuperableColor,
      onTap: (_saving || _terminating) ? null : _terminer,
    );

    return isMobile
        ? Column(children: [saveBtn, const SizedBox(height: 10), finishBtn])
        : Row(children: [Expanded(child: saveBtn), const SizedBox(width: 12), Expanded(child: finishBtn)]);
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : kCrmBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : kCrmBorder, width: selected ? 1.6 : 1),
        ),
        child: Text(label,
            style: tInter(fontSize: 12.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? color : kCrmText)),
      ),
    );
  }
}
