// lib/forms/raw_material_request/raw_material_request_login_prompt.dart
//
// Popup « Demande de matières premières » affichée automatiquement à la
// connexion de production_1@cbi-tunisia.com, le VENDREDI uniquement (jour et
// heure du serveur), tant que la demande de ce vendredi n'est pas soumise. Déclenchée par AppShell une fois la session authentifiée et la
// navigation prête (premier écran affiché après la connexion).
//
// Une seule fois par session : le marqueur est l'identifiant de session
// (AuthService.sessionId), nouveau à chaque connexion et conservé à
// l'actualisation. Si la page est actualisée pendant que la popup est
// ouverte, elle réapparaît (la session n'a pas encore été traitée).
//
// Le poste n'est pas encore choisi dans l'interface à la connexion : le
// backend le déduit des horaires de production du compte et décide seul si
// la demande est exigée (aussi : pas de 2e popup si une demande déjà validée
// attend d'être utilisée).

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import 'raw_material_request_dialog.dart';
import 'raw_material_request_paths.dart';
import 'raw_material_request_service.dart';

/// Comptes pour lesquels la vérification est lancée à la connexion. Le
/// backend reste seul juge (config/rawMaterialRequest.js) ; ce filtre évite
/// seulement tout appel réseau pour les autres comptes.
const kRawMaterialLoginEmails = {'production_1@cbi-tunisia.com'};

String normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

/// Marqueur « popup déjà traitée pour cette session ».
abstract class RawMaterialPromptStore {
  String? read();
  Future<void> write(String sessionId);
}

/// Marqueur en GetStorage ; une clé par popup (connexion du demandeur,
/// demandes en attente du responsable).
class GetStorageRawMaterialPromptStore implements RawMaterialPromptStore {
  final String key;
  const GetStorageRawMaterialPromptStore([this.key = 'rawMaterialLoginPromptSession']);
  @override
  String? read() => GetStorage().read<String>(key);
  @override
  Future<void> write(String sessionId) => GetStorage().write(key, sessionId);
}

class RawMaterialLoginPrompt {
  RawMaterialLoginPrompt._();

  // Session en cours de traitement : évite deux popups simultanées quand
  // l'écran est reconstruit / ré-initialisé pendant les appels réseau.
  static String? _inFlight;

  @visibleForTesting
  static void resetForTest() => _inFlight = null;

  static Future<String?> defaultSessionId() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return null;
    return auth.ensureSessionId();
  }

  // Email déjà stocké à la connexion ; sinon (session restaurée sans
  // profil local) relu depuis le jeton via GET /me.
  static Future<String?> defaultEmail() async {
    final stored = AuthService().userEmail;
    if (normalizeEmail(stored).isNotEmpty) return stored;
    final res = await ApiClient.instance.dio.get('/me');
    final user = res.data is Map ? (res.data as Map)['user'] : null;
    return user is Map ? user['email']?.toString() : null;
  }

  static Future<void> maybeShow(
    BuildContext context, {
    Future<String?> Function()? loadSessionId,
    Future<String?> Function()? loadEmail,
    Future<RawMaterialRequirement> Function()? checkRequirement,
    RawMaterialSubmit? submit,
    RawMaterialPromptStore? store,
  }) async {
    final s = store ?? const GetStorageRawMaterialPromptStore();
    final sessionId = await (loadSessionId ?? defaultSessionId)();
    if (sessionId == null || _inFlight == sessionId || s.read() == sessionId) return;
    _inFlight = sessionId;
    try {
      final email = normalizeEmail(await (loadEmail ?? defaultEmail)());
      if (!kRawMaterialLoginEmails.contains(email)) {
        await s.write(sessionId);
        return;
      }
      final requirement = await (checkRequirement ?? RawMaterialRequestService.instance.sessionRequirement)();
      final poste = requirement.poste;
      if (!requirement.required || poste == null) {
        await s.write(sessionId);
        return;
      }
      if (!context.mounted) return; // non marqué : réessayé au prochain affichage
      debugPrint('[RawMaterialLoginPrompt] popup à la connexion ($email, poste=$poste)');
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RawMaterialRequestDialog(
          poste: poste,
          submit: submit,
          deadlineAt: requirement.deadlineAt,
          deadlinePassed: requirement.deadlinePassed,
          rejection: requirement.rejected,
        ),
      );
      // Validée ou annulée : plus de popup automatique pendant cette session
      // (la popup « Nouvelle fiche » reste exigée tant qu'aucune demande n'est validée).
      await s.write(sessionId);
    } catch (e) {
      // Vérification impossible : popup avec l'erreur et accès au formulaire
      // de demande (jamais une simple notification en bas de l'écran).
      debugPrint('[RawMaterialLoginPrompt] vérification impossible : $e');
      if (!context.mounted) return;
      final create = await showRawMaterialRequiredDialog(context, error: RawMaterialRequestService.friendlyError(e));
      await s.write(sessionId);
      if (create && context.mounted) context.go(rawMaterialRequestPath());
    } finally {
      if (_inFlight == sessionId) _inFlight = null;
    }
  }
}
