import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../providers/auth_service.dart';
import '../../../services/commercial_profile_api_service.dart';

class CommercialProfileController extends GetxController {
  final _service = CommercialProfileApiService.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  final isLoading = true.obs;
  final hasError = false.obs;
  final isSaving = false.obs;

  final profiles = <CommercialProfile>[].obs;

  /// Sélection dans la liste API (null si aucune)
  final selected = Rxn<CommercialProfile>();

  /// Champ texte "Autre commercial" (nom libre)
  final newNameController = TextEditingController();
  final newNameText = ''.obs;

  // ── Computed ───────────────────────────────────────────────────────────────
  /// Nom final : champ texte prioritaire, sinon sélection liste.
  String? get finalName {
    final custom = newNameController.text.trim();
    if (custom.isNotEmpty) return custom;
    return selected.value?.name;
  }

  bool get canConfirm => finalName != null && !isSaving.value;

  /// Label affiché sur le bouton Confirmer.
  String get confirmLabel {
    final name = finalName;
    return name != null ? 'Confirmer : $name' : 'Confirmer';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadProfiles();
    newNameController.addListener(() => newNameText.value = newNameController.text);
  }

  @override
  void onClose() {
    newNameController.dispose();
    super.onClose();
  }

  // ── GET /commercial-contacts/user-names/list ──────────────────────────────
  Future<void> loadProfiles() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      final result = await _service.getProfiles();
      profiles.assignAll(result);
      debugPrint('[CommercialProfileCtrl] ${result.length} profils chargés');
    } catch (e) {
      hasError.value = true;
      debugPrint('[CommercialProfileCtrl] loadProfiles ERROR = $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Enregistrement dans GetStorage ────────────────────────────────────────
  /// Nom saisi dans "Autre commercial" : enregistré d'abord en base via
  /// l'API (attente de la confirmation) — sinon il disparaîtrait à la
  /// reconnexion. Puis sauvegarde la sélection dans GetStorage et retourne
  /// le nom, ou null si rien choisi. Lève une [Exception] si l'enregistrement
  /// échoue (rien n'est alors sauvegardé localement).
  Future<String?> confirm() async {
    var name = finalName;
    if (name == null || isSaving.value) return null;

    if (newNameController.text.trim().isNotEmpty) {
      isSaving.value = true;
      try {
        final saved = await _service.saveProfile(name);
        name = saved.name;
        if (!profiles.contains(saved) &&
            !profiles.any((p) => p.name.toLowerCase() == saved.name.toLowerCase())) {
          profiles.add(saved);
        }
      } finally {
        isSaving.value = false;
      }
    }

    final box = GetStorage();
    box.write('selectedCommercial', name);
    box.write('selectedCommercialId', name); // pas d'id distinct pour une string

    // Compat. user_nom pour les requêtes API existantes
    AuthService().setUserName(name.toLowerCase());

    print('COMMERCIAL CHOISI = $name');
    return name;
  }
}
