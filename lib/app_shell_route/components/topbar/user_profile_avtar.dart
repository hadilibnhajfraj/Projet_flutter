import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common_imports.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({super.key});

  static const String kSigninPath = '/authentication/signin';
  static const String kProfilePath = '/users/user_profile';
  static const String kSettingsPath = '/application/settings';

  Future<void> _logout(BuildContext context) async {
    debugPrint('LOGOUT CLICKED');

    // Nettoyage complet de la session via AuthService :
    // isLoggedIn=false, accessToken, tokenExpiryMs, userId, userEmail, userRole
    // + AuthStorage (secure storage) + ApiClient token header
    await AuthService().logout();

    debugPrint('TOKEN REMOVED');
    debugPrint('REDIRECT TO LOGIN');

    if (context.mounted) {
      context.go(kSigninPath);
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
