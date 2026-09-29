// lib/quality_control/model/quality_control_model.dart
//
// Module CONTRÔLE QUALITÉ — mirrors GET /quality-control(/:id) (backend :
// modules/quality-control/services/qualityControl.service.js#toControlResponse).
// Date/heure/contrôleur sont toujours ceux renvoyés par le serveur (heure de
// Tunisie) — jamais calculés côté Flutter.

class QualityParameter {
  final String key;
  final String label;
  final int position;
  final bool autoTime;

  const QualityParameter({required this.key, required this.label, required this.position, this.autoTime = false});

  factory QualityParameter.fromJson(Map<String, dynamic> j) => QualityParameter(
        key: j['key'].toString(),
        label: j['label'].toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        autoTime: j['autoTime'] == true,
      );
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
  'EN_ATTENTE': 'EN ATTENTE',
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

class QualityControlHistoryEntry {
  final String action;
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

class QualityControlModel {
  final String id;
  final String productionType; // PROMESH | PROBAR
  final String productionRecordRef; // "promesh:<uuid>" — GET /production-records/:id
  final String? ficheNumero;
  final String? machineLabel;
  final String? posteLabel;
  final String? productionDate; // yyyy-MM-dd
  final String controllerEmail;
  final String status;
  final String? remark;
  final bool isValidated;
  final String controlDate; // dd/MM/yyyy (Tunis)
  final String controlTime; // HH:mm:ss (Tunis)
  final int controlledCount;
  final int nonConformCount;
  final int totalCount;
  final List<String> nonConformParameters;
  final List<QualityControlItem> items;
  final List<QualityControlHistoryEntry> history;
  final int? notificationsSent;

  const QualityControlModel({
    required this.id,
    required this.productionType,
    required this.productionRecordRef,
    this.ficheNumero,
    this.machineLabel,
    this.posteLabel,
    this.productionDate,
    required this.controllerEmail,
    required this.status,
    this.remark,
    this.isValidated = false,
    this.controlDate = '',
    this.controlTime = '',
    this.controlledCount = 0,
    this.nonConformCount = 0,
    this.totalCount = 15,
    this.nonConformParameters = const [],
    this.items = const [],
    this.history = const [],
    this.notificationsSent,
  });

  factory QualityControlModel.fromJson(Map<String, dynamic> j) {
    final counts = j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : <String, dynamic>{};
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return QualityControlModel(
      id: j['id'].toString(),
      productionType: j['productionType']?.toString() ?? '',
      productionRecordRef: j['productionRecordRef']?.toString() ?? '',
      ficheNumero: j['ficheNumero']?.toString(),
      machineLabel: j['machineLabel']?.toString(),
      posteLabel: j['posteLabel']?.toString(),
      productionDate: j['productionDate']?.toString(),
      controllerEmail: j['controllerEmail']?.toString() ?? '',
      status: j['status']?.toString() ?? 'EN_ATTENTE',
      remark: j['remark']?.toString(),
      isValidated: j['isValidated'] == true,
      controlDate: j['controlDate']?.toString() ?? '',
      controlTime: j['controlTime']?.toString() ?? '',
      controlledCount: (counts['controlled'] as num?)?.toInt() ?? 0,
      nonConformCount: (counts['nonConformes'] as num?)?.toInt() ?? 0,
      totalCount: (counts['total'] as num?)?.toInt() ?? 15,
      nonConformParameters: (j['nonConformParameters'] as List? ?? []).map((e) => e.toString()).toList(),
      items: maps(j['items']).map(QualityControlItem.fromJson).toList(),
      history: maps(j['history']).map(QualityControlHistoryEntry.fromJson).toList(),
      notificationsSent: (j['notificationsSent'] as num?)?.toInt(),
    );
  }
}
