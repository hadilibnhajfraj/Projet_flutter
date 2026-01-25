import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/profile_model.dart';
import '../../services/user_profile_service.dart';


class UserProfileController extends GetxController {
  Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);
  RxBool isEditing = false.obs;

  // ✅ controllers champs (emailCtrl ajouté)
  final nameCtrl = TextEditingController();
  final designationCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // ✅ important
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

  Future<void> loadProfile() async {
    final data = await UserProfileService.getMyProfile();

    profile.value = ProfileModel(
      name: data["name"] ?? "",
      designation: data["designation"] ?? "",
      email: data["email"] ?? "", // ✅
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
    );

    // ✅ remplir les TextEditingController
    nameCtrl.text = profile.value!.name;
    designationCtrl.text = profile.value!.designation;
    emailCtrl.text = profile.value!.email;
    birthdayCtrl.text = profile.value!.birthday;
    phoneCtrl.text = profile.value!.phone;
    countryCtrl.text = profile.value!.country;
    stateCtrl.text = profile.value!.state;
    addressCtrl.text = profile.value!.address;
  }

  void startEdit() => isEditing.value = true;

  void cancelEdit() {
    isEditing.value = false;
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

  Future<void> saveEdit() async {
    final payload = {
      "name": nameCtrl.text.trim(),
      "designation": designationCtrl.text.trim(),
      "birthday": birthdayCtrl.text.trim(),
      "phone": phoneCtrl.text.trim(),
      "country": countryCtrl.text.trim(),
      "state": stateCtrl.text.trim(),
      "address": addressCtrl.text.trim(),

      // ⚠️ email généralement pas modifié ici (User table)
      // "email": emailCtrl.text.trim(),
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
    );

    // mettre à jour les inputs aussi
    nameCtrl.text = profile.value!.name;
    designationCtrl.text = profile.value!.designation;
    emailCtrl.text = profile.value!.email;
    birthdayCtrl.text = profile.value!.birthday;
    phoneCtrl.text = profile.value!.phone;
    countryCtrl.text = profile.value!.country;
    stateCtrl.text = profile.value!.state;
    addressCtrl.text = profile.value!.address;

    isEditing.value = false;
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
