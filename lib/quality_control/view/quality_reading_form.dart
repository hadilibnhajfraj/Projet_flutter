// lib/quality_control/view/quality_reading_form.dart
//
// CONTRÔLE QUALITÉ — formulaire des paramètres d'UN prélèvement.
//
// UN SEUL composant pour tous les prélèvements d'une fiche : changer d'étape =
// charger un autre prélèvement dans le même contrôleur (`load`), jamais un
// second formulaire. Les TextEditingController sont créés UNE fois par
// paramètre (`configure`) et seulement synchronisés au chargement — jamais
// recréés ni réinitialisés dans build().
//
// Tous les prélèvements ont les MÊMES paramètres (catégories A, B, C… servies par
// le backend) ; leurs valeurs sont indépendantes. La valeur du prélèvement
// précédent est proposée (« Reprendre ») mais jamais recopiée d'office.

import 'package:flutter/material.dart' hide Text;

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/reports/view/report_widgets.dart';
import '../model/quality_control_model.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

/// Valeurs d'un paramètre (saisies ou enregistrées).
typedef QcParamValues = ({String value, String status, String remark});

const QcParamValues _blank = (value: '', status: 'NON_CONTROLE', remark: '');

/// État de saisie du prélèvement affiché : controllers persistants, statuts,
/// valeurs enregistrées (référence du diff), résultat demandé.
class QualityReadingFormController extends ChangeNotifier {
  List<QualityParameter> _params = const [];
  final Map<String, TextEditingController> _values = {};
  final Map<String, TextEditingController> _remarks = {};
  final Map<String, String> _statuses = {};
  final Map<String, QcParamValues> _saved = {};
  final Set<String> _remarkOpen = {};

  /// Résultat choisi par le contrôleur (un paramètre non conforme impose
  /// NON_CONFORME — voir [result]).
  String requestedResult = 'CONFORME';

  /// Erreurs signalées sur les champs (après une tentative de validation).
  bool showErrors = false;
  Set<String> errorKeys = {};

  List<QualityParameter> get parameters => _params;

  /// Paramètres du formulaire : un controller par paramètre, créé une fois.
  void configure(List<QualityParameter> params) {
    _params = [...params]..sort((a, b) => a.position.compareTo(b.position));
    for (final p in _params) {
      _values[p.key] ??= TextEditingController();
      _remarks[p.key] ??= TextEditingController();
      _statuses[p.key] ??= 'NON_CONTROLE';
      _saved[p.key] ??= _blank;
    }
  }

  /// Charge un prélèvement ENREGISTRÉ (ses valeurs, statuts, remarques) ou un
  /// prélèvement vierge (`null`). Les valeurs d'un autre prélèvement ne sont jamais
  /// conservées.
  void load(QualityReading? reading) {
    final byKey = {for (final i in reading?.items ?? const <QualityControlItem>[]) i.parameterKey: i};
    _remarkOpen.clear();
    for (final p in _params) {
      final i = byKey[p.key];
      final v = i == null ? _blank : (value: i.value ?? '', status: i.status, remark: i.remark ?? '');
      _saved[p.key] = v;
      _values[p.key]!.text = v.value;
      _remarks[p.key]!.text = v.remark;
      _statuses[p.key] = v.status;
    }
    requestedResult = reading?.status == 'NON_CONFORME' ? 'NON_CONFORME' : 'CONFORME';
    showErrors = false;
    errorKeys = {};
    notifyListeners();
  }

  TextEditingController valueController(String key) => _values[key]!;
  TextEditingController remarkController(String key) => _remarks[key]!;
  String status(String key) => _statuses[key] ?? 'NON_CONTROLE';

  QcParamValues current(String key) => (value: _values[key]!.text.trim(), status: status(key), remark: _remarks[key]!.text.trim());

  void setStatus(String key, String value) {
    _statuses[key] = value;
    if (anyNonConforme) requestedResult = 'NON_CONFORME';
    notifyListeners();
  }

  /// Valeur choisie par un bouton (paramètre à choix) ou reprise du prélèvement
  /// précédent. `tone` : statut PROPOSÉ si aucun n'est encore choisi.
  void setValue(String key, String value, {String? tone}) {
    _values[key]!.text = value;
    if (status(key) == 'NON_CONTROLE' && value.isNotEmpty) {
      if (tone == 'ok') _statuses[key] = 'CONFORME';
      if (tone == 'nok') _statuses[key] = 'NON_CONFORME';
    }
    if (anyNonConforme) requestedResult = 'NON_CONFORME';
    notifyListeners();
  }

  /// Contrôle binaire (kind `conformity`) : aucune valeur saisie — la valeur
  /// suit le statut choisi (même règle que le backend).
  void setConformity(String key, String status) {
    _statuses[key] = status;
    _values[key]!.text = switch (status) { 'CONFORME' => 'Conforme', 'NON_CONFORME' => 'Non conforme', _ => '' };
    if (anyNonConforme) requestedResult = 'NON_CONFORME';
    notifyListeners();
  }

  void setResult(String value) {
    requestedResult = value;
    notifyListeners();
  }

  bool isRemarkOpen(String key) => _remarkOpen.contains(key);

  void openRemark(String key) {
    _remarkOpen.add(key);
    notifyListeners();
  }

  /// Saisie clavier : les compteurs et repères « modifié » se mettent à jour.
  void touch() => notifyListeners();

  bool get anyNonConforme => _statuses.values.contains('NON_CONFORME');
  int get controlledCount => _params.where((p) => status(p.key) != 'NON_CONTROLE').length;
  int get nonConformCount => _params.where((p) => status(p.key) == 'NON_CONFORME').length;
  String get result => anyNonConforme ? 'NON_CONFORME' : requestedResult;

  /// Paramètres MODIFIÉS depuis le chargement (un paramètre inchangé n'est
  /// pas renvoyé ; un prélèvement vierge n'envoie que ce qui a été saisi).
  List<Map<String, dynamic>> payload() => [
        for (final p in _params)
          if (current(p.key) != _saved[p.key])
            {'parameterKey': p.key, 'value': current(p.key).value, 'status': current(p.key).status, 'remark': current(p.key).remark},
      ];

  bool get hasChanges => _params.any((p) => current(p.key) != _saved[p.key]);

  // Mêmes règles que le backend (collectValidationErrors) — affichées avant
  // l'envoi ; le serveur reste l'autorité.
  String? errorOf(QualityParameter p) {
    final v = current(p.key);
    if (v.status != 'NON_CONTROLE' && v.value.isEmpty) return 'Valeur obligatoire';
    // Non conforme : remarque RECOMMANDÉE (champ ouvert), jamais bloquante.
    if (v.status == 'NON_CONTROLE' && v.value.isNotEmpty) return 'Indiquer Conforme ou Non conforme';
    return null;
  }

  List<String> errors() => [
        if (controlledCount == 0) 'Au moins un paramètre doit être contrôlé (Conforme ou Non conforme).',
        for (final p in _params)
          if (errorOf(p) != null) '${p.label} : ${errorOf(p)}',
      ];

  void flagErrors({Set<String> keys = const {}}) {
    showErrors = true;
    errorKeys = keys;
    notifyListeners();
  }

  bool isFlagged(QualityParameter p) => errorOf(p) != null && (showErrors || errorKeys.contains(p.key));

  @override
  void dispose() {
    for (final c in [..._values.values, ..._remarks.values]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Sous-titre d'une catégorie UNIQUE de prélèvement (sans lettre).
const _sectionSubtitles = <String, String>{
  'controle_promesh_4': 'Paramètres spécifiques de la machine',
};

const _sectionIcons = <String, IconData>{
  'ligne': Icons.linear_scale_rounded,
  'chauffage': Icons.local_fire_department_outlined,
  'polymerisation': Icons.science_outlined,
  'barre': Icons.straighten_rounded,
  'coupe': Icons.content_cut_rounded,
  'machine': kMachineIcon,
  'controle_machine': Icons.settings_rounded,
  'controle_promesh_4': Icons.settings_rounded,
  'physique': Icons.grid_4x4_rounded,
};

/// Paramètres du prélèvement chargé dans [controller], par catégorie (A, B, C…),
/// puis résultat du prélèvement.
class QualityReadingForm extends StatelessWidget {
  final QualityReadingFormController controller;
  final QualityConfig config;

  /// Ligne de la fiche : seuls SES contrôles sont affichés (PROMESH ne voit
  /// jamais les contrôles des barres PROBAR).
  final String productionType;

  /// Heure du prélèvement affiché (rappel dans les titres).
  final String readingTime;

  /// Prélèvement validé / consultation : aucune saisie possible.
  final bool locked;
  final bool busy;

  /// Prélèvement PRÉCÉDENT de la fiche : ses valeurs sont proposées (action
  /// volontaire « Reprendre »), jamais recopiées automatiquement.
  final QualityReading? previous;

  /// Le prélèvement affiché est-il validé (résultat figé) ?
  final bool validated;

  const QualityReadingForm({
    super.key,
    required this.controller,
    required this.config,
    required this.productionType,
    required this.readingTime,
    this.locked = false,
    this.busy = false,
    this.previous,
    this.validated = false,
  });

  bool get _editable => !locked && !busy;

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        var letter = 0;
        final sections = config.visibleSectionsFor(productionType);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // PROBAR : une seule section « Contrôle qualité de la machine » (les catégories
          // deviennent des sous-titres). PROMESH : une seule catégorie, « Contrôle
          // Machine » — sans lettre. Sinon : catégories A, B, C…
          if (productionType.toUpperCase() == 'PROBAR')
            _machineQualitySection(sections)
          else if (sections.length == 1)
            _section(sections.single, null)
          else
            for (final s in sections) _section(s, String.fromCharCode(65 + letter++)),
          _resultSection(),
        ]);
      },
    );
  }

  /// Compteur d'une section : paramètres contrôlés / total, et non-conformités.
  Widget _counter(List<QualityParameter> params) {
    final controlled = params.where((p) => controller.status(p.key) != 'NON_CONTROLE').length;
    final nc = params.where((p) => controller.status(p.key) == 'NON_CONFORME').length;
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$controlled / ${params.length} contrôlé(s)', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      if (nc > 0) TextSpan(text: '  ·  $nc NC', style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kQcNonConformeText)),
    ]));
  }

  /// PROBAR — section unique « Contrôle qualité de la machine » : tous les contrôles du
  /// prélèvement, un seul compteur ; les catégories ne sont plus que des
  /// sous-titres visuels.
  Widget _machineQualitySection(List<QualitySection> sections) {
    final groups = [for (final s in sections) (section: s, params: config.parametersOf(s.key, productionType: productionType))];
    return QcSection(
      key: const ValueKey('qc-machine-quality-section'),
      icon: Icons.settings_rounded,
      title: 'Contrôle qualité de la machine',
      subtitle: 'Contrôle des paramètres de fonctionnement et de réglage de la machine',
      trailing: _counter([for (final g in groups) ...g.params]),
      children: [
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          Row(key: ValueKey('qc-machine-quality-group-${g.section.key}'), children: [
            Icon(_sectionIcons[g.section.key] ?? Icons.tune_rounded, size: 14, color: kCrmTextSub),
            const SizedBox(width: 6),
            Text(g.section.label.toUpperCase(), style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.8)),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1, color: kCrmBorder)),
          ]),
          const SizedBox(height: 10),
          qcGrid(columns: qcColumnsFor(240, max: 3), [for (final p in g.params) _paramCard(p)]),
        ],
      ],
    );
  }

  /// Suites de paramètres consécutifs partageant le même sous-groupe (`null` :
  /// hors groupe), dans l'ordre reçu.
  static List<({String? group, List<QualityParameter> params})> _runs(List<QualityParameter> params) {
    final runs = <({String? group, List<QualityParameter> params})>[];
    for (final p in params) {
      if (runs.isNotEmpty && runs.last.group == p.group) {
        runs.last.params.add(p);
      } else {
        runs.add((group: p.group, params: [p]));
      }
    }
    return runs;
  }

  /// Catégorie de paramètres (A, B, C…) ; sans lettre quand elle est la seule
  /// catégorie du prélèvement.
  Widget _section(QualitySection section, String? letter) {
    final params = config.parametersOf(section.key, productionType: productionType);
    return QcSection(
      key: letter == null ? ValueKey('qc-reading-section-${section.key}') : null,
      number: letter,
      icon: _sectionIcons[section.key] ?? Icons.tune_rounded,
      title: section.label,
      subtitle: letter == null ? (_sectionSubtitles[section.key] ?? 'Paramètres liés au prélèvement') : 'Prélèvement de $readingTime',
      trailing: _counter(params),
      children: [
        // Dans l'ordre du backend : les paramètres consécutifs d'un même
        // sous-groupe (ex. « Température machine 1 » : zone 1 / zone 2) sont
        // réunis sous un sous-titre ; les autres forment une grille simple.
        for (final (i, run) in _runs(params).indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          if (run.group != null) ...[
            Row(key: ValueKey('qc-param-group-${run.group}'), children: [
              Text(run.group!, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.8)),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1, color: kCrmBorder)),
            ]),
            const SizedBox(height: 10),
          ],
          qcGrid(columns: qcColumnsFor(240, max: 3), [for (final p in run.params) _paramCard(p)]),
        ],
      ],
    );
  }

  // ── Carte de paramètre ─────────────────────────────────────────────────

  Widget _paramCard(QualityParameter p) {
    final c = controller;
    final status = c.status(p.key);
    final nc = status == 'NON_CONFORME';
    final accent = qualityStatusColor(status);
    final flagged = c.isFlagged(p);
    final remarkVisible = c.isRemarkOpen(p.key) || c.remarkController(p.key).text.trim().isNotEmpty || nc;
    final iconColor = status == 'NON_CONTROLE' ? kCrmTextSub : accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: nc ? kCrmDanger.withValues(alpha: 0.04) : kCrmSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flagged || nc ? kCrmDanger.withValues(alpha: 0.5) : kCrmBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(qualityParamIcon(p.key), size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            // Dans un sous-groupe : libellé court du champ (« BAIN 1 »).
            child: Text(p.shortLabel ?? p.label,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmText, letterSpacing: 0.2)),
          ),
          if (status != 'NON_CONTROLE') Icon(nc ? Icons.cancel_rounded : Icons.check_circle_rounded, size: 16, color: accent),
          if (!locked && !remarkVisible)
            IconButton(
              tooltip: qcT('Ajouter une remarque'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => c.openRemark(p.key),
              icon: const Icon(Icons.notes_rounded, size: 16, color: kCrmTextSub),
            ),
        ]),
        const SizedBox(height: 8),
        // Contrôle binaire : ni valeur ni « Non contrôlé » — Conforme / Non conforme.
        if (p.kind == 'conformity')
          _conformityChoice(p.key, status)
        else ...[
          _valueInput(p),
          _previousValue(p),
          const SizedBox(height: 8),
          _statusToggle(p.key, status),
        ],
        if (flagged)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(c.errorOf(p)!, style: tInter(fontSize: 11, color: kCrmDanger)),
          ),
        if (remarkVisible) ...[
          const SizedBox(height: 8),
          TextField(
            controller: c.remarkController(p.key),
            enabled: _editable,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => c.touch(),
            style: tInter(fontSize: 12.5, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.notes_rounded, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              hintText: qcT(nc ? 'Expliquer l\'anomalie (recommandé)' : 'Remarque'),
              hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
              filled: true,
              fillColor: kCrmBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmBorder)),
            ),
          ),
        ],
      ]),
    );
  }

  /// Valeur du prélèvement précédent : rappel + reprise VOLONTAIRE. Rien n'est
  /// recopié sans ce clic ; le statut reste à choisir.
  Widget _previousValue(QualityParameter p) {
    final value = previous?.valueOf(p.key) ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    final same = controller.valueController(p.key).text.trim() == value;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.history_rounded, size: 13, color: kCrmTextSub),
        const SizedBox(width: 4),
        Expanded(
          child: Text('Précédent (${previous!.readingTime}) : $value${p.unit == null || p.unit!.isEmpty ? '' : ' ${p.unit}'}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
        ),
        if (_editable && !same)
          InkWell(
            key: ValueKey('qc-reuse-${p.key}'),
            onTap: () => controller.setValue(p.key, value),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('Reprendre', style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kQualityControlColor)),
            ),
          ),
      ]),
    );
  }

  Widget _valueInput(QualityParameter p) {
    final ctrl = controller.valueController(p.key);
    if (p.kind == 'choice' && p.options.isNotEmpty) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in p.options)
          _optionPill(
            label: o.label,
            color: qualityToneColor(o.tone),
            selected: ctrl.text == o.value,
            // Statut PROPOSÉ (toujours modifiable) si pas encore choisi.
            onTap: _editable ? () => controller.setValue(p.key, ctrl.text == o.value ? '' : o.value, tone: o.tone) : null,
          ),
      ]);
    }
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));
    return TextField(
      key: ValueKey('qc-value-${p.key}'),
      controller: ctrl,
      enabled: _editable,
      // Saisie libre même pour une mesure ("> 6", "180 / 190") : la valeur
      // est enregistrée telle quelle.
      keyboardType: TextInputType.text,
      onChanged: (_) => controller.touch(),
      style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true,
        fillColor: kCrmBg,
        hintText: qcT(p.hint ?? 'Valeur'),
        hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
        // Unité : uniquement celle fournie par le backend.
        suffixText: p.unit != null && p.unit!.isNotEmpty ? p.unit : null,
        suffixStyle: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub),
        border: border(kCrmBorder),
        enabledBorder: border(kCrmBorder),
        focusedBorder: border(kQualityControlColor, 1.5),
      ),
    );
  }

  Widget _optionPill({required String label, required Color color, required bool selected, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : kCrmBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : kCrmBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 15, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : kCrmText)),
        ]),
      ),
    );
  }

  /// Deux choix exclusifs : Conforme / Non conforme (un second appui retire le choix).
  Widget _conformityChoice(String key, String status) {
    Widget pill(String value, String label) => KeyedSubtree(
          key: ValueKey('qc-conformity-$key-$value'),
          child: _optionPill(
            label: label,
            color: qualityStatusColor(value),
            selected: status == value,
            onTap: _editable ? () => controller.setConformity(key, status == value ? 'NON_CONTROLE' : value) : null,
          ),
        );
    return Wrap(spacing: 8, runSpacing: 8, children: [pill('CONFORME', 'Conforme'), pill('NON_CONFORME', 'Non conforme')]);
  }

  Widget _statusToggle(String key, String status) {
    Widget seg(String value, String label, IconData icon) {
      final selected = status == value;
      final color = qualityStatusColor(value == 'NON_CONTROLE' ? '' : value);
      return Expanded(
        child: InkWell(
          onTap: _editable ? () => controller.setStatus(key, value) : null,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? color : Colors.transparent),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: selected ? color : kCrmTextSub),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? color : kCrmTextSub)),
              ),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
      child: Row(children: [
        seg('CONFORME', 'Conforme', Icons.check_circle_outline_rounded),
        seg('NON_CONFORME', 'Non conforme', Icons.cancel_outlined),
        seg('NON_CONTROLE', 'Non contrôlé', Icons.remove_circle_outline_rounded),
      ]),
    );
  }

  // ── Résultat du prélèvement ─────────────────────────────────────────────────

  Widget _resultSection() {
    final c = controller;
    final ncParams = [
      for (final p in c.parameters)
        if (c.status(p.key) == 'NON_CONFORME') p.label,
    ];
    Widget choice(String value, String label, IconData icon) {
      final selected = c.result == value;
      final color = qualityStatusColor(value);
      final disabled = !_editable || (c.anyNonConforme && value == 'CONFORME');
      return ChoiceChip(
        avatar: Icon(icon, size: 18, color: selected ? color : kCrmTextSub),
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.16),
        labelStyle: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? color : kCrmText),
        onSelected: disabled ? null : (_) => c.setResult(value),
      );
    }

    return QcSection(
      icon: Icons.check_circle_outline_rounded,
      title: 'Résultat du prélèvement',
      subtitle: 'Prélèvement de $readingTime · ${c.controlledCount} / ${c.parameters.length} paramètres contrôlés · ${ncParams.length} non conforme(s)',
      children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          choice('CONFORME', 'Conforme', Icons.check_circle_rounded),
          choice('NON_CONFORME', 'Non conforme', Icons.cancel_rounded),
          if (!validated)
            Chip(
              avatar: const Icon(Icons.pending_outlined, size: 18, color: kCrmWarning),
              label: Text('À vérifier — non validé', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmWarning)),
              backgroundColor: kCrmWarning.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
        ]),
        if (c.anyNonConforme) ...[
          const SizedBox(height: 10),
          RpNote(qcT('Un paramètre non conforme impose le résultat NON CONFORME.'), icon: Icons.info_outline_rounded),
          Text('Paramètre(s) non conforme(s) : ${ncParams.join(', ')}',
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmDanger)),
        ],
      ],
    );
  }
}
