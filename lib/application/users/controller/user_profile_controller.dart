import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/profile_model.dart';
import '../../services/user_profile_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
class UserProfileController extends GetxController {
  Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);
  RxBool isEditing = false.obs;
// ✅ avatar local
RxString avatarPath = "".obs;

// ✅ picker image
Future<void> pickImage() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

  if (picked != null) {
    avatarPath.value = picked.path;
  }
}
  // ================= CONTROLLERS =================
  final nameCtrl = TextEditingController();
  final designationCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final birthdayCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  // ================= LOAD PROFILE =================
  Future<void> loadProfile() async {
    try {
      final data = await UserProfileService.getMyProfile();

      profile.value = ProfileModel(
        name: data["name"] ?? "",
        designation: data["designation"] ?? "",
        email: data["email"] ?? "",
        birthday: data["birthday"] ?? "",
        phone: data["phone"] ?? "",
        country: data["country"] ?? "",
        state: data["state"] ?? "",
        address: data["address"] ?? "",
        about: data["about"] ?? "",
        occupationType: const [],
        department: "",
        location: "",
        activities: const [],
        experiences: const [],

        // ✅ IMPORTANT (si backend envoie avatar)
        avatarUrl: data["avatarUrl"],
      );

      _fillControllers();

    } catch (e) {
      Get.snackbar("Error", "Failed to load profile");
      print("❌ LOAD PROFILE ERROR: $e");
    }
  }

  // ================= FILL INPUTS =================
  void _fillControllers() {
    final p = profile.value;
    if (p == null) return;

    nameCtrl.text = p.name;
    designationCtrl.text = p.designation;
    emailCtrl.text = p.email;
    birthdayCtrl.text = p.birthday;
    phoneCtrl.text = p.phone;
    countryCtrl.text = p.country;
    stateCtrl.text = p.state;
    addressCtrl.text = p.address;
  }

  // ================= EDIT =================
  void startEdit() => isEditing.value = true;

  void cancelEdit() {
    isEditing.value = false;
    _fillControllers();
  }

  // ================= SAVE =================
  Future<void> saveEdit() async {
    try {
      final payload = {
        "name": nameCtrl.text.trim(),
        "designation": designationCtrl.text.trim(),
        "birthday": birthdayCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "country": countryCtrl.text.trim(),
        "state": stateCtrl.text.trim(),
        "address": addressCtrl.text.trim(),
      };

      final updated = await UserProfileService.updateMyProfile(payload);

      profile.value = profile.value!.copyWith(
        name: updated["name"] ?? "",
        designation: updated["designation"] ?? "",
        email: updated["email"] ?? profile.value!.email,
        birthday: updated["birthday"] ?? "",
        phone: updated["phone"] ?? "",
        country: updated["country"] ?? "",
        state: updated["state"] ?? "",
        address: updated["address"] ?? "",
        avatarUrl: updated["avatarUrl"], // ✅ IMPORTANT
      );

      _fillControllers();
      isEditing.value = false;

      Get.snackbar("Success", "Profil mis à jour ✅");

    } catch (e) {
      Get.snackbar("Error", "Erreur lors de la mise à jour");
      print("❌ SAVE PROFILE ERROR: $e");
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    designationCtrl.dispose();
    emailCtrl.dispose();
    birthdayCtrl.dispose();
    phoneCtrl.dispose();
    countryCtrl.dispose();
    stateCtrl.dispose();
    addressCtrl.dispose();
    super.onClose();
  }
}