import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';

DioException _err(int status, Map<String, dynamic> body) {
  final ro = RequestOptions(path: '/por-promesh');
  return DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: ro, statusCode: status, data: body),
  );
}

void main() {
  test('PREVIOUS_PRODUCTION_MISSING (une date) -> message métier FR/EN (pas "DioException")', () {
    final e = _err(403, {
      'success': false,
      'code': 'PREVIOUS_PRODUCTION_MISSING',
      'missingDate': '2026-09-20',
      'missingDates': ['2026-09-20'],
      'requestedDate': '2026-09-21',
    });
    expect(ProductionComplianceService.friendlyError(e, fr: true), 'Fiche du 20/09/2026 manquante : 20/09/2026.\nDemandez une autorisation de régularisation.');
    expect(ProductionComplianceService.friendlyError(e, fr: false), contains('20/09/2026'));
    expect(ProductionComplianceService.friendlyError(e, fr: true), isNot(contains('DioException')));
  });

  test('PREVIOUS_PRODUCTION_MISSING (plusieurs dates) -> missingDates[] jamais tronqué à une seule', () {
    final e = _err(403, {
      'code': 'PREVIOUS_PRODUCTION_MISSING',
      'missingDate': '2026-09-18',
      'missingDates': ['2026-09-18', '2026-09-20', '2026-09-21'],
      'requestedDate': '2026-09-22',
    });
    final msgFr = ProductionComplianceService.friendlyError(e, fr: true);
    expect(msgFr, contains('3 fiches précédentes sont manquantes'));
    expect(msgFr, allOf(contains('18/09/2026'), contains('20/09/2026'), contains('21/09/2026')));
    final msgEn = ProductionComplianceService.friendlyError(e, fr: false);
    expect(msgEn, contains('3 previous sheets are missing'));
  });

  test('BACKFILL_NOT_AUTHORIZED -> date antérieure', () {
    final e = _err(403, {'code': 'BACKFILL_NOT_AUTHORIZED', 'requestedDate': '2026-09-20'});
    expect(ProductionComplianceService.friendlyError(e, fr: true), 'Cette date est antérieure (20/09/2026).\nUne autorisation de rattrapage est nécessaire.');
  });

  test('PERMISSION_DENIED / SHEET_LOCKED / NOT_OWNER / 403 sans code', () {
    expect(ProductionComplianceService.friendlyError(_err(403, {'code': 'PERMISSION_DENIED'}), fr: true), "Vous n'avez pas l'autorisation d'effectuer cette action.");
    expect(ProductionComplianceService.friendlyError(_err(403, {'code': 'SHEET_LOCKED'}), fr: true), contains('validée définitivement'));
    expect(ProductionComplianceService.friendlyError(_err(403, {'code': 'NOT_OWNER'}), fr: true), contains('autre utilisateur'));
    expect(ProductionComplianceService.friendlyError(_err(403, {'success': false}), fr: true), "Vous n'avez pas l'autorisation d'effectuer cette action.");
  });

  test('ProductionApiException expose le code et le corps pour le dialogue métier', () {
    final ex = ProductionApiException('x', code: 'PREVIOUS_PRODUCTION_MISSING', statusCode: 403, data: {'missingDate': '2026-09-20', 'production': 'PROD1'});
    expect(ex.needsAuthorization, isTrue);
    expect(ex.isMissingPreviousSheet, isTrue);
    expect(ex.isBackfillNotAuthorized, isFalse);
    expect(ex.data!['production'], 'PROD1');
    expect(ex.toString(), 'x');
    expect(ProductionComplianceService.isComplianceBlock(ex), isTrue);
  });
}
