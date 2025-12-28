import '../common_imports.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: (value) {
        switch (value) {
          case 1:
            break;
          case 2:
            break;
          case 3:
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.person, ),
              SizedBox(width: 10),
              Text("Profile"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.settings, ),
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
      position: PopupMenuPosition.under, // Open popup below the avatar
      child: CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(
          profileIcon,
        ), // Replace with actual image
      ),
    );
  }
}
