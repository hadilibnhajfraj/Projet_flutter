// lib/forms/raw_material_request/raw_material_request_form.dart
//
// Formulaire « Demande de matières premières » (5 matières),
// partagé par la popup (raw_material_request_dialog.dart) et par la page
// dédiée (raw_material_request_screen.dart) — une seule implémentation des
// champs, des validations et de l'enregistrement.
//
// Présentation calquée sur le document papier : tableau titré
// « DEMANDE DE MATIÈRES PREMIÈRES », 7 colonnes (en-têtes bleu foncé),
// 5 lignes (ISO → FIBRE), puis la zone « Validation ». Une ligne laissée
// entièrement vide = matière non demandée ; une ligne commencée doit avoir
// ses 3 quantités ; au moins une matière par demande.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import 'raw_material_request_service.dart';

/// Renvoie la demande enregistrée (réponse du backend), ou null.
typedef RawMaterialSubmit = Future<Map<String, dynamic>?> Function(String clientRequestId, List<RawMaterialLine> lines);

/// Les 5 matières, dans cet ordre (code backend, libellé affiché —
/// fixe, jamais traduit). Toujours affichées, même sans donnée enregistrée.
const kRawMaterials = [
  ('ISO', 'ISO'),
  ('RESINE', 'RESINE'),
  ('ACCELERATEUR', 'ACCELERATEUR'),
  ('GRAIN_PLASTIQUE', 'GRAIN PLASTIQUE'),
  ('FIBRE', 'FIBRE'),
];
const kRawMaterialUnit = 'KG';

const _kMaxQuantity = 10000000;
final _quantityPattern = RegExp(r'^\d+([.,]\d{1,3})?$');

/// Traduction (assets/lang, clés françaises) ; renvoie la clé si les
/// traductions ne sont pas chargées.
String rmT(BuildContext context, String key) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)?.translate(key) ?? key;

/// Validation d'une quantité saisie (positive ou nulle, 3 décimales max).
/// Renvoie une clé de traduction (française).
String? validateRawMaterialQuantity(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Champ obligatoire';
  if (v.startsWith('-')) return 'La quantité ne peut pas être négative';
  if (!_quantityPattern.hasMatch(v)) return 'Nombre invalide (ex. 12,5)';
  if (parseRawMaterialQuantity(v)! > _kMaxQuantity) return 'Valeur trop élevée';
  return null;
}

double? parseRawMaterialQuantity(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

/// Quantité enregistrée → texte du champ (« 120 », « 12,5 ») ; vide si absente.
String formatRawMaterialQuantity(Object? value) {
  final n = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (n == null) return '';
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString().replaceAll('.', ',');
}

Color rawMaterialAccent(String? module) => switch (module) {
      'probar' => kProbarColor,
      'promesh' => kPromeshColor,
      'melange' => kMelangeColor,
      _ => kCrmPrimary,
    };

String _moduleLabel(String module) => switch (module) {
      'probar' => 'PROBAR',
      'melange' => 'MÉLANGE',
      _ => 'PROMESH',
    };

/// Heure d'échéance en heure de Tunis (UTC+1, sans changement d'heure) —
/// celle du serveur, jamais l'heure locale du navigateur.
String rawMaterialDeadlineLabel(DateTime deadlineAt) {
  final t = deadlineAt.toUtc().add(const Duration(hours: 1));
  return t.minute == 0 ? '${t.hour} h' : '${t.hour} h ${t.minute.toString().padLeft(2, '0')}';
}

/// Échéance de validation (« Validation requise avant vendredi à 14 h »),
/// échéance dépassée, et motif d'un rejet à corriger.
class RawMaterialDeadlineNotice extends StatelessWidget {
  final DateTime? deadlineAt;
  final bool deadlinePassed;
  final bool resubmission;
  final String? rejectionComment;

  const RawMaterialDeadlineNotice({
    super.key,
    this.deadlineAt,
    this.deadlinePassed = false,
    this.resubmission = false,
    this.rejectionComment,
  });

  Widget _box(Key key, IconData icon, Color color, List<String> lines) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, l) in lines.indexed)
                Text(l, style: TextStyle(fontSize: 13, color: kCrmText, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    String t(String k) => rmT(context, k);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (deadlineAt != null)
        _box(
          const ValueKey('raw-material-deadline'),
          deadlinePassed ? Icons.warning_amber_rounded : Icons.schedule_rounded,
          deadlinePassed ? kCrmDanger : kCrmWarning,
          [
            '${t('Validation requise avant vendredi à')} ${rawMaterialDeadlineLabel(deadlineAt!)}',
            if (deadlinePassed) t('Échéance dépassée : la demande sera signalée en retard au responsable logistique achats.'),
          ],
        ),
      if (resubmission)
        _box(const ValueKey('raw-material-rejection'), Icons.report_gmailerrorred_rounded, kCrmDanger, [
          t('Demande rejetée par le responsable logistique achats'),
          if ((rejectionComment ?? '').isNotEmpty) '« $rejectionComment »',
          t('Corrigez les valeurs puis soumettez de nouveau la demande.'),
        ]),
    ]);
  }
}

/// En-tête commun : icône, titre, sous-titre et contexte (module, machine,
/// poste, date).
class RawMaterialRequestHeader extends StatelessWidget {
  final String? module;
  final String? machine;
  final String poste;
  final String subtitle;
  final Widget? trailing;

  const RawMaterialRequestHeader({
    super.key,
    this.module,
    this.machine,
    required this.poste,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = rawMaterialAccent(module);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.inventory_2_rounded, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rmT(context, 'Demande de matières premières'),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 4),
              Text(rmT(context, subtitle), style: const TextStyle(fontSize: 13, color: kCrmTextSub)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (module != null) _chip(Icons.factory_rounded, _moduleLabel(module!)),
                if (machine != null) _chip(Icons.precision_manufacturing_rounded, '${rmT(context, 'Machine')} $machine'),
                _chip(Icons.wb_sunny_rounded, rmT(context, poste == 'matin' ? 'Poste Matin' : 'Poste Soir')),
                _chip(Icons.calendar_today_rounded, DateFormat('dd/MM/yyyy').format(DateTime.now())),
              ]),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
      );
}

// ── Style « document » du tableau ──────────────────────────────────────────
const kRawMaterialHeaderColor = Color(0xFF1F3A5F); // bleu foncé des en-têtes
const _kGrid = Color(0xFF94A3B8); // bordures fines
const _kTitleBg = Color(0xFFE8EEF6);

/// 7 colonnes : (clé de traduction, largeur minimale). Au-delà de la somme
/// des minimums, les colonnes s'élargissent proportionnellement ; en deçà
/// (petit écran), le tableau défile horizontalement sans se déformer. Les
/// minimums tiennent dans la popup (les 7 colonnes restent visibles) ; un
/// intitulé long passe sur deux lignes plutôt que d'être tronqué.
const _kColumns = [
  ('Matière', 130.0),
  ('Référence', 130.0),
  ('Lot', 110.0),
  ('Quantité disponible', 125.0),
  ('Besoin production', 125.0),
  ('Quantité demandée', 125.0),
  ('Unité', 70.0),
];
final _kMinTableWidth = _kColumns.fold<double>(0, (s, c) => s + c.$2);

/// Tableau des 5 matières + zone « Validation ». N'appelle [onSaved] qu'après
/// confirmation de l'enregistrement par le backend ; en cas d'échec les
/// valeurs saisies restent dans le formulaire et l'erreur est affichée.
class RawMaterialRequestForm extends StatefulWidget {
  final String? module;
  final String? machine;
  final String poste;

  /// Injection pour les tests ; par défaut, POST /raw-material-requests.
  final RawMaterialSubmit? submit;
  final ValueChanged<Map<String, dynamic>?> onSaved;
  final VoidCallback onCancel;
  final ValueChanged<bool>? onSubmittingChanged;

  /// Lignes d'une demande déjà enregistrée (`items` du backend) : les champs
  /// sont pré-remplis avec ces valeurs, jamais avec des zéros par défaut.
  final List<dynamic>? initialItems;

  /// Consultation d'une demande enregistrée : aucun champ modifiable, pas
  /// de zone Validation.
  final bool readOnly;

  /// Popup : le tableau défile verticalement, la zone Validation reste
  /// visible en bas (le parent doit borner la hauteur).
  final bool pinValidation;

  /// Clé de traduction du texte de la zone « Validation ».
  final String validationText;

  const RawMaterialRequestForm({
    super.key,
    this.module,
    this.machine,
    required this.poste,
    this.submit,
    required this.onSaved,
    required this.onCancel,
    this.onSubmittingChanged,
    this.initialItems,
    this.readOnly = false,
    this.pinValidation = false,
    this.validationText = 'La demande est enregistrée à votre nom avec la date et le poste, '
        'puis transmise au responsable logistique achats pour validation.',
  });

  @override
  State<RawMaterialRequestForm> createState() => _RawMaterialRequestFormState();
}

class _LineControllers {
  final reference = TextEditingController();
  final lot = TextEditingController();
  final disponible = TextEditingController();
  final besoin = TextEditingController();
  final demandee = TextEditingController();

  void dispose() {
    for (final c in [reference, lot, disponible, besoin, demandee]) {
      c.dispose();
    }
  }
}

class _RawMaterialRequestFormState extends State<RawMaterialRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _lines = {for (final m in kRawMaterials) m.$1: _LineControllers()};
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  // Fixé une fois par ouverture : un nouvel essai après échec réutilise le
  // même identifiant, le backend ne crée donc jamais de doublon.
  final _clientRequestId = const Uuid().v4();

  bool _submitting = false;
  bool _attempted = false;
  String? _error;

  Color get _accent => rawMaterialAccent(widget.module);
  String _t(String key) => rmT(context, key);

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialItems ?? const []) {
      if (item is! Map) continue;
      final c = _lines[item['material']];
      if (c == null) continue; // matière hors modèle : ignorée
      c.reference.text = item['reference']?.toString() ?? '';
      c.lot.text = item['lot']?.toString() ?? '';
      c.disponible.text = formatRawMaterialQuantity(item['quantiteDisponible']);
      c.besoin.text = formatRawMaterialQuantity(item['besoinProduction']);
      c.demandee.text = formatRawMaterialQuantity(item['quantiteDemandee']);
    }
  }

  @override
  void dispose() {
    for (final l in _lines.values) {
      l.dispose();
    }
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  void _setSubmitting(bool value) {
    setState(() => _submitting = value);
    widget.onSubmittingChanged?.call(value);
  }

  // Ligne commencée : au moins un de ses champs renseigné.
  bool _rowTouched(String code) {
    final c = _lines[code]!;
    return [c.reference, c.lot, c.disponible, c.besoin, c.demandee].any((t) => t.text.trim().isNotEmpty);
  }

  String? _validateQty(String code, String? value) {
    if ((value ?? '').trim().isEmpty && !_rowTouched(code)) return null; // matière non demandée
    final error = validateRawMaterialQuantity(value);
    return error == null ? null : _t(error);
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _attempted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = _t('Corrigez les champs signalés en rouge avant de valider.'));
      return;
    }
    final requested = [for (final (code, _) in kRawMaterials) if (_rowTouched(code)) code];
    if (requested.isEmpty) {
      setState(() => _error = _t('Renseignez au moins une matière avant de valider.'));
      return;
    }
    final lines = [
      for (final code in requested)
        RawMaterialLine(
          material: code,
          reference: _lines[code]!.reference.text,
          lot: _lines[code]!.lot.text,
          quantiteDisponible: parseRawMaterialQuantity(_lines[code]!.disponible.text)!,
          besoinProduction: parseRawMaterialQuantity(_lines[code]!.besoin.text)!,
          quantiteDemandee: parseRawMaterialQuantity(_lines[code]!.demandee.text)!,
        ),
    ];

    _error = null;
    _setSubmitting(true);
    try {
      final submit = widget.submit ??
          (id, l) => RawMaterialRequestService.instance
              .create(clientRequestId: id, module: widget.module, machine: widget.machine, poste: widget.poste, lines: l);
      final saved = await submit(_clientRequestId, lines);
      if (!mounted) return;
      _setSubmitting(false);
      widget.onSaved(saved);
    } catch (e) {
      // Les valeurs saisies restent dans le formulaire ; rien n'est considéré enregistré.
      if (!mounted) return;
      setState(() => _error = "${_t("La demande n'a pas pu être enregistrée")} : ${RawMaterialRequestService.friendlyError(e)}");
      _setSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = _scrollableTable();
    return Form(
      key: _formKey,
      autovalidateMode: _attempted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.pinValidation && !widget.readOnly)
            // Barre visible : signale les lignes sous la zone affichée.
            Flexible(
              child: Scrollbar(
                controller: _vertical,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('raw-material-vertical-scroll'),
                  controller: _vertical,
                  child: table,
                ),
              ),
            )
          else
            table,
          if (!widget.readOnly) _validationSection(),
        ],
      ),
    );
  }

  Widget _scrollableTable() => LayoutBuilder(builder: (context, constraints) {
            final width = math.max(constraints.maxWidth, _kMinTableWidth);
            final scale = width / _kMinTableWidth;
            return Scrollbar(
              controller: _horizontal,
              thumbVisibility: width > constraints.maxWidth,
              child: SingleChildScrollView(
                key: const ValueKey('raw-material-table-scroll'),
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: width, child: _table(scale)),
              ),
            );
          });

  Widget _table(double scale) {
    const side = BorderSide(color: _kGrid, width: 0.8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: _kTitleBg, border: Border.all(color: _kGrid, width: 0.8)),
          child: Text(
            _t('DEMANDE DE MATIÈRES PREMIÈRES'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: kRawMaterialHeaderColor),
          ),
        ),
        Table(
          key: const ValueKey('raw-material-table'),
          border: const TableBorder(left: side, right: side, bottom: side, horizontalInside: side, verticalInside: side),
          columnWidths: {
            for (var i = 0; i < _kColumns.length; i++) i: FixedColumnWidth(_kColumns[i].$2 * scale),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: kRawMaterialHeaderColor),
              children: [
                for (final (key, _) in _kColumns)
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      child: Text(
                        _t(key),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
            for (final (code, label) in kRawMaterials) _row(code, label),
          ],
        ),
      ],
    );
  }

  TableRow _row(String code, String label) {
    final c = _lines[code]!;
    Widget cell(Widget child) => Padding(padding: const EdgeInsets.all(4), child: child);
    Widget centered(Widget child) => TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Center(child: child)),
        );
    return TableRow(
      key: ValueKey('raw-material-row-$code'),
      decoration: const BoxDecoration(color: kCrmSurface),
      children: [
        centered(Text(label,
            key: ValueKey('raw-material-label-$code'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kCrmText))),
        cell(_textField(c.reference, key: 'ref-$code')),
        cell(_textField(c.lot, key: 'lot-$code')),
        cell(_qtyField(c.disponible, code, key: 'dispo-$code')),
        cell(_qtyField(c.besoin, code, key: 'besoin-$code')),
        cell(_qtyField(c.demandee, code, key: 'demandee-$code')),
        centered(Text(kRawMaterialUnit,
            key: ValueKey('unite-$code'), style: const TextStyle(fontWeight: FontWeight.w700, color: kCrmText))),
      ],
    );
  }

  InputDecoration _decoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: kCrmTextSub),
        isDense: true,
        filled: true,
        fillColor: kCrmBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kCrmBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kCrmBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _accent, width: 1.6)),
        errorMaxLines: 3,
        errorStyle: const TextStyle(fontSize: 11),
      );

  Widget _textField(TextEditingController controller, {required String key}) => TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_submitting,
        readOnly: widget.readOnly,
        maxLength: 100,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        style: const TextStyle(fontSize: 13),
        decoration: _decoration(hint: widget.readOnly ? null : _t('Facultatif')),
      );

  Widget _qtyField(TextEditingController controller, String code, {required String key}) => TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_submitting,
        readOnly: widget.readOnly,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 13),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        validator: (v) => _validateQty(code, v),
        // Champ vide tant que rien n'est saisi : pas de « 0 » indicatif qui
        // passerait pour une valeur.
        decoration: _decoration(),
      );

  // Ligne « Validation » sous le tableau, comme sur le document papier ;
  // pleine largeur visible (hors défilement horizontal) pour que les
  // boutons restent accessibles sur petit écran.
  Widget _validationSection() {
    return Container(
      key: const ValueKey('raw-material-validation'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: kCrmBg,
        border: Border(
          left: BorderSide(color: _kGrid, width: 0.8),
          right: BorderSide(color: _kGrid, width: 0.8),
          bottom: BorderSide(color: _kGrid, width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded, size: 18, color: kRawMaterialHeaderColor),
            const SizedBox(width: 8),
            Text(_t('Validation'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kRawMaterialHeaderColor)),
          ]),
          const SizedBox(height: 6),
          Text(_t(widget.validationText), style: const TextStyle(fontSize: 12.5, color: kCrmTextSub)),
          Text(_t('Laissez vides les lignes des matières non demandées.'),
              style: const TextStyle(fontSize: 12.5, color: kCrmTextSub)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('raw-material-error'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kCrmDanger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kCrmDanger.withValues(alpha: 0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: kCrmDanger, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _submitting ? null : widget.onCancel,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                child: Text(_t('Annuler')),
              ),
              FilledButton.icon(
                key: const ValueKey('raw-material-submit'),
                onPressed: _submitting ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: kRawMaterialHeaderColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_t(_submitting ? 'Enregistrement…' : 'Valider la demande')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
