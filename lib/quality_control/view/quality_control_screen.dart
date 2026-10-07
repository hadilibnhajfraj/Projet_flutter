// lib/quality_control/view/quality_control_screen.dart
//
// CONTRÔLE QUALITÉ — fiche qualité d'une MACHINE : un carnet de contrôle
// (ligne + machine + date + poste) qui porte PLUSIEURS prélèvements (étapes).
//
// Structure de l'écran :
//   01 Identification — ligne, machine, date, poste, contrôleur, ouverture,
//      lot et fabrication contrôlée (« FAB01 — 28/08/2026 — Ø12 », composée
//      par le serveur depuis la fiche de production : jamais saisie) ;
//   02 Prélèvements de contrôle — stepper HORIZONTAL (QualityReadingStepper) :
//      navigation entre prélèvements, sans aucun paramètre physique ;
//      Prélèvement actuel — heure, statut, résultat et ses CONTRÔLES temporels :
//      UN seul formulaire (QualityReadingForm) rechargé quand on change
//      d'étape, jamais dupliqué ; puis « Enregistrer le prélèvement » et
//      « Valider le prélèvement », juste avant les paramètres physiques ;
//   03 Paramètres physiques — niveau FICHE, indépendants du temps : saisis
//      UNE fois (propres à la ligne PROMESH / PROBAR), jamais dans un prélèvement
//      ni dupliqués par heure ; enregistrés à part des prélèvements ;
//   03 Paramètres spécifiques PROMESH (physiques + treillis GFRP, une section) — niveau
//      fiche : Géométrie — 6 paramètres (valeur, statut, remarque) ;
//   Synthèse — tous les prélèvements de la fiche, résultat global, validation.
// Le journal d'audit (ancienne / nouvelle valeur) reste enregistré par le
// backend mais n'est plus affiché dans la fiche.
// PROMESH ≠ PROBAR : chaque ligne n'affiche que SES contrôles et SES
// paramètres (configuration servie par le backend, filtrée par ligne).
// Un bandeau d'identification (ligne, machine, date, poste, lot, fabrication)
// reste visible en haut de la fiche pendant le défilement.
// Une seule étape est ouverte à la fois ; les autres restent compactes dans
// le stepper. Les actions restent visibles en bas de l'écran.
//
// - Heure d'OUVERTURE : appartient à la fiche (identification).
// - Heure du PRÉLÈVEMENT : appartient à l'étape affichée.
// Un nouveau prélèvement (« + Nouveau prélèvement » : heure proposée = dernier prélèvement
// + 3 h, modifiable) a les MÊMES paramètres que les autres, des valeurs
// vides et indépendantes ; il n'écrase jamais un prélèvement existant. Changer
// d'étape enregistre d'abord le brouillon en cours : aucune saisie perdue.
//
// La fiche de production n'est jamais demandée ni affichée : le serveur
// l'associe (ligne + machine + date de production + poste) ; l'écran n'en
// montre que le lot et l'ordre de fabrication, et signale sans bloquer
// l'absence de fiche. Paramètres, catégories, unités et choix viennent du
// backend (GET /quality-control/config). Saisie réservée au rôle
// controle_qualite ; admins en lecture seule.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_widgets.dart';
import 'quality_reading_form.dart';
import 'quality_reading_stepper.dart';
import '../quality_control_i18n.dart';

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    // Flottant, au-dessus de la barre d'actions : les boutons restent accessibles.
    SnackBar(
      content: Text(message),
      backgroundColor: error ? kCrmDanger : kCrmSuccess,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 78),
    ),
  );
}

/// Fiche de contrôle qualité.
/// - ÉDITION : `QualityControlScreen(controlId: …)` — fiche EXISTANTE,
///   chargée par son id PostgreSQL (GET /quality-control/:id) avec tous ses
///   prélèvements.
/// - CRÉATION : `QualityControlScreen.create(productionType:, machine:)` —
///   NOUVELLE fiche de la MACHINE de la page ; rien n'est écrit en base avant
///   « Enregistrer » ou « Valider » (POST unique : fiche + étape 1), puis
///   réouverture en édition.
class QualityControlScreen extends StatelessWidget {
  final String? controlId;
  final String? productionType;
  final String? machine;
  const QualityControlScreen({super.key, required String this.controlId})
      : productionType = null,
        machine = null;
  const QualityControlScreen.create({super.key, required String this.productionType, required String this.machine})
      : controlId = null;

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(child: _FicheView(controlId: controlId, productionType: productionType, machine: machine)),
    );
  }
}

class _FicheView extends StatefulWidget {
  final String? controlId;
  final String? productionType;
  final String? machine;
  const _FicheView({required this.controlId, required this.productionType, required this.machine});

  @override
  State<_FicheView> createState() => _FicheViewState();
}

class _FicheViewState extends State<_FicheView> {
  final bool _canWrite = AuthService().isControleQualite;

  /// FICHE en lecture seule : rôle sans saisie (admins) OU fiche VALIDÉE
  /// (statut réel relu en base — même règle que l'API : 403 CONTROL_LOCKED).
  bool get _readOnly => !_canWrite || (_control?.isValidated ?? false);

  /// PRÉLÈVEMENT affiché en lecture seule : fiche en lecture seule OU prélèvement
  /// VALIDÉ (403 READING_LOCKED côté API).
  bool get _readingLocked => _readOnly || (_reading?.isValidated ?? false);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  QualityControlModel? _control;
  QualityConfig _config = const QualityConfig();

  // ── Prélèvement affiché ─────────────────────────────────────────────────────
  // UN formulaire pour tous les prélèvements : `_form` garde ses controllers,
  // `_readingId` désigne le prélèvement chargé (null : étape 1 pas encore
  // enregistrée), `_readingTime` son heure (HH:mm).
  final _form = QualityReadingFormController();
  String? _readingId;
  String _readingTime = '';
  QualityReading? get _reading => _control?.reading(_readingId);

  /// Étape en cours de saisie, pas encore en base : la première d'une fiche
  /// sans prélèvement.
  bool get _pending => _control != null && _control!.readings.isEmpty;

  // ── Paramètres physiques (niveau FICHE, indépendants des prélèvements) ──────
  // Controllers PERSISTANTS (un par paramètre de la ligne, créés une fois) ;
  // `_physicalSaved` garde les valeurs ENREGISTRÉES (référence du diff).
  List<QualityParameter> _physicalParams = const [];
  final Map<String, TextEditingController> _physicalCtrls = {};
  final Map<String, String> _physicalSaved = {};

  // ── Contrôle spécifique de la ligne (PROMESH : treillis GFRP) ──────────
  // Niveau FICHE, indépendant des prélèvements ; valeur + statut + remarque par
  // paramètre. Controllers persistants, `_specSaved` = valeurs enregistrées.
  List<QualityParameter> _specificParams = const [];
  final Map<String, TextEditingController> _specValueCtrls = {};
  final Map<String, TextEditingController> _specRemarkCtrls = {};
  final Map<String, String> _specStatuses = {};
  final Map<String, QcParamValues> _specSaved = {};

  final _generalRemarkCtrl = TextEditingController();
  // Lot : saisie manuelle UNIQUEMENT quand la fiche de production ne le
  // porte pas. L'ordre de fabrication n'est jamais saisi.
  final _lotCtrl = TextEditingController();
  // Recherche automatique de la fiche de production (date de production +
  // poste) : état, lot et ordre de fabrication ; _matchSeq écarte les
  // réponses dépassées.
  QcProductionMatch? _match;
  int _matchSeq = 0;
  // En-tête modifiable : valeurs ENREGISTRÉES (référence du diff) et valeurs
  // saisies. Écrites uniquement par _applyControl (chargement / sauvegarde)
  // et par les sélecteurs — jamais dans build().
  QualityControlHeader _savedHeader = const QualityControlHeader();
  QualityControlHeader _header = const QualityControlHeader();
  // Valeurs initiales affichées (repère « modifié ») — en création, les
  // valeurs proposées ; en édition, identiques à _savedHeader.
  QualityControlHeader _baseHeader = const QualityControlHeader();

  bool get _isCreate => widget.controlId == null;
  List<String> _serverErrors = [];

  @override
  void initState() {
    super.initState();
    // Compteurs, repères « modifié » et synthèse suivent la saisie.
    _form.addListener(_onFormChanged);
    _load();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _form.removeListener(_onFormChanged);
    _form.dispose();
    for (final c in [..._physicalCtrls.values, ..._specValueCtrls.values, ..._specRemarkCtrls.values]) {
      c.dispose();
    }
    _generalRemarkCtrl.dispose();
    _lotCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _config = await QualityControlService.instance.fetchConfig();
      if (!_isCreate) {
        // ÉDITION : fiche et prélèvements relus en base par l'id de la fiche.
        _applyControl(await QualityControlService.instance.fetchById(widget.controlId!));
      } else {
        // CRÉATION : nouvelle fiche de la machine de la page.
        _applyControl(_draft());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Heure de Tunisie (UTC+1) — proposée pour l'ouverture et l'étape 1.
  static DateTime _tunisNow() => DateTime.now().toUtc().add(const Duration(hours: 1));
  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Nouvelle fiche (non enregistrée) de la MACHINE de la page : ouverture
  /// proposée = maintenant, date de production = aujourd'hui, aucun prélèvement.
  QualityControlModel _draft() {
    final type = widget.productionType!.toUpperCase();
    final machine = widget.machine!;
    final now = _tunisNow();
    return QualityControlModel(
      id: '',
      productionType: type,
      machine: machine,
      machineLabel: 'Machine $machine',
      productionDate: qcIsoFromDate(now),
      controllerEmail: AuthService().userEmail ?? '',
      status: 'EN_ATTENTE',
      controlDate: '${_two(now.day)}/${_two(now.month)}/${now.year}',
      controlTime: '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}',
      totalCount: _form.parameters.length,
    );
  }

  /// Écrit la fiche ENREGISTRÉE (identification) puis affiche un prélèvement :
  /// celui demandé (`select`, ou celui que la sauvegarde vient d'écrire),
  /// sinon le prélèvement déjà affiché, sinon le dernier brouillon, sinon le
  /// dernier prélèvement. Sans aucun prélèvement : l'étape 1, vierge, à l'heure proposée.
  void _applyControl(QualityControlModel c, {String? select}) {
    _generalRemarkCtrl.text = c.remark ?? '';
    _baseHeader = QualityControlHeader.fromControl(c);
    // Création : rien n'est encore en base → toutes les valeurs sont envoyées.
    _savedHeader = _isCreate ? const QualityControlHeader() : _baseHeader;
    _header = _baseHeader;
    _lotCtrl.text = c.lotAuto ? '' : _baseHeader.lot;
    // Le formulaire d'un prélèvement ne porte que les contrôles TEMPORELS de la
    // LIGNE de la fiche.
    _form.configure(_config.readingParametersFor(_config.lineKey(c.productionType, c.machine)));
    _syncPhysical(c);

    QualityReading? target = c.reading(select ?? c.readingId) ?? c.reading(_readingId);
    if (target == null && c.readings.isNotEmpty) {
      final drafts = c.readings.where((r) => !r.isValidated);
      target = drafts.isNotEmpty ? drafts.last : c.readings.last;
    }
    _control = c;
    _showReading(target, time: c.suggestedNextReadingTime);
    if (mounted) setState(() => _serverErrors = []);
    _lookupProduction();
  }

  /// Écrit les paramètres physiques ENREGISTRÉS de la fiche dans leurs
  /// controllers (créés une fois par paramètre de la ligne).
  void _syncPhysical(QualityControlModel c) {
    _physicalParams = _config.physicalParameters(_config.lineKey(c.productionType, c.machine));
    final byKey = {for (final i in c.physicalParameters) i.parameterKey: i};
    _physicalSaved.clear();
    for (final p in _physicalParams) {
      final value = byKey[p.key]?.value ?? '';
      _physicalSaved[p.key] = value;
      (_physicalCtrls[p.key] ??= TextEditingController()).text = value;
    }
    _syncSpecific(c);
  }

  /// Écrit le contrôle spécifique ENREGISTRÉ (treillis GFRP) dans ses
  /// controllers ; aucune donnée pour une ligne qui n'en a pas (PROBAR).
  void _syncSpecific(QualityControlModel c) {
    _specificParams = _config.specificParameters(_config.lineKey(c.productionType, c.machine));
    final byKey = {for (final i in c.specificParameters) i.parameterKey: i};
    _specSaved.clear();
    for (final p in _specificParams) {
      final i = byKey[p.key];
      final QcParamValues v = (value: i?.value ?? '', status: i?.status ?? 'NON_CONTROLE', remark: i?.remark ?? '');
      _specSaved[p.key] = v;
      (_specValueCtrls[p.key] ??= TextEditingController()).text = v.value;
      (_specRemarkCtrls[p.key] ??= TextEditingController()).text = v.remark;
      _specStatuses[p.key] = v.status;
    }
  }

  QcParamValues _specCurrent(String key) =>
      (value: _specValueCtrls[key]!.text.trim(), status: _specStatuses[key] ?? 'NON_CONTROLE', remark: _specRemarkCtrls[key]!.text.trim());

  /// Paramètres MODIFIÉS du contrôle spécifique (niveau fiche).
  List<Map<String, dynamic>> _specificPayload() => [
        for (final p in _specificParams)
          if (_specCurrent(p.key) != _specSaved[p.key])
            {'parameterKey': p.key, 'value': _specCurrent(p.key).value, 'status': _specCurrent(p.key).status, 'remark': _specCurrent(p.key).remark},
      ];

  /// Tout ce qui est modifié au niveau FICHE hors identification :
  /// paramètres physiques + contrôle spécifique.
  List<Map<String, dynamic>> _fichePayload() => [..._physicalPayload(), ..._specificPayload()];

  /// Paramètres physiques MODIFIÉS (niveau fiche — jamais envoyés avec un prélèvement).
  List<Map<String, dynamic>> _physicalPayload() => [
        for (final p in _physicalParams)
          if (_physicalCtrls[p.key]!.text.trim() != _physicalSaved[p.key]) {'parameterKey': p.key, 'value': _physicalCtrls[p.key]!.text.trim()},
      ];

  /// « Enregistrer » du bloc Paramètres physiques : écrit UNIQUEMENT les
  /// paramètres physiques de la fiche — aucun prélèvement n'est envoyé ni
  /// rechargé (la saisie en cours d'un prélèvement reste à l'écran).
  Future<void> _savePhysical() async {
    if (_saving || _readOnly) return;
    if (_isCreate) return _saveDraft(); // la fiche n'existe pas encore : création complète
    final payload = _fichePayload();
    if (payload.isEmpty) {
      _snack(context, 'Paramètres de la fiche déjà enregistrés.');
      return;
    }
    await _run(() async {
      final saved = await QualityControlService.instance.update(widget.controlId!, physical: payload);
      if (!mounted) return;
      setState(() {
        _control = saved;
        _syncPhysical(saved);
      });
      _snack(context, 'Paramètres de la fiche enregistrés.');
    });
  }

  /// Charge un prélèvement dans LE formulaire : ses valeurs enregistrées, ou
  /// l'étape 1 vierge (`reading` null) à l'heure `time`.
  void _showReading(QualityReading? reading, {String? time}) {
    _readingId = reading?.id;
    final now = _tunisNow();
    _readingTime = reading?.readingTime ?? (qcIsValidReadingTime(time) ? time! : '${_two(now.hour)}:${_two(now.minute)}');
    _form.load(reading);
  }

  /// Lancée quand la date de production ou le poste est choisi / modifié et
  /// au chargement d'un brouillon : état de la recherche + lot et ordre de
  /// fabrication de la production. Informative : un échec ou une absence de
  /// fiche ne bloque ni l'enregistrement ni la validation.
  Future<void> _lookupProduction() async {
    final seq = ++_matchSeq;
    final c = _control;
    if (c == null || _readOnly || c.machine == null || !_header.canMatchProduction) {
      if (mounted && _match != null) setState(() => _match = null);
      return;
    }
    QcProductionMatch? match;
    try {
      match = await QualityControlService.instance.fetchProductionMatch(
        productionType: c.productionType,
        machine: c.machine!,
        productionDate: _header.productionDate!,
        poste: _header.poste!,
      );
    } catch (_) {
      match = null;
    }
    if (mounted && seq == _matchSeq) setState(() => _match = match);
  }

  // ── Lot / ordre de fabrication ─────────────────────────────────────────

  /// Lot repris de la fiche de production (recherche à jour pour la date et
  /// le poste affichés ; à défaut, valeur automatique enregistrée). null :
  /// la production ne le porte pas → saisie manuelle.
  String? get _autoLot => _match != null ? _match!.lot : ((_control?.lotAuto ?? false) ? _control!.lot : null);

  /// Fabrication contrôlée (« FAB01 — 28/08/2026 — Ø12 ») : identification
  /// composée par le serveur depuis la fiche de production — jamais saisie.
  /// null : aucune fiche de production → « Non renseigné ».
  String? get _fabrication {
    final saved = (_control?.manufacturingOrder ?? '').trim();
    return _match != null ? _match!.manufacturingOrder : (saved.isEmpty ? null : saved);
  }

  /// En-tête à envoyer : champs MODIFIÉS uniquement. L'ordre de fabrication
  /// n'est jamais envoyé, ni un lot automatique (le serveur les reprend
  /// lui-même de la production).
  Map<String, String> _headerPayload() => _header
      .copyWith(lot: _autoLot != null ? _savedHeader.lot : _lotCtrl.text, manufacturingOrder: _savedHeader.manufacturingOrder)
      .diff(_savedHeader);

  bool get _remarkChanged => _generalRemarkCtrl.text.trim() != (_control?.remark ?? '').trim();
  // Saisie de niveau FICHE non enregistrée : identification, remarque,
  // paramètres physiques.
  bool get _headerDirty => !_readOnly && (_headerPayload().isNotEmpty || _remarkChanged || _fichePayload().isNotEmpty);

  // ── Saisie du prélèvement affiché ───────────────────────────────────────────

  bool get _timeChanged => !_pending && _readingTime != _reading?.readingTime;

  /// Saisie non enregistrée dans le prélèvement affiché.
  bool get _readingDirty => !_readingLocked && (_form.hasChanges || _timeChanged);

  /// Autre prélèvement de la fiche déjà enregistré à cette heure.
  QualityReading? _readingAt(String time, {bool excludeCurrent = true}) {
    for (final r in _control?.readings ?? const <QualityReading>[]) {
      if ((!excludeCurrent || r.id != _readingId) && r.readingTime == time) return r;
    }
    return null;
  }

  bool _showErrors(List<String> errors) {
    if (errors.isEmpty) return false;
    setState(() => _serverErrors = errors);
    _snack(context, 'Champs obligatoires manquants', error: true);
    return true;
  }

  // ── Erreurs serveur ────────────────────────────────────────────────────

  Future<void> _handleError(Object e) async {
    if (e is QualityControlApiException) {
      if (e.code == 'READING_TIME_EXISTS') {
        final existing = _control?.reading(e.existingReadingId);
        final open = await _duplicateTimeDialog(_readingTime, existing);
        if (open == true && existing != null && mounted) setState(() => _showReading(existing));
        return;
      }
      if (e.code == 'FICHE_EXISTS' && e.existingId != null) return _existingFicheDialog(e);
      if (e.errors.isNotEmpty) {
        // Erreurs du prélèvement affiché (ou de la fiche) : champs signalés.
        final mine = e.errors.where((m) => m['readingId'] == null || m['readingId'] == _readingId);
        _form.flagErrors(keys: mine.map((m) => m['parameterKey']?.toString()).whereType<String>().toSet());
        setState(() => _serverErrors = e.errors.map((m) => m['message'].toString()).toList());
      }
    }
    if (mounted) _snack(context, e.toString(), error: true);
  }

  /// « Un prélèvement existe déjà pour 08:00. » — true : ouvrir le prélèvement
  /// existant ; false : choisir une autre heure ; null : fermer.
  Future<bool?> _duplicateTimeDialog(String time, QualityReading? existing) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prélèvement déjà enregistré'),
          content: Text('Un prélèvement existe déjà pour $time.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Choisir une autre heure')),
            if (existing != null) FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ouvrir le prélèvement existant')),
          ],
        ),
      );

  /// Une fiche est déjà ouverte pour cette machine / date / poste : les
  /// contrôles suivants sont des prélèvements de CETTE fiche.
  Future<void> _existingFicheDialog(QualityControlApiException e) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fiche déjà ouverte'),
        content: Text(e.message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ouvrir la fiche existante')),
        ],
      ),
    );
    if (open == true && mounted) context.go(QcPaths.control(e.existingId!));
  }

  // ── Enregistrement ─────────────────────────────────────────────────────

  /// Le prélèvement affiché doit-il être écrit par la sauvegarde ?
  bool get _readingToSave => !_readingLocked && (_pending ? (_isCreate || _form.hasChanges) : _readingDirty);

  /// Contrôles communs avant tout envoi : identification, heure du prélèvement,
  /// heure déjà utilisée par un autre prélèvement de la fiche.
  Future<bool> _precheck() async {
    if (_showErrors(_header.errors())) return false;
    if (!_readingToSave) return true;
    if (_showErrors([if (!qcIsValidReadingTime(_readingTime)) 'Heure du prélèvement : heure valide obligatoire.'])) return false;
    final existing = _readingAt(_readingTime);
    if (existing != null) {
      final open = await _duplicateTimeDialog(_readingTime, existing);
      if (!mounted) return false;
      if (open == true) {
        setState(() => _showReading(existing));
      } else if (open == false) {
        await _pickReadingTime();
      }
      return false;
    }
    return true;
  }

  /// Écrit l'identification (si elle a changé) puis le prélèvement affiché (s'il
  /// porte une saisie) ; retourne la fiche relue en base, ou null si rien
  /// n'était à écrire. `validateReading` valide le prélèvement affiché.
  Future<QualityControlModel?> _persist({bool validateReading = false}) async {
    final svc = QualityControlService.instance;
    final id = widget.controlId!;
    QualityControlModel? saved;
    final header = _headerPayload();
    // Niveau fiche (identification, remarque, paramètres physiques) puis
    // niveau prélèvement : deux écritures distinctes, jamais mélangées.
    final physical = _fichePayload();
    if (header.isNotEmpty || _remarkChanged || physical.isNotEmpty) {
      saved = await svc.update(id, header: header, remark: _generalRemarkCtrl.text.trim(), physical: physical);
    }
    if (_pending) {
      if (_readingToSave || validateReading) {
        saved = await svc.createReading(id, readingTime: _readingTime, items: _form.payload(), validate: validateReading, status: _form.result);
      }
    } else if (validateReading) {
      saved = await svc.validateReading(id, _readingId!, readingTime: _timeChanged ? _readingTime : null, items: _form.payload(), status: _form.result);
    } else if (_readingToSave) {
      saved = await svc.updateReading(id, _readingId!, readingTime: _timeChanged ? _readingTime : null, items: _form.payload());
    }
    return saved;
  }

  /// Exécute une écriture ; true si elle a réussi.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) await _handleError(e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_saving || !await _precheck()) return;
    if (_isCreate) return _createAndOpen();
    await _run(() async {
      // Réponse = fiche relue en base : les champs affichés sont ceux
      // réellement enregistrés.
      final saved = await _persist();
      if (saved != null) _applyControl(saved);
      if (mounted) _snack(context, 'Contrôle qualité enregistré avec succès.');
    });
  }

  /// Validation du PRÉLÈVEMENT affiché : il passe en lecture seule ; la fiche
  /// reste ouverte pour les prélèvements suivants.
  Future<void> _validateReading() async {
    if (_saving || _readingLocked) return;
    final errors = [..._header.errors(), if (!qcIsValidReadingTime(_readingTime)) 'Heure du prélèvement : heure valide obligatoire.', ..._form.errors()];
    if (errors.isNotEmpty) _form.flagErrors();
    if (_showErrors(errors)) return;
    if (!await _precheck() || !mounted) return;
    final result = _form.result;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Valider le prélèvement de $_readingTime'),
        content: Text(
          'Résultat : ${qualityResultLabel(result)}\n\n'
          'Le prélèvement ne sera plus modifiable. La fiche reste ouverte : vous pourrez ajouter les prélèvements suivants.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Valider le prélèvement')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_isCreate) return _createAndOpen(validateReading: true, status: result);
    await _run(() async {
      final saved = await _persist(validateReading: true);
      if (saved != null) _applyControl(saved);
      if (mounted) {
        final notified = saved?.notificationsSent;
        _snack(context, 'Prélèvement validé : ${qualityResultLabel(result)}${notified != null && notified > 0 ? ' — $notified responsable(s) notifié(s)' : ''}');
      }
    });
  }

  /// Validation de la FICHE : ses prélèvements brouillons sont validés avec elle
  /// et tout passe en lecture seule (plus aucun prélèvement ajoutable).
  Future<void> _validate() async {
    if (_saving) return;
    final errors = <String>[..._header.errors()];
    // Le prélèvement affiché est contrôlé ici ; les autres prélèvements brouillons le
    // sont par le serveur (erreurs listées par prélèvement).
    if (_readingToSave || (!_readingLocked && !_pending)) {
      final own = _form.errors();
      if (own.isNotEmpty) _form.flagErrors();
      errors.addAll(own);
    }
    if (_showErrors(errors)) return;
    if (!await _precheck() || !mounted) return;
    final result = _form.result;
    final count = (_control?.readings.length ?? 0) + (_pending && _readingToSave ? 1 : 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider le contrôle qualité'),
        content: Text(
          'Résultat : ${qualityResultLabel(result)} · $count prélèvement(s)\n\n'
          'Ouvert le ${qcIsoDateToDisplay(_header.controlDate)} à ${_header.controlTime ?? '—'}. '
          'La fiche et tous ses prélèvements passent en lecture seule : aucun prélèvement ne pourra plus être ajouté. '
          'L\'horodatage de la validation et le contrôleur sont enregistrés automatiquement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_isCreate) return _createAndOpen(validate: true, status: result);

    await _run(() async {
      final saved = await _persist();
      if (saved != null) _applyControl(saved);
      final control = await QualityControlService.instance.validate(widget.controlId!, status: result);
      _applyControl(control);
      if (mounted) {
        final notified = control.notificationsSent;
        _snack(
          context,
          'Contrôle qualité validé : ${qualityResultLabel(control.status)}'
          '${notified != null && notified > 0 ? ' — $notified responsable(s) notifié(s)' : ''}',
        );
      }
    });
  }

  /// CRÉATION : un seul POST (fiche + étape 1, validations demandées dans la
  /// même transaction), puis réouverture de la fiche ENREGISTRÉE par son id
  /// (relue en base, mode édition).
  Future<void> _createAndOpen({bool validate = false, bool validateReading = false, String? status}) => _run(() async {
        final control = await QualityControlService.instance.create(
          productionType: widget.productionType!.toUpperCase(),
          machine: widget.machine!,
          readingTime: _readingTime,
          items: _form.payload(),
          readingValidate: validateReading,
          remark: _generalRemarkCtrl.text.trim(),
          physical: _fichePayload(),
          header: _headerPayload(),
          validate: validate,
          status: status,
        );
        if (!mounted) return;
        _snack(
          context,
          validate
              ? 'Contrôle qualité validé : ${qualityResultLabel(control.status)}'
              : validateReading
                  ? 'Prélèvement validé : ${qualityResultLabel(status ?? 'CONFORME')}'
                  : 'Contrôle qualité enregistré avec succès.',
        );
        context.go(QcPaths.control(control.id));
      });

  /// Suppression d'une fiche BROUILLON (le backend refuse une fiche validée :
  /// 403 CONTROL_LOCKED). Retour à la machine, données relues via l'API.
  Future<void> _delete() async {
    final c = _control;
    if (c == null || _saving || c.isValidated || _isCreate) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le brouillon'),
        content: Text('La fiche qualité ${c.reference} (brouillon) de la ${c.machineLabel ?? 'machine'} et ses ${c.readings.length} prélèvement(s) seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await QualityControlService.instance.delete(c.id);
      if (!mounted) return;
      _snack(context, 'Brouillon supprimé.');
      context.go(c.machine != null ? QcPaths.machine(c.productionType, c.machine!) : QcPaths.history);
    });
  }

  // ── Étapes : navigation, nouveau prélèvement, suppression ───────────────────

  /// Avant de quitter le prélèvement affiché : la saisie en cours (brouillon,
  /// identification) est ENREGISTRÉE — naviguer entre les étapes ne perd
  /// jamais de donnée. false : l'enregistrement a échoué, on reste.
  Future<bool> _leaveReading() async {
    if (_isCreate) return false;
    if (!_readingDirty && !_headerDirty) return true;
    if (!await _precheck()) return false;
    return _run(() async {
      final saved = await _persist();
      if (saved != null) _applyControl(saved);
    });
  }

  Future<void> _selectReading(QualityReading reading) async {
    if (_saving || reading.id == _readingId) return;
    if (!await _leaveReading() || !mounted) return;
    // La fiche a pu être relue : prélèvement pris dans la version à jour.
    final fresh = _control?.reading(reading.id);
    if (fresh == null) return;
    setState(() {
      _serverErrors = [];
      _showReading(fresh);
    });
  }

  /// Sélecteur d'heure (24 h) — retourne HH:mm, ou null si annulé. [help] reste
  /// court : l'en-tête du sélecteur n'a qu'une ligne.
  Future<String?> _askTime({required String initial, required String help}) async {
    final parts = initial.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts.length >= 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0) : TimeOfDay.now(),
      helpText: qcT(help),
      cancelText: qcT('Annuler'),
      confirmText: qcT('Valider'),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return picked == null ? null : '${_two(picked.hour)}:${_two(picked.minute)}';
  }

  /// « + Nouveau prélèvement » : heure proposée = dernier prélèvement + cadence
  /// recommandée (3 h), affichée dans le sélecteur et modifiable ; l'étape
  /// suivante est alors créée (mêmes paramètres, valeurs vides) et affichée
  /// dans le MÊME formulaire. Les prélèvements existants ne sont jamais touchés.
  Future<void> _newReading() async {
    if (_saving || _readOnly || _isCreate || _pending) return;
    if (!await _leaveReading() || !mounted) return;
    var time = _control?.suggestedNextReadingTime ?? _readingTime;
    while (true) {
      final picked = await _askTime(initial: time, help: 'Prélèvement');
      if (picked == null || !mounted) return;
      final existing = _readingAt(picked, excludeCurrent: false);
      if (existing == null) {
        time = picked;
        break;
      }
      final open = await _duplicateTimeDialog(picked, existing);
      if (!mounted || open == null) return;
      if (open) {
        setState(() => _showReading(existing));
        return;
      }
    }
    final created = time;
    await _run(() async {
      final saved = await QualityControlService.instance.createReading(widget.controlId!, readingTime: created);
      _applyControl(saved);
      if (mounted) _snack(context, 'Étape ${saved.reading(saved.readingId)?.step ?? saved.readings.length} créée — prélèvement de $created.');
    });
  }

  /// Heure du prélèvement affiché (modifiable tant qu'il est brouillon).
  Future<void> _pickReadingTime() async {
    if (_readingLocked || _saving) return;
    final time = await _askTime(initial: _readingTime, help: 'Prélèvement');
    if (time == null || !mounted) return;
    final existing = _readingAt(time);
    if (existing != null) {
      final open = await _duplicateTimeDialog(time, existing);
      if (!mounted) return;
      if (open == true) return _selectReading(existing);
      if (open == false) return _pickReadingTime();
      return;
    }
    setState(() => _readingTime = time);
  }

  /// Suppression du prélèvement BROUILLON affiché (les autres prélèvements sont intacts).
  Future<void> _deleteReading() async {
    final r = _reading;
    if (_saving || _readingLocked || r == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le prélèvement'),
        content: Text('L\'étape ${r.step} — prélèvement de ${r.readingTime} (brouillon) — sera supprimée. Les autres prélèvements de la fiche sont conservés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final saved = await QualityControlService.instance.deleteReading(widget.controlId!, r.id);
      _readingId = null;
      _applyControl(saved);
      if (mounted) _snack(context, 'Prélèvement de ${r.readingTime} supprimé.');
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    if (_loading && _control == null) {
      return const Padding(padding: EdgeInsets.all(24), child: QcSkeletonRows(rows: 8, height: 64));
    }
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(24), child: QcErrorBanner('Contrôle qualité indisponible : $_error', onRetry: _load));
    }
    final c = _control!;
    final color = productionTypeColor(c.productionType);
    final backPath = c.machine != null ? QcPaths.machine(c.productionType, c.machine!) : QcPaths.history;

    final header = QcPageHeader(
      crumbs: [
        ('Contrôle Qualité', QcPaths.root),
        (c.productionType, QcPaths.line(c.productionType)),
        if (c.machine != null) (c.machineLabel ?? 'Machine ${c.machine}', QcPaths.machine(c.productionType, c.machine!)),
        (_isCreate ? 'Nouveau contrôle qualité' : c.reference, null),
      ],
      title: _isCreate ? 'Nouveau contrôle qualité' : 'Contrôle qualité ${c.reference}',
      icon: kQualityControlIcon,
      color: color,
      onBack: () => context.go(backPath),
      meta: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        QcLineChip(c.productionType),
        _metaChip(kMachineIcon, c.machineLabel ?? 'Machine —'),
        if (qcIsoDateToDisplay(_header.productionDate).isNotEmpty) _metaChip(Icons.event_outlined, qcIsoDateToDisplay(_header.productionDate)),
        if (qualityPosteLabel(_header.poste) != null) _metaChip(Icons.wb_twilight_rounded, 'Poste ${qualityPosteLabel(_header.poste)}'),
        _metaChip(Icons.format_list_numbered_rounded, '${c.readings.length} prélèvement${c.readings.length > 1 ? 's' : ''}'),
      ]),
      // Étiquette de la fiche (référence générée par le serveur à la première
      // sauvegarde) + statut.
      trailing: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (c.reference.isNotEmpty) QcReferenceBadge(c.reference, productionType: c.productionType, key: const ValueKey('qc-reference-badge')),
        if (c.isValidated) ...[QcStatusBadge(c.status), const QcStatusBadge('VALIDE')] else const QcStatusBadge('BROUILLON'),
      ]),
    );

    return LayoutBuilder(builder: (context, box) {
      final padding = qcPagePadding(box.maxWidth);
      return Column(children: [
        // Identification TOUJOURS visible (reste en place au défilement).
        _identityBar(c, color, padding),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kQcMaxContentWidth),
              child: ListView(padding: padding, children: [
                header,
                if (c.isValidated) _lockedBanner(c) else if (_readOnly) const QcReadOnlyNote(),
                _identificationSection(c, color),
                // Stepper horizontal = navigation entre prélèvements ; dessous, le
                // prélèvement ACTUEL seul (ses contrôles temporels), ses actions,
                // puis — à part — les paramètres physiques de la fiche.
                _stepsSection(c, color),
                _readingSection(c, color),
                _parametersHeading(c, color),
                QualityReadingForm(
                  controller: _form,
                  config: _config,
                  // Liste de la machine si elle en a une (PROMESH 4), sinon de la ligne.
                  productionType: _config.lineKey(c.productionType, c.machine),
                  readingTime: _readingTime,
                  locked: _readingLocked,
                  busy: _saving,
                  previous: _previousReading(c),
                  validated: _reading?.isValidated ?? false,
                ),
                if (!_readOnly) _readingActions(c),
                // PROMESH : paramètres physiques et contrôle du treillis dans UNE
                // section ; PROBAR : paramètres physiques seuls.
                // PROMESH (13 paramètres du prélèvement) : aucun paramètre de niveau
                // fiche → aucune section, la synthèse suit directement les prélèvements.
                if (_specificParams.isNotEmpty) _treillisSection(c, color) else if (_physicalParams.isNotEmpty) _physicalSection(c, color),
                // PROMESH uniquement : jamais affiché pour PROBAR.
                _summarySection(c),
              ]),
            ),
          ),
        ),
        if (!_readOnly) _actionBar(c, padding),
      ]);
    });
  }

  Widget _metaChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(6), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kCrmTextSub),
          const SizedBox(width: 5),
          Text(label, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmText)),
        ]),
      );

  /// Bandeau d'identification compact, fixe en haut de la fiche : ligne,
  /// machine, date, poste, lot et fabrication restent visibles en permanence.
  Widget _identityBar(QualityControlModel c, Color color, EdgeInsets padding) {
    final lot = _autoLot ?? _lotCtrl.text.trim();
    final fabrication = _fabrication;
    Widget item(IconData icon, String text, {bool strong = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kCrmTextSub),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: strong ? FontWeight.w800 : FontWeight.w700, color: kCrmText)),
          ),
        ]);
    return Container(
      key: const ValueKey('qc-identity-bar'),
      width: double.infinity,
      decoration: BoxDecoration(color: kCrmSurface, border: Border(bottom: const BorderSide(color: kCrmBorder), left: BorderSide(color: color, width: 4))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kQcMaxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 8, padding.right, 8),
            child: Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              // Référence : absente tant que la fiche n'est pas enregistrée.
              if (c.reference.isNotEmpty) QcReferenceBadge(c.reference, productionType: c.productionType, dense: true) else QcLineChip(c.productionType, dense: true),
              item(kMachineIcon, c.machineLabel ?? 'Machine —', strong: true),
              item(Icons.event_outlined, qcIsoDateToDisplay(_header.productionDate).isEmpty ? 'Date à renseigner' : qcIsoDateToDisplay(_header.productionDate)),
              item(Icons.wb_twilight_rounded, 'Poste : ${qualityPosteLabel(_header.poste) ?? '—'}'),
              item(Icons.inventory_2_outlined, 'Lot : ${lot.isEmpty ? '—' : lot}'),
              item(Icons.assignment_outlined, 'Fabrication : ${fabrication ?? 'non renseignée'}', strong: fabrication != null),
            ]),
          ),
        ),
      ),
    );
  }

  /// Actions du PRÉLÈVEMENT actuel, placées juste avant les paramètres physiques :
  /// « Valider le prélèvement » ne valide que le prélèvement affiché — ni les autres
  /// prélèvements, ni les paramètres physiques.
  Widget _readingActions(QualityControlModel c) => Container(
        key: const ValueKey('qc-reading-actions'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: qcCardDecoration(),
        child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
          Text(
            _readingLocked ? 'Prélèvement de $_readingTime validé — lecture seule' : 'Prélèvement de $_readingTime',
            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmTextSub),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveDraft,
            style: OutlinedButton.styleFrom(
              foregroundColor: kCrmText,
              side: const BorderSide(color: kCrmBorder),
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'Enregistrement…' : 'Enregistrer le prélèvement'),
          ),
          if (!_readingLocked)
            FilledButton.icon(
              onPressed: _saving ? null : _validateReading,
              style: FilledButton.styleFrom(
                backgroundColor: kCrmSuccess,
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Valider le prélèvement'),
            ),
        ]),
      );

  int get _physicalFilled => _physicalParams.where((p) => _physicalCtrls[p.key]!.text.trim().isNotEmpty).length;

  /// Champ d'un paramètre physique de la fiche (valeur seule). Controller
  /// persistant — jamais recréé dans build().
  ///
  /// [numeric] : n'accepte que des chiffres (et un séparateur décimal).
  Widget _physicalField(QualityControlModel c, QualityParameter p, Color color, {bool numeric = false}) {
    final enabled = !_readOnly && !_saving;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));
    final ctrl = _physicalCtrls[p.key]!;
    final changed = ctrl.text.trim() != _physicalSaved[p.key];
    // Anciennes fiches : le paramètre portait un statut — rappelé, non saisi.
    final legacy = c.physicalParameters.where((i) => i.parameterKey == p.key).firstOrNull?.status ?? 'NON_CONTROLE';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(p.label,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmText, letterSpacing: 0.2)),
        ),
        if (legacy != 'NON_CONTROLE') QcStatusBadge(legacy, dense: true),
      ]),
      const SizedBox(height: 6),
      // Paramètre à choix (ex. qualité de coupe : Bon / Pas bon) : options
      // exclusives, aucune saisie libre.
      if (p.kind == 'choice' && p.options.isNotEmpty)
        _physicalChoice(p, ctrl, enabled: enabled, changed: changed, color: color)
      else
      TextField(
        key: ValueKey('qc-physical-${p.key}'),
        controller: ctrl,
        readOnly: !enabled,
        canRequestFocus: enabled,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
        inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
        onChanged: (_) => setState(() {}),
        style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: enabled ? kCrmSurface : kCrmBg,
          hintText: enabled ? qcT(p.hint ?? 'Valeur') : '—',
          hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
          // Unité : uniquement celle fournie par le backend.
          suffixText: p.unit != null && p.unit!.isNotEmpty ? p.unit : null,
          suffixStyle: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub),
          border: border(kCrmBorder),
          enabledBorder: border(changed ? color : kCrmBorder, changed ? 1.4 : 1),
          focusedBorder: border(color, 1.5),
        ),
      ),
    ]);
  }

  /// Choix exclusif d'un paramètre physique. La valeur choisie (code du
  /// backend : BON, PAS_BON…) vit dans le même controller persistant que les
  /// champs texte : même sauvegarde, même compteur. Aucune sélection par
  /// défaut ; un second appui sur l'option choisie l'efface.
  Widget _physicalChoice(QualityParameter p, TextEditingController ctrl, {required bool enabled, required bool changed, required Color color}) {
    final selected = ctrl.text.trim();
    return Container(
      key: ValueKey('qc-physical-${p.key}'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: enabled ? kCrmSurface : kCrmBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: changed ? color : kCrmBorder, width: changed ? 1.4 : 1),
      ),
      child: Row(children: [
        for (final o in p.options)
          Expanded(
            child: Builder(builder: (context) {
              final on = selected == o.value;
              final tone = o.tone == 'nok' ? kQcNonConformeText : (o.tone == 'warn' ? kQcAVerifierText : kQcConformeText);
              return InkWell(
                key: ValueKey('qc-physical-${p.key}-${o.value}'),
                onTap: enabled ? () => setState(() => ctrl.text = on ? '' : o.value) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(color: on ? tone.withValues(alpha: 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: on ? tone : kCrmTextSub),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(o.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? tone : kCrmText)),
                    ),
                  ]),
                ),
              );
            }),
          ),
      ]),
    );
  }

  /// 03 — CONTRÔLE PRODUIT (paramètres de niveau fiche — PROBAR) : un seul bloc,
  /// indépendant des prélèvements et de l'heure. (PROMESH : fusionnés dans « Paramètres
  /// spécifiques PROMESH » — voir _specificSection.)
  Widget _physicalSection(QualityControlModel c, Color color) {
    final filled = _physicalFilled;
    return QcSection(
      key: const ValueKey('qc-physical-section'),
      icon: Icons.straighten_rounded,
      // PROBAR : titre et sous-titre inchangés. PROMESH : caractéristiques du produit.
      title: c.productionType == 'PROMESH' ? 'Contrôle Produit' : 'Contrôle produit',
      subtitle: c.productionType == 'PROMESH'
          ? 'Caractéristiques du produit — saisies une seule fois pour la fiche, communes à tous les prélèvements'
          : 'Contrôle dimensionnel et qualité du produit — indépendant des prélèvements',
      color: color,
      trailing: Text('$filled / ${_physicalParams.length} renseigné(s)', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      children: [
        if (_physicalParams.isEmpty)
          const QcEmptyState('Aucun paramètre physique défini pour cette ligne.', icon: Icons.straighten_rounded)
        else
          qcGrid(columns: qcColumnsFor(240, max: 3), [for (final p in _physicalParams) _physicalField(c, p, color)]),
        if (!_readOnly && _physicalParams.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: FilledButton.icon(
                key: const ValueKey('qc-save-physical'),
                onPressed: _saving ? null : _savePhysical,
                style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Enregistrer'),
              ),
            ),
          ),
      ],
    );
  }

  /// 03 — PARAMÈTRES SPÉCIFIQUES de la ligne (PROMESH : treillis GFRP) : UNE
  /// seule section de niveau fiche, indépendante des prélèvements et de l'heure,
  /// saisie une seule fois — un compteur, un bouton « Enregistrer », une
  /// sauvegarde. Deux sous-groupes :
  ///   Caractéristiques du treillis — paramètres physiques (valeur) ;
  ///   Contrôle dimensionnel et géométrique — valeur, statut (Conforme /
  ///   Non conforme / Non contrôlé) et remarque.
  /// Les paramètres viennent du backend ; rien n'est codé en dur.
  Widget _treillisSection(QualityControlModel c, Color color) {
    const icons = <String, IconData>{
      'treillis_geometrie': Icons.square_foot_rounded,
      'treillis_assemblage': Icons.hub_outlined,
      'treillis_mecanique': Icons.fitness_center_rounded,
    };
    final enabled = !_readOnly && !_saving;
    final sections = _config.specificSections(_config.lineKey(c.productionType, c.machine));
    // Renseigné : une valeur saisie ou un statut choisi (calculé sur la liste
    // réelle des paramètres — jamais un nombre en dur).
    final filled = _physicalFilled +
        _specificParams.where((p) => _specStatuses[p.key] != 'NON_CONTROLE' || (_specValueCtrls[p.key]?.text.trim().isNotEmpty ?? false)).length;
    final total = _physicalParams.length + _specificParams.length;
    Widget groupTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Row(children: [
            Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: 0.7)),
            ),
          ]),
        );
    final nc = _specificParams.where((p) => _specStatuses[p.key] == 'NON_CONFORME').length;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));

    // Résultat d'un paramètre contrôlé : Conforme ou Non conforme. Aucun
    // bouton « Non contrôlé » : un paramètre sans résultat n'est simplement
    // pas encore renseigné (un second appui sur l'option choisie l'efface).
    Widget statusToggle(String key) {
      final status = _specStatuses[key] ?? 'NON_CONTROLE';
      Widget option(String value, String label) {
        final selected = status == value;
        final tone = qualityStatusColor(value);
        return Expanded(
          child: InkWell(
            key: ValueKey('qc-specific-status-$key-$value'),
            onTap: enabled ? () => setState(() => _specStatuses[key] = selected ? 'NON_CONTROLE' : value) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: selected ? tone : kCrmTextSub),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? tone : kCrmText)),
                ),
              ]),
            ),
          ),
        );
      }

      return Row(children: [option('CONFORME', 'Conforme'), const SizedBox(width: 6), option('NON_CONFORME', 'Non conforme')]);
    }

    Widget card(QualityParameter p) {
      final status = _specStatuses[p.key] ?? 'NON_CONTROLE';
      final isNc = status == 'NON_CONFORME';
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isNc ? kCrmDanger.withValues(alpha: 0.04) : kCrmSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isNc ? kCrmDanger.withValues(alpha: 0.5) : kCrmBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(p.label,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmText, letterSpacing: 0.2)),
            ),
            if (status != 'NON_CONTROLE') Icon(isNc ? Icons.cancel_rounded : Icons.check_circle_rounded, size: 16, color: qualityStatusColor(status)),
          ]),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('qc-specific-${p.key}'),
            controller: _specValueCtrls[p.key],
            readOnly: !enabled,
            canRequestFocus: enabled,
            onChanged: (_) => setState(() {}),
            style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              filled: true,
              fillColor: kCrmBg,
              hintText: enabled ? qcT('Valeur') : '—',
              hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
              // Unité : uniquement celle fournie par le backend.
              suffixText: p.unit != null && p.unit!.isNotEmpty ? p.unit : null,
              border: border(kCrmBorder),
              enabledBorder: border(kCrmBorder),
              focusedBorder: border(color, 1.5),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('qc-specific-remark-${p.key}'),
            controller: _specRemarkCtrls[p.key],
            readOnly: !enabled,
            canRequestFocus: enabled,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            style: tInter(fontSize: 12.5, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.notes_rounded, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              hintText: qcT(isNc ? 'Expliquer l\'anomalie (recommandé)' : 'Remarque'),
              hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
              filled: true,
              fillColor: kCrmBg,
              border: border(kCrmBorder),
              enabledBorder: border(kCrmBorder),
            ),
          ),
          const SizedBox(height: 6),
          statusToggle(p.key),
        ]),
      );
    }

    Widget subSection(QualitySection s, String letter) {
      final params = _specificParams.where((p) => p.section == s.key).toList();
      final done = params.where((p) => _specStatuses[p.key] != 'NON_CONTROLE').length;
      final bad = params.where((p) => _specStatuses[p.key] == 'NON_CONFORME').length;
      return Container(
        key: ValueKey('qc-${s.key}'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(letter, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(width: 10),
            Icon(icons[s.key] ?? Icons.tune_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.label.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: 0.6)),
            ),
            Text.rich(TextSpan(children: [
              TextSpan(text: '$done / ${params.length}', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
              if (bad > 0) TextSpan(text: '  ·  $bad NC', style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kQcNonConformeText)),
            ])),
          ]),
          const SizedBox(height: 12),
          qcGrid(columns: qcColumnsFor(250, max: 3), [for (final p in params) card(p)]),
        ]),
      );
    }

    var letter = 0;
    return QcSection(
      key: const ValueKey('qc-treillis-section'),
      number: '03',
      icon: Icons.grid_on_rounded,
      title: 'Paramètres spécifiques ${c.productionType}',
      subtitle: 'Contrôle dimensionnel et géométrique du treillis GFRP — indépendant des prélèvements, saisi une seule fois pour la fiche',
      color: color,
      trailing: Text.rich(TextSpan(children: [
        TextSpan(text: '$filled / $total renseigné(s)', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
        if (nc > 0) TextSpan(text: '  ·  $nc NC', style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kQcNonConformeText)),
      ])),
      children: [
        // Caractéristiques du treillis : paramètres physiques de la fiche.
        if (_physicalParams.isNotEmpty) ...[
          groupTitle('Caractéristiques du treillis'),
          Padding(
            key: const ValueKey('qc-physical-group'),
            padding: const EdgeInsets.only(bottom: 18),
            child: qcGrid(columns: qcColumnsFor(240, max: 3), [for (final p in _physicalParams) _physicalField(c, p, color, numeric: p.kind == 'number')]),
          ),
          groupTitle('Contrôle dimensionnel et géométrique'),
        ],
        // Une seule sous-section (géométrie) : les cartes directement ;
        // plusieurs : une sous-section lettrée chacune.
        if (sections.length == 1)
          Padding(
            key: ValueKey('qc-${sections.single.key}'),
            padding: const EdgeInsets.only(bottom: 14),
            child: qcGrid(columns: qcColumnsFor(250, max: 3), [for (final p in _specificParams) card(p)]),
          )
        else
          for (final s in sections) subSection(s, String.fromCharCode(65 + letter++)),
        _specificResultRow(),
        if (!_readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('qc-save-specific'),
              onPressed: _saving ? null : _savePhysical,
              style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
      ],
    );
  }

  /// Résultat du contrôle dimensionnel : calculé sur les paramètres qui
  /// portent un résultat (jamais sur les caractéristiques du treillis) — un
  /// non conforme → Non conforme ; sinon au moins un conforme → Conforme ;
  /// rien de renseigné → À vérifier. Même règle que le backend
  /// (`specificResult`).
  Widget _specificResultRow() {
    final statuses = [for (final p in _specificParams) _specStatuses[p.key] ?? 'NON_CONTROLE'];
    final result = statuses.contains('NON_CONFORME') ? 'NON_CONFORME' : (statuses.contains('CONFORME') ? 'CONFORME' : 'EN_ATTENTE');
    final color = qualityStatusColor(result == 'EN_ATTENTE' ? '' : result);
    final (label, icon) = switch (result) {
      'CONFORME' => ('Conforme', Icons.check_circle_rounded),
      'NON_CONFORME' => ('Non conforme', Icons.cancel_rounded),
      _ => ('À vérifier', Icons.help_outline_rounded),
    };
    return Container(
      key: const ValueKey('qc-specific-result'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(children: [
        Expanded(child: Text('Résultat du contrôle dimensionnel', style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText))),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  /// Barre d'actions de la FICHE, toujours visible en bas de l'écran (les
  /// actions du prélèvement sont dans la page, avant les paramètres physiques).
  Widget _actionBar(QualityControlModel c, EdgeInsets padding) {
    ButtonStyle outlined([Color fg = kCrmText, Color side = kCrmBorder]) => OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: side),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kCrmSurface,
        border: Border(top: BorderSide(color: kCrmBorder)),
        boxShadow: [BoxShadow(color: Color(0x140F172A), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kQcMaxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 10, padding.right, 10),
              child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
                if (!_isCreate)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: outlined(kCrmDanger, kCrmDanger.withValues(alpha: 0.5)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _validate,
                  style: FilledButton.styleFrom(
                    backgroundColor: kQualityControlColor,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Valider le contrôle qualité'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  /// Bandeau d'une fiche VALIDÉE : lecture seule, aucune action.
  Widget _lockedBanner(QualityControlModel c) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kCrmSuccess.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kCrmSuccess.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.lock_rounded, size: 18, color: kQcConformeText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Contrôle qualité validé — Lecture seule · validé le ${c.validatedDate ?? c.controlDate} à ${c.validatedTime ?? c.controlTime} '
              'par ${c.controllerEmail}. Aucune modification ni suppression possible.',
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kQcConformeText),
            ),
          ),
        ]),
      );

  // ── 01 Identification ──────────────────────────────────────────────────

  bool get _headerEditable => !_readOnly && !_saving;

  Future<void> _pickDate({required String? current, required String help, required void Function(String iso) onPicked}) async {
    final now = DateTime.now();
    final initial = qcDateFromIso(current) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: qcT(help),
      cancelText: qcT('Annuler'),
      confirmText: qcT('Valider'),
      fieldLabelText: qcT('Date (JJ/MM/AAAA)'),
    );
    if (picked == null || !mounted) return;
    final before = _header.productionDate;
    setState(() => onPicked(qcIsoFromDate(picked)));
    if (_header.productionDate != before) _lookupProduction();
  }

  Future<void> _pickTime() async {
    final time = await _askTime(initial: _header.controlTime ?? '', help: 'Heure d\'ouverture');
    if (time == null || !mounted) return;
    setState(() => _header = _header.copyWith(controlTime: '$time:00'));
  }

  /// Champ cliquable (date / heure) : identifiable comme éditable (bordure,
  /// icône d'action), désactivé en consultation.
  Widget _pickerField({
    required IconData icon,
    required String label,
    required String value,
    required IconData actionIcon,
    required VoidCallback onTap,
    bool changed = false,
    bool invalid = false,
    bool? enabled,
    Key? key,
  }) {
    final active = enabled ?? _headerEditable;
    final border = invalid ? kCrmDanger : (changed ? kQualityControlColor : kCrmBorder);
    return Material(
      key: key,
      color: active ? kCrmSurface : kCrmBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: changed || invalid ? 1.4 : 1)),
          child: Row(children: [
            Icon(icon, size: 18, color: active ? kQualityControlColor : kCrmTextSub),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'À renseigner' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: value.isEmpty ? kCrmDanger : kCrmText)),
              ]),
            ),
            if (active) Icon(actionIcon, size: 18, color: kCrmTextSub),
          ]),
        ),
      ),
    );
  }

  Widget _posteField() {
    final legacy = _header.hasLegacyPoste;
    final current = legacy ? null : _header.poste;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: current != _baseHeader.poste && current != null ? kQualityControlColor : kCrmBorder),
    );
    IconData iconOf(String? v) => v == 'soir' ? Icons.nights_stay_outlined : Icons.wb_twilight_rounded;
    return DropdownButtonFormField<String>(
      // Clé locale (jamais une GlobalKey) : le champ reflète la valeur relue
      // en base après chaque chargement / sauvegarde.
      key: ValueKey('qc-poste-${widget.controlId}-$current'),
      initialValue: current,
      isExpanded: true,
      onChanged: _headerEditable
          ? (v) {
              if (v == _header.poste) return;
              setState(() => _header = _header.copyWith(poste: v));
              _lookupProduction();
            }
          : null,
      style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText),
      decoration: InputDecoration(
        isDense: true,
        labelText: qcT('Poste'),
        labelStyle: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub),
        helperText: legacy ? qcT('Valeur existante : ${qualityPosteLabel(_header.poste)} — choisir Matin ou Soir') : null,
        helperMaxLines: 2,
        helperStyle: tInter(fontSize: 11, color: kQcAVerifierText),
        prefixIcon: Icon(iconOf(current), size: 18, color: _headerEditable ? kQualityControlColor : kCrmTextSub),
        filled: true,
        fillColor: _headerEditable ? kCrmSurface : kCrmBg,
        border: border,
        enabledBorder: border,
      ),
      hint: Text('Sélectionner', style: tInter(fontSize: 13, color: kCrmTextSub)),
      items: [
        for (final (value, label) in kQualityPostes)
          DropdownMenuItem(
            value: value,
            child: Row(children: [
              Icon(iconOf(value), size: 16, color: kCrmTextSub),
              const SizedBox(width: 8),
              Text(label),
            ]),
          ),
      ],
    );
  }

  /// Lot / ordre de fabrication SAISI : uniquement quand la fiche de
  /// production ne le porte pas. Vide par défaut, lecture seule une fois la
  /// fiche validée.
  Widget _headerTextField({required String id, required IconData icon, required String label, required String hint, required TextEditingController ctrl, required String saved}) {
    final enabled = _headerEditable;
    final changed = ctrl.text.trim() != saved;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return TextField(
      key: ValueKey('qc-$id'),
      controller: ctrl,
      // Lecture seule (fiche validée / consultation) : texte lisible, non modifiable.
      readOnly: !enabled,
      canRequestFocus: enabled,
      maxLines: 1,
      inputFormatters: [LengthLimitingTextInputFormatter(kQcHeaderTextMax)],
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText),
      decoration: InputDecoration(
        isDense: true,
        labelText: qcT(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub),
        hintText: qcT(enabled ? hint : 'Non renseigné'),
        hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
        prefixIcon: Icon(icon, size: 18, color: enabled ? kQualityControlColor : kCrmTextSub),
        filled: true,
        fillColor: enabled ? kCrmSurface : kCrmBg,
        border: border(kCrmBorder),
        enabledBorder: border(changed ? kQualityControlColor : kCrmBorder, changed ? 1.4 : 1),
        disabledBorder: border(kCrmBorder),
        focusedBorder: border(kQualityControlColor, 1.4),
      ),
    );
  }

  /// Lot / ordre de fabrication repris de la fiche de production : lecture
  /// seule, marqué « Automatique » (la production elle-même n'est pas affichée).
  Widget _autoTile({required String id, required IconData icon, required String label, required String value}) => Container(
        key: ValueKey('qc-$id-auto'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(children: [
          Icon(icon, size: 18, color: kCrmTextSub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
            ]),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: qcT('Repris automatiquement de la fiche de production'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: kQualityControlColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.link_rounded, size: 12, color: kQualityControlColor),
                const SizedBox(width: 4),
                Text('Automatique', style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kQualityControlColor)),
              ]),
            ),
          ),
        ]),
      );

  /// Aucune fiche de production (ou plusieurs) pour la date et le poste :
  /// information discrète et NON bloquante.
  Widget _productionNotice(String text) => Padding(
        key: const ValueKey('qc-production-notice'),
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 15, color: kCrmTextSub)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: tInter(fontSize: 12, color: kCrmTextSub))),
        ]),
      );

  Widget _infoTile(IconData icon, String label, String value, {Widget? trailing}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(children: [
          Icon(icon, size: 18, color: kCrmTextSub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
              const SizedBox(height: 2),
              Text(value, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText), overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      );

  Widget _identificationSection(QualityControlModel c, Color color) {
    final autoLot = _autoLot;
    final fabrication = _fabrication;
    return QcSection(
      number: '01',
      icon: Icons.badge_outlined,
      title: 'Identification',
      subtitle: 'Ligne, machine et contrôleur fixés par la page · date, poste et ouverture modifiables · lot et fabrication repris automatiquement de la production',
      color: color,
      children: [
        qcGrid(columns: qcColumnsFor(210, max: 4), [
          _infoTile(kMachineIcon, 'Ligne · Machine', '${c.productionType} · ${c.machineLabel ?? '—'}'),
          // Date de production + poste : le serveur s'en sert pour associer la
          // fiche de production en arrière-plan (jamais affichée ici).
          _pickerField(
            icon: Icons.event_outlined,
            label: 'Date de production',
            value: qcIsoDateToDisplay(_header.productionDate),
            actionIcon: Icons.edit_calendar_outlined,
            changed: _header.productionDate != _baseHeader.productionDate,
            invalid: !qcIsValidIsoDate(_header.productionDate),
            onTap: () => _pickDate(
              current: _header.productionDate,
              help: 'Date de production',
              onPicked: (iso) => _header = _header.copyWith(productionDate: iso),
            ),
          ),
          _posteField(),
          _infoTile(Icons.person_outline_rounded, 'Contrôleur qualité', c.controllerEmail),
          if (autoLot != null)
            _autoTile(id: 'lot', icon: Icons.inventory_2_outlined, label: 'Lot de fabrication', value: autoLot)
          else
            _headerTextField(
              id: 'lot',
              icon: Icons.inventory_2_outlined,
              label: 'Lot de fabrication',
              hint: 'Non renseigné — saisie manuelle',
              ctrl: _lotCtrl,
              saved: c.lotAuto ? '' : _baseHeader.lot,
            ),
          // Fabrication contrôlée : identification automatique, jamais saisie.
          if (fabrication != null)
            _autoTile(id: 'manufacturing-order', icon: Icons.assignment_outlined, label: 'Ordre de fabrication', value: fabrication)
          else
            Container(
              key: const ValueKey('qc-manufacturing-order-empty'),
              child: _infoTile(Icons.assignment_outlined, 'Ordre de fabrication', 'Non renseigné'),
            ),
          _pickerField(
            icon: Icons.calendar_today_outlined,
            label: 'Ouvert le',
            value: qcIsoDateToDisplay(_header.controlDate),
            actionIcon: Icons.edit_calendar_outlined,
            changed: _header.controlDate != _baseHeader.controlDate,
            invalid: !qcIsValidIsoDate(_header.controlDate),
            onTap: () => _pickDate(
              current: _header.controlDate,
              help: 'Date d\'ouverture',
              onPicked: (iso) => _header = _header.copyWith(controlDate: iso),
            ),
          ),
          // Heure d'OUVERTURE de la fiche — distincte de l'heure de chaque
          // prélèvement, jamais remplacée par celle-ci.
          _pickerField(
            icon: Icons.schedule_rounded,
            label: 'Heure d\'ouverture',
            value: _header.controlTime ?? '',
            actionIcon: Icons.more_time_rounded,
            changed: _header.controlTime != _baseHeader.controlTime,
            invalid: !qcIsValidTime(_header.controlTime),
            onTap: _pickTime,
          ),
        ]),
        // PROMESH : la fiche qualité est indépendante de la production — aucune
        // fiche de production n'est attendue, donc aucun message. (L'association
        // éventuelle reste faite par le serveur, à titre informatif.) PROBAR :
        // comportement inchangé.
        if (!_readOnly && _match?.notice != null && c.productionType != 'PROMESH') _productionNotice(_match!.notice!),
      ],
    );
  }

  // ── 02 Prélèvements de contrôle (stepper horizontal) ────────────────────────

  Widget _stepsSection(QualityControlModel c, Color color) {
    final count = c.readings.length;
    return QcSection(
      number: '02',
      icon: Icons.timeline_rounded,
      title: 'Prélèvements de contrôle',
      subtitle: count == 0
          ? 'Étape 1 en cours de saisie — enregistrez-la pour ajouter le prélèvement suivant'
          : '$count étape${count > 1 ? 's' : ''} · cliquer sur une étape affiche son prélèvement ci-dessous · chaque prélèvement conserve ses propres valeurs',
      color: color,
      children: [
        QualityReadingStepper(
          readings: c.readings,
          selectedId: _readingId,
          pendingTime: _pending ? _readingTime : null,
          parameterCount: _form.parameters.length,
          color: color,
          busy: _saving,
          onOpen: _selectReading,
          onNew: _readOnly ? null : _newReading,
          newEnabled: !_pending,
          // Heure proposée = dernier prélèvement + 3 h (modifiable au clic).
          newHint: _readOnly ? null : (_pending ? 'après l\'étape 1' : 'proposé : ${c.suggestedNextReadingTime ?? '—'}'),
        ),
      ],
    );
  }

  // ── 03 Prélèvement actif ────────────────────────────────────────────────────

  int _readingIndex(QualityControlModel c) => _pending ? 0 : c.readings.indexWhere((r) => r.id == _readingId);

  /// Prélèvement précédent de la fiche (étape juste avant celle affichée).
  QualityReading? _previousReading(QualityControlModel c) {
    final i = _readingIndex(c);
    return i > 0 ? c.readings[i - 1] : null;
  }

  Widget _readingSection(QualityControlModel c, Color color) {
    final r = _reading;
    final index = _readingIndex(c);
    final total = _pending ? 1 : c.readings.length;
    final previous = _previousReading(c);
    final next = !_pending && index >= 0 && index < c.readings.length - 1 ? c.readings[index + 1] : null;
    Widget nav({required Key key, required QualityReading? target, required bool forward}) => OutlinedButton.icon(
          key: key,
          onPressed: target == null || _saving ? null : () => _selectReading(target),
          style: OutlinedButton.styleFrom(
            foregroundColor: kCrmText,
            side: const BorderSide(color: kCrmBorder),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          iconAlignment: forward ? IconAlignment.end : IconAlignment.start,
          icon: Icon(forward ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 16),
          label: Text(target?.readingTime ?? (forward ? 'Suivante' : 'Précédente')),
        );

    return QcSection(
      key: const ValueKey('qc-current-reading'),
      icon: Icons.fact_check_outlined,
      title: 'Prélèvement actuel — étape ${index + 1}',
      subtitle: r == null
          ? 'Étape 1 — non enregistrée'
          : r.isValidated
              ? 'Prélèvement validé le ${r.validatedDate ?? ''} à ${r.validatedTime ?? ''} — lecture seule'
              : 'Prélèvement brouillon — modifiable',
      color: color,
      trailing: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        nav(key: const ValueKey('qc-prev-reading'), target: previous, forward: false),
        Text('Étape ${index + 1} / $total', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmText)),
        nav(key: const ValueKey('qc-next-reading'), target: next, forward: true),
      ]),
      children: [
        qcGrid(columns: qcColumnsFor(210, max: 3), [
          _pickerField(
            key: const ValueKey('qc-reading-time'),
            icon: Icons.schedule_rounded,
            label: 'Heure du prélèvement',
            value: _readingTime,
            actionIcon: Icons.more_time_rounded,
            changed: _timeChanged,
            invalid: !qcIsValidReadingTime(_readingTime),
            enabled: !_readingLocked && !_saving,
            onTap: _pickReadingTime,
          ),
          _infoTile(Icons.flag_outlined, 'Statut', r != null && r.isValidated ? 'Validé' : 'Brouillon',
              trailing: QcStatusBadge(r != null && r.isValidated ? 'VALIDE' : 'BROUILLON', dense: true)),
          // Résultat : celui du prélèvement validé ; en saisie, celui qu'annoncent
          // les paramètres (un paramètre non conforme l'impose).
          _infoTile(Icons.check_circle_outline_rounded, 'Résultat', qualityResultLabel(_readingResult(r)),
              trailing: QcStatusBadge(_readingResult(r), dense: true)),
        ]),
        if (r != null && !_readingLocked)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: _saving ? null : _deleteReading,
                style: TextButton.styleFrom(foregroundColor: kCrmDanger, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Supprimer le prélèvement'),
              ),
            ),
          ),
      ],
    );
  }

  /// Résultat affiché du prélèvement actif.
  String _readingResult(QualityReading? r) {
    if (r != null && r.isValidated) return r.status;
    return _form.anyNonConforme ? 'NON_CONFORME' : 'EN_ATTENTE';
  }

  /// Titre des CONTRÔLES du prélèvement actuel (temporels) — à ne pas confondre
  /// avec les paramètres physiques de la fiche, affichés plus bas, à part.
  Widget _parametersHeading(QualityControlModel c, Color color) => Padding(
        key: const ValueKey('qc-parameters-heading'),
        padding: const EdgeInsets.only(bottom: 12, top: 2),
        child: Row(children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Flexible(
            child: Text('CONTRÔLES DU PRÉLÈVEMENT ${_readingIndex(c) + 1} — $_readingTime',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: 0.6)),
          ),
        ]),
      );

  // ── 04 Synthèse ────────────────────────────────────────────────────────

  Widget _summarySection(QualityControlModel c) {
    final readings = c.readings;
    final conformes = readings.where((r) => r.isValidated && r.status == 'CONFORME').length;
    final nonConformes = readings.where((r) => r.isValidated && r.status == 'NON_CONFORME').length;
    final aVerifier = readings.where((r) => !r.isValidated).length;
    final controlled = readings.fold<int>(0, (s, r) => s + r.controlledCount);
    final nc = readings.fold<int>(0, (s, r) => s + r.nonConformCount);
    // Résultat global : celui de la fiche validée ; sinon un prélèvement validé
    // non conforme l'annonce déjà, à défaut « à vérifier ».
    final specificNc = c.specificParameters.where((i) => i.status == 'NON_CONFORME').length;
    final global = c.isValidated ? c.status : (nonConformes > 0 || specificNc > 0 ? 'NON_CONFORME' : 'EN_ATTENTE');
    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: tInter(fontSize: 12.5, color: kCrmTextSub))),
            value,
          ]),
        );
    TextStyle strong([Color color = kCrmText]) => tInter(fontSize: 13, fontWeight: FontWeight.w800, color: color);

    return QcSection(
      number: _physicalParams.isEmpty && _specificParams.isEmpty ? '03' : '04',
      icon: Icons.insights_rounded,
      title: 'Synthèse',
      subtitle: c.isValidated
          ? 'Fiche validée le ${c.validatedDate ?? c.controlDate} à ${c.validatedTime ?? c.controlTime} par ${c.controllerEmail}'
          : 'Tous les prélèvements enregistrés de la fiche · « Valider le prélèvement » fige l\'étape affichée, « Valider le contrôle qualité » clôture la fiche',
      children: [
        qcGrid(columns: qcColumnsFor(170, max: 4), [
          QcKpiTile(icon: kQualityControlIcon, label: 'Fiche QC', value: '1', caption: c.reference.isEmpty ? 'non enregistrée' : c.reference),
          QcKpiTile(icon: Icons.format_list_numbered_rounded, label: 'Prélèvements', value: '${readings.length}', caption: c.lastReadingTime == null ? null : 'dernier : ${c.lastReadingTime}'),
          QcKpiTile(icon: Icons.checklist_rounded, label: 'Paramètres contrôlés', value: '$controlled', color: kCrmSuccess),
          QcKpiTile(icon: Icons.report_gmailerrorred_rounded, label: 'Non-conformités', value: '$nc', color: nc > 0 ? kCrmDanger : kCrmTextSub),
        ]),
        const SizedBox(height: 12),
        line('Prélèvements conformes', Text('$conformes', style: strong(conformes > 0 ? kQcConformeText : kCrmText))),
        line('Prélèvements non conformes', Text('$nonConformes', style: strong(nonConformes > 0 ? kQcNonConformeText : kCrmText))),
        line('Prélèvements à vérifier (brouillons)', Text('$aVerifier', style: strong(aVerifier > 0 ? kQcAVerifierText : kCrmText))),
        line('Résultat global', QcStatusBadge(global)),
        const SizedBox(height: 10),
        TextField(
          controller: _generalRemarkCtrl,
          enabled: !_readOnly && !_saving,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: qcT('Remarque générale sur la fiche (facultative)'),
            alignLabelWithHint: true,
            filled: true,
            fillColor: kCrmBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCrmBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCrmBorder)),
          ),
        ),
        if (_serverErrors.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kCrmDanger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kCrmDanger.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in _serverErrors) Text('• $e', style: tInter(fontSize: 12.5, color: kCrmDanger)),
            ]),
          ),
        if (c.isValidated)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              const Icon(Icons.lock_rounded, size: 16, color: kQcConformeText),
              const SizedBox(width: 8),
              Text('Contrôle qualité validé — Lecture seule', style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kQcConformeText)),
            ]),
          ),
      ],
    );
  }
}
