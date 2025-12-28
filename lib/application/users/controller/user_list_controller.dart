
import 'package:dash_master_toolkit/application/users/users_imports.dart';


class UserListController extends GetxController {
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

}

List<UserModel> generateUsers(int count) {
  List<UserModel> users = [];
  for (int i = 1; i <= count; i++) {
    users.add(UserModel(
      name: "User $i",
      designation: i % 2 == 0 ? "Front-End Developer" : "App Developer",
      department: i % 3 == 0 ? "Software" : "Creative",
      email: "user$i@company.com",
      phone: "(555) 123-45${i.toString().padLeft(2, '0')}",
      status: i % 2 == 0 ? "Active" : "Inactive",
      imageUrl: i % 2 == 0 ? profileIcon1 : profileIcon2, // Random avatars
    ));
  }
  return users;
}

