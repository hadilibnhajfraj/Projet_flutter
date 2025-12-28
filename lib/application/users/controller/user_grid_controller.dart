

import 'package:dash_master_toolkit/application/users/users_imports.dart';


class UserGridController extends GetxController {
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();


  RxList<UserGridData> filteredUsersList = <UserGridData>[].obs;
  var searchQuery = ''.obs; // Observable variable for the search query
  RxList<UserGridData> users = <UserGridData>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  void loadUsers() {
    users.value = List.generate(12, (index) {
      return UserGridData(
        name: "Anthony Stark",
        email: "antony@gmail.com",
        category: "Software",
        amount: "4,564 kr",
        rating: 4.5,
        imageUrl:
        "https://i.ibb.co/FLmVN4v7/Ellipse-8-1.png", // Avatar placeholder
      );
    });

    filteredUsersList.value = List.from(users);
  }
  // Filter the list based on the search query
  void searchUser(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      // If the search query is empty, show the full list
      filteredUsersList.value = List.from(users);
    } else {
      // Filter the list based on the name
      filteredUsersList.value = users
          .where((lang) =>
          lang.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }
}

