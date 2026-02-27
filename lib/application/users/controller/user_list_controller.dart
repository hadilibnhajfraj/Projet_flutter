import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dash_master_toolkit/application/services/admin_users_service.dart';
import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/application/users/users_imports.dart'; // profileIcon1/profileIcon2
import '../model/user_model.dart';

class UserListController extends GetxController {
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

  final RxBool loading = false.obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  Future<void> loadUsers() async {
    loading.value = true;
    try {
      // ✅ 1) users
      final list = await AdminUsersService.instance.fetchUsers();

      // ✅ 2) projects count per user (admin only)
      // returns: [{ userId, projectsCount, email, displayName }]
      final counts = await AdminUsersService.instance.fetchUsersProjectsCount();

      // map userId -> count
      final Map<String, int> countByUserId = {
        for (final c in counts)
          (c['userId'] ?? '').toString(): (c['projectsCount'] ?? 0) is int
              ? (c['projectsCount'] ?? 0) as int
              : int.tryParse((c['projectsCount'] ?? '0').toString()) ?? 0
      };

      final mapped = list.map((u) {
        final id = (u['id'] ?? '').toString();
        final email = (u['email'] ?? '').toString();
        final role = (u['role'] ?? 'user').toString();
        final isActive = (u['isActive'] ?? false) == true;

        final name = email.contains('@') ? email.split('@').first : email;
        final projectsCount = countByUserId[id] ?? 0;

        return UserModel(
          id: id,
          name: name.isEmpty ? 'User' : name,
          designation: role,

          // ✅ Department => number of projects
          department: "$projectsCount projets",

          email: email,

          // ✅ Phone => ACTION placeholder (UI will render a button)
          phone: "Voir",

          status: isActive ? 'Active' : 'Inactive',
          imageUrl: isActive ? profileIcon1 : profileIcon2,
        );
      }).toList();

      users.assignAll(mapped);
    } catch (e) {
      SafeSnack.show("Error", e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      loading.value = false;
    }
  }

  /// ✅ action: open projects of this user (admin only)
  Future<List<Map<String, dynamic>>> fetchProjectsOfUser(String userId) async {
    try {
      return await AdminUsersService.instance.fetchProjectsByUserId(userId);
    } catch (e) {
      SafeSnack.show("Error", e.toString().replaceFirst('Exception: ', ''), isError: true);
      return [];
    }
  }

  Future<void> toggleActive(UserModel user) async {
    try {
      final newValue = !user.isActive;
      await AdminUsersService.instance.setActive(user.id, newValue);

      final idx = users.indexWhere((x) => x.id == user.id);
      if (idx != -1) {
        users[idx] = users[idx].copyWith(
          status: newValue ? "Active" : "Inactive",
          imageUrl: newValue ? profileIcon1 : profileIcon2,
        );
      }

      SafeSnack.show("Success", "User updated");
    } catch (e) {
      SafeSnack.show("Error", e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    f1.dispose();
    super.onClose();
  }
}