// lib/quality_control/model/quality_control_model.dart
//
// Module CONTRÔLE QUALITÉ — mirrors GET /quality-control(/:id) (backend :
// modules/quality-control/services/qualityControl.service.js#toControlResponse).
// Date/heure/contrôleur sont toujours ceux renvoyés par le serveur (heure de
// Tunisie) — jamais calculés côté Flutter.

/// Choix prédéfini d'un paramètre (boutons). `tone` : ok | warn | nok.
class QualityOption {
  final String value;
  final String label;
  final String tone;

  const QualityOption({required this.value, required this.label, this.tone = 'ok'});

  factory QualityOption.fromJson(Map<String, dynamic> j) => QualityOption(
        value: j['value'].toString(),
        label: (j['label'] ?? j['value']).toString(),
        tone: j['tone']?.toString() ?? 'ok',
      );
}

/// Paramètre de la checklist + métadonnées d'affichage servies par le
/// backend (GET /quality-control/config) — jamais codées en dur ici.
class QualityParameter {
  final String key;
  final String label;
  final int position;
  final bool autoTime;
  final String section; // catégorie du prélèvement (voir QualityConfig.sections)
  final String kind; // number | text | choice | conformity (binaire, sans valeur)
  // 'reading' : contrôle TEMPOREL d'un prélèvement ; 'fiche' : PARAMÈTRE PHYSIQUE
  // de la fiche (indépendant du temps), pour les lignes [lines].
  final String scope;
  final List<String> lines;
  // Paramètre de niveau fiche portant un statut et une remarque (contrôle
  // spécifique des treillis GFRP).
  final bool withStatus;
  final String? unit;
  final String? hint;
  final List<QualityOption> options;
  // Présentation propre à une ligne (ex. PROMESH : catégorie, ordre et
  // libellé de la fiche de référence) — { 'PROMESH': {section, order, label} }.
  final Map<String, Map<String, dynamic>> byLine;
  // Rang dans la ligne (voir [forLine]) — null : ordre général ([position]).
  final int? order;
  // Sous-groupe d'affichage (ex. « VISCOSITÉ DE LA RÉSINE » : bain 1 / bain 2)
  // et libellé du champ dans ce groupe — null : paramètre hors groupe.
  final String? group;
  final String? shortLabel;

  const QualityParameter({
    required this.key,
    required this.label,
    required this.position,
    this.autoTime = false,
    this.section = 'machine',
    this.kind = 'text',
    this.scope = 'reading',
    this.lines = const ['PROMESH', 'PROBAR'],
    this.withStatus = false,
    this.unit,
    this.hint,
    this.options = const [],
    this.byLine = const {},
    this.order,
    this.group,
    this.shortLabel,
  });

  /// Le paramètre tel qu'il se présente pour [productionType] : catégorie,
  /// ordre et libellé de la ligne quand le backend en fournit.
  QualityParameter forLine(String productionType) {
    final v = byLine[productionType.toUpperCase()];
    if (v == null) return this;
    return QualityParameter(
      key: key,
      label: (v['label'] ?? label).toString(),
      position: position,
      autoTime: autoTime,
      section: (v['section'] ?? section).toString(),
      kind: kind,
      scope: scope,
      lines: lines,
      withStatus: withStatus,
      unit: unit,
      hint: hint,
      options: options,
      byLine: byLine,
      order: (v['order'] as num?)?.toInt(),
      group: group,
      shortLabel: shortLabel,
    );
  }

  factory QualityParameter.fromJson(Map<String, dynamic> j) => QualityParameter(
        key: j['key'].toString(),
        label: j['label'].toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        autoTime: j['autoTime'] == true,
        section: j['section']?.toString() ?? 'machine',
        kind: j['kind']?.toString() ?? 'text',
        scope: j['scope']?.toString() ?? 'reading',
        withStatus: j['withStatus'] == true,
        lines: j['lines'] is List ? (j['lines'] as List).map((e) => e.toString().toUpperCase()).toList() : const ['PROMESH', 'PROBAR'],
        unit: j['unit']?.toString(),
        hint: j['hint']?.toString(),
        group: j['group']?.toString(),
        shortLabel: j['shortLabel']?.toString(),
        byLine: {
          for (final e in (j['byLine'] is Map ? j['byLine'] as Map : const {}).entries)
            if (e.value is Map) e.key.toString().toUpperCase(): Map<String, dynamic>.from(e.value as Map),
        },
        options: (j['options'] as List? ?? [])
            .whereType<Map>()
            .map((o) => QualityOption.fromJson(Map<String, dynamic>.from(o)))
            .toList(),
      );
}

/// Ligne de production contrôlable et ses machines (mêmes machines que le
/// module Production — servies par le backend).
class QualityProductionLine {
  final String type; // PROMESH | PROBAR
  final String label;
  final List<String> machines;

  const QualityProductionLine({required this.type, required this.label, required this.machines});

  factory QualityProductionLine.fromJson(Map<String, dynamic> j) => QualityProductionLine(
        type: j['type'].toString(),
        label: (j['label'] ?? j['type']).toString(),
        machines: (j['machines'] as List? ?? []).map((m) => m.toString()).toList(),
      );
}

/// Catégorie de paramètres du formulaire d'un prélèvement (ordre du backend).
class QualitySection {
  final String key;
  final String label;
  // 'reading' : catégorie d'un prélèvement ; 'fiche' : bloc de niveau fiche.
  final String scope;
  // Bloc de niveau fiche : 'physique' ou 'treillis' (contrôle spécifique).
  final String? group;
  const QualitySection({required this.key, required this.label, this.scope = 'reading', this.group});

  factory QualitySection.fromJson(Map<String, dynamic> j) => QualitySection(
        key: j['key'].toString(),
        label: (j['label'] ?? j['key']).toString(),
        scope: j['scope']?.toString() ?? 'reading',
        group: j['group']?.toString(),
      );
}

class QualityConfig {
  final List<QualityParameter> parameters;
  final List<QualitySection> sections;
  final List<QualityProductionLine> productionLines;
  // Cadence RECOMMANDÉE entre deux prélèvements (suggestion, jamais imposée).
  final int readingIntervalMinutes;
  // Machines qui ont leur PROPRE liste de paramètres (ex. PROMESH 4) :
  // 'TYPE:machine' → clé de liste utilisée dans `lines` / `byLine`.
  final Map<String, String> machineLines;

  const QualityConfig({
    this.parameters = const [],
    this.sections = const [],
    this.productionLines = const [],
    this.readingIntervalMinutes = 180,
    this.machineLines = const {},
  });

  factory QualityConfig.fromJson(Map<String, dynamic> j) => QualityConfig(
        parameters: (j['parameters'] as List? ?? [])
            .whereType<Map>()
            .map((m) => QualityParameter.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        sections: (j['sections'] as List? ?? [])
            .whereType<Map>()
            .map((m) => QualitySection.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        readingIntervalMinutes: (j['readingIntervalMinutes'] as num?)?.toInt() ?? 180,
        machineLines: {
          for (final m in (j['machineLines'] as List? ?? []).whereType<Map>())
            '${m['type'].toString().toUpperCase()}:${m['machine']}': m['key'].toString().toUpperCase(),
        },
        productionLines: (j['productionLines'] as List? ?? [])
            .whereType<Map>()
            .map((m) => QualityProductionLine.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  QualityProductionLine? line(String type) {
    for (final l in productionLines) {
      if (l.type.toUpperCase() == type.toUpperCase()) return l;
    }
    return null;
  }

  /// Clé de la liste de paramètres d'une fiche : celle de sa MACHINE quand
  /// elle a sa propre liste (PROMESH 4), sinon celle de sa ligne. À passer
  /// aux méthodes `…For(productionType)` ci-dessous.
  String lineKey(String productionType, String? machine) {
    final type = productionType.toUpperCase();
    return machineLines['$type:${(machine ?? '').trim()}'] ?? type;
  }

  QualityParameter? parameter(String key) {
    for (final p in parameters) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// Contrôles TEMPORELS d'un prélèvement (mêmes paramètres pour chaque prélèvement).
  List<QualityParameter> get readingParameters =>
      parameters.where((p) => p.scope == 'reading').toList()..sort((a, b) => a.position.compareTo(b.position));

  /// PARAMÈTRES PHYSIQUES de la fiche pour une ligne (PROMESH / PROBAR) :
  /// indépendants du temps, jamais dans un prélèvement.
  List<QualityParameter> physicalParameters(String productionType) =>
      ficheParameters(productionType).where((p) => p.section == 'physique').toList();

  /// Contrôles d'un prélèvement pour UNE ligne : PROMESH (treillis) ne reçoit
  /// jamais les contrôles propres aux barres (PROBAR).
  /// Catégorie, ordre et libellé : ceux de la ligne (PROMESH : les 13
  /// paramètres de la fiche de référence, dans son ordre).
  List<QualityParameter> readingParametersFor(String productionType) =>
      readingParameters.where((p) => p.lines.contains(productionType.toUpperCase())).map((p) => p.forLine(productionType)).toList()
        ..sort((a, b) => (a.order ?? a.position).compareTo(b.order ?? b.position));

  /// Paramètres de niveau FICHE d'une ligne (indépendants des prélèvements).
  /// Libellé et ordre : ceux de la liste quand le backend en fournit (PROMESH 4).
  List<QualityParameter> ficheParameters(String productionType) =>
      parameters.where((p) => p.scope == 'fiche' && p.lines.contains(productionType.toUpperCase())).map((p) => p.forLine(productionType)).toList()
        ..sort((a, b) => (a.order ?? a.position).compareTo(b.order ?? b.position));

  /// CONTRÔLE SPÉCIFIQUE de la ligne (PROMESH : treillis GFRP ; PROBAR :
  /// aucun) — niveau fiche, chaque paramètre avec statut et remarque.
  List<QualityParameter> specificParameters(String productionType) =>
      ficheParameters(productionType).where((p) => p.section != 'physique').toList();

  /// Sous-sections du contrôle spécifique d'une ligne (Géométrie,
  /// …), dans l'ordre du backend — seulement celles qui ont des paramètres.
  List<QualitySection> specificSections(String productionType) {
    final used = specificParameters(productionType).map((p) => p.section).toSet();
    return sections.where((s) => used.contains(s.key)).toList();
  }

  /// Catégories AFFICHÉES d'un prélèvement, dans l'ordre : celles du backend qui
  /// portent au moins un contrôle qualité, puis toute catégorie non déclarée.
  List<QualitySection> get visibleSections => visibleSectionsFor(null);

  /// Catégories d'un prélèvement pour une ligne (`null` : toutes lignes).
  List<QualitySection> visibleSectionsFor(String? productionType) {
    // Toutes lignes : chaque paramètre dans la catégorie de chacune de ses lignes.
    final parameters = productionType == null ? [for (final l in productionLines) ...readingParametersFor(l.type)] : readingParametersFor(productionType);
    final used = parameters.map((p) => p.section).toSet();
    final declared = sections.where((s) => used.contains(s.key)).toList();
    final known = declared.map((s) => s.key).toSet();
    final extra = <String>[];
    for (final p in parameters) {
      if (!known.contains(p.section) && !extra.contains(p.section)) extra.add(p.section);
    }
    return [...declared, for (final k in extra) QualitySection(key: k, label: k)];
  }

  List<QualityParameter> parametersOf(String section, {String? productionType}) =>
      (productionType == null ? readingParameters : readingParametersFor(productionType)).where((p) => p.section == section).toList();
}

// Statuts d'un paramètre — valeurs backend + libellés affichés.
const kItemStatuses = ['CONFORME', 'NON_CONFORME', 'NON_CONTROLE'];
const kItemStatusLabels = {
  'CONFORME': 'Conforme',
  'NON_CONFORME': 'Non conforme',
  'NON_CONTROLE': 'Non contrôlé',
};

// Statuts globaux du contrôle.
const kControlStatusLabels = {
  'EN_ATTENTE': 'À VÉRIFIER',
  'EN_COURS': 'EN COURS',
  'CONFORME': 'CONFORME',
  'NON_CONFORME': 'NON CONFORME',
};

class QualityControlItem {
  final String parameterKey;
  final String parameterName;
  final int position;
  final bool autoTime;
  final String? value;
  final String status;
  final String? remark;
  final String? checkedAt;
  final String? checkedByEmail;

  const QualityControlItem({
    required this.parameterKey,
    required this.parameterName,
    required this.position,
    this.autoTime = false,
    this.value,
    this.status = 'NON_CONTROLE',
    this.remark,
    this.checkedAt,
    this.checkedByEmail,
  });

  factory QualityControlItem.fromJson(Map<String, dynamic> j) => QualityControlItem(
        parameterKey: j['parameterKey'].toString(),
        parameterName: j['parameterName'].toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        autoTime: j['autoTime'] == true,
        value: j['value']?.toString(),
        status: j['status']?.toString() ?? 'NON_CONTROLE',
        remark: j['remark']?.toString(),
        checkedAt: j['checkedAt']?.toString(),
        checkedByEmail: j['checkedByEmail']?.toString(),
      );
}

// ── Prélèvements d'une fiche ──────────────────────────────────────────────────

bool qcIsValidReadingTime(String? v) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v ?? '');

/// "08:00" + 180 min → "11:00" (au-delà de minuit : retour à 00:00+).
String qcAddMinutes(String hhmm, int minutes) {
  final p = hhmm.split(':');
  final total = ((int.parse(p[0]) * 60 + int.parse(p[1]) + minutes) % 1440 + 1440) % 1440;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

/// PRÉLÈVEMENT périodique d'une fiche : une heure de contrôle + ses paramètres.
/// Brouillon (modifiable) tant que `isValidated` est faux.
class QualityReading {
  final String id;
  final int step; // étape affichée : 1, 2, 3… (sans trou)
  final int sequence; // rang stocké (dernier rang + 1) — jamais l'heure
  final String readingTime; // HH:mm — heure du contrôle
  final String status; // EN_ATTENTE | EN_COURS | CONFORME | NON_CONFORME
  final bool isValidated;
  final String? validatedDate;
  final String? validatedTime;
  final int controlledCount;
  final int nonConformCount;
  final int totalCount;
  final List<String> nonConformParameters;
  final List<QualityControlItem> items; // vide dans les listes

  const QualityReading({
    required this.id,
    required this.readingTime,
    this.step = 1,
    this.sequence = 1,
    this.status = 'EN_ATTENTE',
    this.isValidated = false,
    this.validatedDate,
    this.validatedTime,
    this.controlledCount = 0,
    this.nonConformCount = 0,
    this.totalCount = 0,
    this.nonConformParameters = const [],
    this.items = const [],
  });

  factory QualityReading.fromJson(Map<String, dynamic> j) {
    final counts = j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : <String, dynamic>{};
    return QualityReading(
      id: j['id'].toString(),
      step: (j['step'] as num?)?.toInt() ?? 1,
      sequence: (j['sequence'] as num?)?.toInt() ?? 1,
      readingTime: j['readingTime']?.toString() ?? '',
      status: j['status']?.toString() ?? 'EN_ATTENTE',
      isValidated: j['isValidated'] == true,
      validatedDate: j['validatedDate']?.toString(),
      validatedTime: j['validatedTime']?.toString(),
      controlledCount: (counts['controlled'] as num?)?.toInt() ?? 0,
      nonConformCount: (counts['nonConformes'] as num?)?.toInt() ?? 0,
      totalCount: (counts['total'] as num?)?.toInt() ?? 0,
      nonConformParameters: (j['nonConformParameters'] as List? ?? []).map((e) => e.toString()).toList(),
      items: (j['items'] as List? ?? []).whereType<Map>().map((e) => QualityControlItem.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  /// Statut affiché : résultat une fois validé, sinon brouillon.
  String get badge => isValidated ? status : 'BROUILLON';

  /// Valeur enregistrée d'un paramètre ('' si non saisie).
  String valueOf(String parameterKey) {
    for (final i in items) {
      if (i.parameterKey == parameterKey) return i.value ?? '';
    }
    return '';
  }
}

class QualityControlHistoryEntry {
  final String action;
  final String? readingTime; // prélèvement concerné (null : action sur la fiche)
  final String? parameterName;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String? userEmail;
  final String changedDate;
  final String changedTime;

  const QualityControlHistoryEntry({
    required this.action,
    this.readingTime,
    this.parameterName,
    this.field,
    this.oldValue,
    this.newValue,
    this.reason,
    this.userEmail,
    this.changedDate = '',
    this.changedTime = '',
  });

  factory QualityControlHistoryEntry.fromJson(Map<String, dynamic> j) => QualityControlHistoryEntry(
        action: j['action'].toString(),
        readingTime: j['readingTime']?.toString(),
        parameterName: j['parameterName']?.toString(),
        field: j['field']?.toString(),
        oldValue: j['oldValue']?.toString(),
        newValue: j['newValue']?.toString(),
        reason: j['reason']?.toString(),
        userEmail: j['userEmail']?.toString(),
        changedDate: j['changedDate']?.toString() ?? '',
        changedTime: j['changedTime']?.toString() ?? '',
      );
}

/// Résultat affiché : Conforme / Non conforme une fois validé, sinon
/// "À vérifier" (contrôle ouvert, EN_ATTENTE ou EN_COURS côté backend).
String qualityResultLabel(String status) => switch (status) {
      'CONFORME' => 'Conforme',
      'NON_CONFORME' => 'Non conforme',
      _ => 'À vérifier',
    };

class QualityControlModel {
  final String id;
  final String reference; // QC-AAAA-NNNNN — référence de la fiche qualité
  final String productionType; // PROMESH | PROBAR
  // Production associée (OPTIONNELLE) : "promesh:<uuid>" — null sans production.
  final String? productionRecordRef;
  final String? ficheNumero;
  final String? machine;
  final String? machineLabel;
  final String? posteLabel;
  final String? poste; // valeur stockée : matin | soir (anciennes : nuit…)
  final String? productionDate; // yyyy-MM-dd
  final String? lot; // null = vide
  final String? manufacturingOrder; // ordre de fabrication
  // true : valeur reprise de la fiche de production (lecture seule).
  final bool lotAuto;
  final bool manufacturingOrderAuto;
  final String controllerEmail;
  final String status;
  final String? remark;
  final bool isValidated;
  final String controlDate; // dd/MM/yyyy (Tunis)
  final String controlTime; // HH:mm:ss (Tunis)
  final String? validatedDate; // dd/MM/yyyy — horodatage serveur de la validation
  final String? validatedTime; // HH:mm:ss
  final int controlledCount;
  final int nonConformCount;
  final int totalCount;
  final List<String> nonConformParameters;
  final List<QualityControlItem> items; // paramètres du DERNIER prélèvement (détail)
  // PARAMÈTRES PHYSIQUES de la fiche (une seule fois, hors des prélèvements).
  final List<QualityControlItem> physicalParameters;
  // CONTRÔLE SPÉCIFIQUE de la fiche (PROMESH : treillis GFRP), hors des prélèvements.
  final List<QualityControlItem> specificParameters;
  // Prélèvements de la fiche, dans l'ordre chronologique (paramètres : détail seul).
  final List<QualityReading> readings;
  final int readingsCount;
  final String? lastReadingTime; // HH:mm
  final String? suggestedNextReadingTime; // dernier prélèvement + cadence (3 h)
  // Après une sauvegarde : prélèvement créé / modifié par la requête.
  final String? readingId;
  final List<QualityControlHistoryEntry> history;
  final int? notificationsSent;

  const QualityControlModel({
    required this.id,
    this.reference = '',
    required this.productionType,
    this.productionRecordRef,
    this.ficheNumero,
    this.machine,
    this.machineLabel,
    this.posteLabel,
    this.poste,
    this.productionDate,
    this.lot,
    this.manufacturingOrder,
    this.lotAuto = false,
    this.manufacturingOrderAuto = false,
    required this.controllerEmail,
    required this.status,
    this.remark,
    this.isValidated = false,
    this.controlDate = '',
    this.controlTime = '',
    this.validatedDate,
    this.validatedTime,
    this.controlledCount = 0,
    this.nonConformCount = 0,
    this.totalCount = 15,
    this.nonConformParameters = const [],
    this.items = const [],
    this.physicalParameters = const [],
    this.specificParameters = const [],
    this.readings = const [],
    this.readingsCount = 0,
    this.lastReadingTime,
    this.suggestedNextReadingTime,
    this.readingId,
    this.history = const [],
    this.notificationsSent,
  });

  QualityReading? reading(String? id) {
    for (final r in readings) {
      if (r.id == id) return r;
    }
    return null;
  }

  factory QualityControlModel.fromJson(Map<String, dynamic> j) {
    final counts = j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : <String, dynamic>{};
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return QualityControlModel(
      id: j['id'].toString(),
      productionType: j['productionType']?.toString() ?? '',
      reference: j['reference']?.toString() ?? '',
      productionRecordRef: (j['productionRecordRef']?.toString() ?? '').isEmpty ? null : j['productionRecordRef'].toString(),
      ficheNumero: j['ficheNumero']?.toString(),
      machine: j['machine']?.toString(),
      machineLabel: j['machineLabel']?.toString(),
      posteLabel: j['posteLabel']?.toString(),
      poste: j['poste']?.toString(),
      productionDate: j['productionDate']?.toString(),
      lot: j['lot']?.toString(),
      manufacturingOrder: j['manufacturingOrder']?.toString(),
      lotAuto: j['lotAuto'] == true,
      manufacturingOrderAuto: j['manufacturingOrderAuto'] == true,
      controllerEmail: j['controllerEmail']?.toString() ?? '',
      status: j['status']?.toString() ?? 'EN_ATTENTE',
      remark: j['remark']?.toString(),
      isValidated: j['isValidated'] == true,
      controlDate: j['controlDate']?.toString() ?? '',
      controlTime: j['controlTime']?.toString() ?? '',
      validatedDate: j['validatedDate']?.toString(),
      validatedTime: j['validatedTime']?.toString(),
      controlledCount: (counts['controlled'] as num?)?.toInt() ?? 0,
      nonConformCount: (counts['nonConformes'] as num?)?.toInt() ?? 0,
      totalCount: (counts['total'] as num?)?.toInt() ?? 15,
      nonConformParameters: (j['nonConformParameters'] as List? ?? []).map((e) => e.toString()).toList(),
      items: maps(j['items']).map(QualityControlItem.fromJson).toList(),
      physicalParameters: maps(j['physicalParameters']).map(QualityControlItem.fromJson).toList(),
      specificParameters: maps(j['specificParameters']).map(QualityControlItem.fromJson).toList(),
      readings: maps(j['readings']).map(QualityReading.fromJson).toList(),
      readingsCount: (j['readingsCount'] as num?)?.toInt() ?? maps(j['readings']).length,
      lastReadingTime: j['lastReadingTime']?.toString(),
      suggestedNextReadingTime: j['suggestedNextReadingTime']?.toString(),
      readingId: j['readingId']?.toString(),
      history: maps(j['history']).map(QualityControlHistoryEntry.fromJson).toList(),
      notificationsSent: (j['notificationsSent'] as num?)?.toInt(),
    );
  }
}

// ── En-tête modifiable du contrôle ───────────────────────────────────────

/// Postes autorisés (valeur stockée, libellé) — liste déroulante.
const kQualityPostes = <(String, String)>[('matin', 'Matin'), ('soir', 'Soir')];

String? qualityPosteLabel(String? v) {
  for (final (value, label) in kQualityPostes) {
    if (value == v) return label;
  }
  return v == null || v.isEmpty ? null : v[0].toUpperCase() + v.substring(1);
}

bool qcIsValidIsoDate(String? v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v ?? '');
  if (m == null) return false;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

bool qcIsValidTime(String? v) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$').hasMatch(v ?? '');

/// "30/09/2026" → "2026-09-30" (null si invalide).
String? qcDisplayDateToIso(String? display) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(display ?? '');
  if (m == null) return null;
  final iso = '${m[3]}-${m[2]}-${m[1]}';
  return qcIsValidIsoDate(iso) ? iso : null;
}

/// "2026-09-30" → "30/09/2026" ("" si invalide).
String qcIsoDateToDisplay(String? iso) {
  if (iso == null || iso.length < 10 || !qcIsValidIsoDate(iso.substring(0, 10))) return '';
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
}

String qcIsoFromDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? qcDateFromIso(String? iso) => qcIsValidIsoDate(iso) ? DateTime.parse(iso!) : null;

/// Champs d'en-tête modifiables (date / heure d'ouverture, date de
/// production, poste, lot, ordre de fabrication) — valeurs au format API
/// (AAAA-MM-JJ, HH:mm:ss, texte libre). Construit depuis la réponse de l'API
/// (jamais dans build()) ; seuls les champs MODIFIÉS sont envoyés — aucune
/// valeur existante réinitialisée.
class QualityControlHeader {
  final String? controlDate;
  final String? controlTime;
  final String? productionDate;
  final String? poste;
  final String lot; // '' = vide
  final String manufacturingOrder;

  const QualityControlHeader({this.controlDate, this.controlTime, this.productionDate, this.poste, this.lot = '', this.manufacturingOrder = ''});

  factory QualityControlHeader.fromControl(QualityControlModel c) => QualityControlHeader(
        controlDate: qcDisplayDateToIso(c.controlDate),
        controlTime: qcIsValidTime(c.controlTime) ? c.controlTime : null,
        productionDate: c.productionDate != null && c.productionDate!.length >= 10 ? c.productionDate!.substring(0, 10) : null,
        poste: c.poste,
        lot: (c.lot ?? '').trim(),
        manufacturingOrder: (c.manufacturingOrder ?? '').trim(),
      );

  QualityControlHeader copyWith({String? controlDate, String? controlTime, String? productionDate, String? poste, String? lot, String? manufacturingOrder}) =>
      QualityControlHeader(
        controlDate: controlDate ?? this.controlDate,
        controlTime: controlTime ?? this.controlTime,
        productionDate: productionDate ?? this.productionDate,
        poste: poste ?? this.poste,
        lot: (lot ?? this.lot).trim(),
        manufacturingOrder: (manufacturingOrder ?? this.manufacturingOrder).trim(),
      );

  /// Critères de la recherche automatique de la fiche de production : date
  /// de production valide + poste Matin / Soir (ligne et machine = la page).
  bool get canMatchProduction => qcIsValidIsoDate(productionDate) && poste != null && !hasLegacyPoste;

  /// Poste hors liste Matin / Soir (ancienne valeur copiée de la fiche) :
  /// conservée telle quelle tant que l'utilisateur ne choisit pas.
  bool get hasLegacyPoste => poste != null && poste!.isNotEmpty && !kQualityPostes.any((p) => p.$1 == poste);

  /// Champs modifiés par rapport à [original] (payload PUT / validate).
  Map<String, String> diff(QualityControlHeader original) => {
        if (controlDate != null && controlDate != original.controlDate) 'controlDate': controlDate!,
        if (controlTime != null && controlTime != original.controlTime) 'controlTime': controlTime!,
        if (productionDate != null && productionDate != original.productionDate) 'productionDate': productionDate!,
        if (poste != null && poste != original.poste && !hasLegacyPoste) 'poste': poste!,
        // Texte libre : '' envoyé pour VIDER une valeur enregistrée.
        if (lot != original.lot) 'lot': lot,
        if (manufacturingOrder != original.manufacturingOrder) 'manufacturingOrder': manufacturingOrder,
      };

  /// Mêmes règles que le backend (validator + collectHeaderErrors).
  List<String> errors() => [
        if (!qcIsValidIsoDate(controlDate)) "Date d'ouverture : date valide obligatoire.",
        if (!qcIsValidTime(controlTime)) "Heure d'ouverture : heure valide obligatoire.",
        if (!qcIsValidIsoDate(productionDate)) 'Date de production : date valide obligatoire.',
      ];
}

// ── Recherche automatique de la fiche de production ──────────────────────

/// Longueur maximale de Lot / Ordre de fabrication (même règle que l'API).
const kQcHeaderTextMax = 100;

/// État de GET /quality-control/production-match : SI une fiche de
/// production unique correspond (ligne + machine + date de production +
/// poste), avec le lot et l'ordre de fabrication qu'elle porte.
/// L'association elle-même est faite par le serveur à la sauvegarde et la
/// fiche de production n'est jamais affichée.
class QcProductionMatch {
  final bool matched;
  final String? reason; // NO_PRODUCTION_SHEET | MULTIPLE_PRODUCTION_SHEETS
  final String? lot; // lot de fabrication de la production (null : non renseigné)
  final String? manufacturingOrder;

  const QcProductionMatch({required this.matched, this.reason, this.lot, this.manufacturingOrder});

  static String? _text(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

  factory QcProductionMatch.fromJson(Map<String, dynamic> j) => QcProductionMatch(
        matched: j['matched'] == true,
        reason: j['reason']?.toString(),
        lot: _text(j['lot']),
        manufacturingOrder: _text(j['manufacturingOrder']),
      );

  /// Message NON bloquant de l'écran — null quand une fiche correspond.
  String? get notice {
    if (matched) return null;
    if (reason == 'MULTIPLE_PRODUCTION_SHEETS') {
      return 'Plusieurs fiches de production correspondent à cette date et ce poste : aucune association automatique. '
          'Le contrôle qualité peut néanmoins être enregistré.';
    }
    return 'Aucune fiche de production correspondante trouvée. Le contrôle qualité peut néanmoins être enregistré.';
  }
}

// ── Tableau de bord (GET /quality-control/stats?period=) ────────────────

/// Périodes du filtre "Statistiques générales" (valeur backend, libellé).
// Période calculée sur la date DU CONTRÔLE (ouverture) côté backend.
const kQualityStatsPeriods = <(String, String)>[
  ('today', "Aujourd'hui"),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('year', 'Cette année'),
  ('all', 'Tout'),
];

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Compteurs par statut (total = conformes + non conformes + à vérifier).
/// `releves` est compté À PART : une fiche à 3 prélèvements reste UN contrôle.
class QualityCounts {
  final int total;
  final int conforme;
  final int nonConforme;
  final int aVerifier;
  final int releves;

  const QualityCounts({this.total = 0, this.conforme = 0, this.nonConforme = 0, this.aVerifier = 0, this.releves = 0});

  factory QualityCounts.fromJson(Map<String, dynamic> j) => QualityCounts(
        releves: _int(j['releves']),
        total: _int(j['total']),
        conforme: _int(j['conforme']),
        nonConforme: _int(j['nonConforme']),
        aVerifier: _int(j['aVerifier']),
      );

  /// Taux de conformité sur les contrôles VALIDÉS (null si aucun).
  double? get conformityRate {
    final decided = conforme + nonConforme;
    return decided == 0 ? null : conforme / decided;
  }
}

class QualityLastControl {
  final String id;
  final String reference;
  final bool isValidated;
  final String status;
  final String? ficheNumero;
  final String controlDate; // dd/MM/yyyy (Tunis)
  final String controlTime; // HH:mm (Tunis)

  const QualityLastControl({
    required this.id,
    required this.status,
    this.reference = '',
    this.isValidated = true,
    this.ficheNumero,
    this.controlDate = '',
    this.controlTime = '',
  });

  factory QualityLastControl.fromJson(Map<String, dynamic> j) => QualityLastControl(
        id: j['id'].toString(),
        reference: j['reference']?.toString() ?? '',
        isValidated: j['isValidated'] != false,
        status: j['status']?.toString() ?? 'EN_ATTENTE',
        ficheNumero: j['ficheNumero']?.toString(),
        controlDate: j['controlDate']?.toString() ?? '',
        controlTime: j['controlTime']?.toString() ?? '',
      );
}

class QualityMachineStats {
  final String machine;
  final String label;
  final QualityCounts counts;
  final QualityLastControl? lastControl; // toutes périodes confondues

  const QualityMachineStats({required this.machine, required this.label, this.counts = const QualityCounts(), this.lastControl});

  factory QualityMachineStats.fromJson(Map<String, dynamic> j) => QualityMachineStats(
        machine: j['machine'].toString(),
        label: (j['label'] ?? 'Machine ${j['machine']}').toString(),
        counts: QualityCounts.fromJson(j),
        lastControl: j['lastControl'] is Map ? QualityLastControl.fromJson(Map<String, dynamic>.from(j['lastControl'] as Map)) : null,
      );
}

class QualityLineStats {
  final String type;
  final String label;
  final QualityCounts counts;
  final List<QualityMachineStats> machines;

  const QualityLineStats({required this.type, required this.label, this.counts = const QualityCounts(), this.machines = const []});

  factory QualityLineStats.fromJson(Map<String, dynamic> j) => QualityLineStats(
        type: j['type'].toString(),
        label: (j['label'] ?? j['type']).toString(),
        counts: QualityCounts.fromJson(j),
        machines: (j['machines'] as List? ?? [])
            .whereType<Map>()
            .map((m) => QualityMachineStats.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  QualityMachineStats? machine(String m) {
    for (final s in machines) {
      if (s.machine == m) return s;
    }
    return null;
  }
}

class QualityStats {
  final String period;
  final String? from; // AAAA-MM-JJ (null = toutes périodes)
  final QualityCounts totals;
  final int machines;
  final int machinesActives;
  final List<QualityLineStats> lines;

  const QualityStats({
    this.period = 'month',
    this.from,
    this.totals = const QualityCounts(),
    this.machines = 0,
    this.machinesActives = 0,
    this.lines = const [],
  });

  factory QualityStats.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] is Map ? Map<String, dynamic>.from(j['totals'] as Map) : <String, dynamic>{};
    return QualityStats(
      period: j['period']?.toString() ?? 'month',
      from: j['from']?.toString(),
      totals: QualityCounts.fromJson(totals),
      machines: _int(totals['machines']),
      machinesActives: _int(totals['machinesActives']),
      lines: (j['lines'] as List? ?? [])
          .whereType<Map>()
          .map((m) => QualityLineStats.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  QualityLineStats? line(String type) {
    for (final l in lines) {
      if (l.type.toUpperCase() == type.toUpperCase()) return l;
    }
    return null;
  }
}

/// Page de l'historique (GET /quality-control — data + pagination).
class QualityControlPage {
  final List<QualityControlModel> items;
  final int page;
  final int totalPages;
  final int total;

  const QualityControlPage({this.items = const [], this.page = 1, this.totalPages = 1, this.total = 0});
}
