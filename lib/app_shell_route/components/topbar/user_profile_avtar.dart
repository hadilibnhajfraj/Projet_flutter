import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_storage/get_storage.dart';

import '../common_imports.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({super.key});

  static const String kSigninPath = '/authentication/signin';
  static const String kProfilePath = '/users/user_profile'; // ✅ adapte si besoin
  static const String kSettingsPath = '/application/settings';     // ✅ adapte si besoin

  Future<void> _logout(BuildContext context) async {
    final box = GetStorage();

    // supprime tout ce qui concerne session
    await box.remove("accessToken");
    await box.remove("token");
    await box.remove("user");
    await box.remove("role");

    if (context.mounted) {
      context.go(kSigninPath); // ✅ path exact
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: (value) async {
        switch (value) {
          case 1:
            // ✅ PROFILE
            context.go(kProfilePath); // 🔁 change si ton route profile différent
            break;

          case 2:
            // ✅ SETTINGS
            context.go(kSettingsPath); // 🔁 change si ton route settings différent
            break;

          case 3:
            // ✅ LOGOUT
            await _logout(context);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.person),
              SizedBox(width: 10),
              Text("Profile"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 10),
              Text("Settings"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 10),
              Text("Logout", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      position: PopupMenuPosition.under,
      child: CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(profileIcon),
      ),
    );
  }
}
