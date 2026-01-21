import 'package:dash_master_toolkit/application/users/users_imports.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserProfileController extends GetxController {
  Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);

  // ✅ Mode édition
  RxBool isEditing = false.obs;

  // ✅ Controllers pour édition
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

  void loadProfile() {
    // ⚠️ Ici tu peux remplacer par un GET /me
    profile.value = ProfileModel(
      name: 'Sara Smith GC',
      designation: 'Software Developer',
      email: 'sarasmith@wave.com',
      birthday: '18 Aug 1990',
      phone: '+13456789012',
      country: 'United States of America',
      state: 'West Virginia',
      address: 'Baker Street No.6',
      occupationType: [],
      department: 'Engineering',
      location: 'Seattle, WA',
      about: '...',
      activities: [],
      experiences: [],
    );

    _fillControllersFromProfile();
  }

  void _fillControllersFromProfile() {
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

  void startEdit() {
    _fillControllersFromProfile();
    isEditing.value = true;
  }

  void cancelEdit() {
    _fillControllersFromProfile();
    isEditing.value = false;
  }

  Future<void> saveEdit() async {
    final p = profile.value;
    if (p == null) return;

    // ✅ Update local (et après tu peux faire PUT /profile)
    profile.value = ProfileModel(
      name: nameCtrl.text.trim(),
      designation: designationCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      birthday: birthdayCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      country: countryCtrl.text.trim(),
      state: stateCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      occupationType: p.occupationType,
      department: p.department,
      location: p.location,
      about: p.about,
      activities: p.activities,
      experiences: p.experiences,
    );

    isEditing.value = false;

    // TODO (si API):
    // await ApiClient.instance.dio.put("/users/me", data: {...});
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
