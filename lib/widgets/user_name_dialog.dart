import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/auth_service.dart';

Future<void> showUserNameDialog(BuildContext context) async {
  final TextEditingController newUserController = TextEditingController();
  String? selectedUser;
  bool isLoading = true;
  List<String> users = [];

  final authService = Get.find<AuthService>();

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          // 🔥 LOAD USERS UNE SEULE FOIS
          if (isLoading) {
            authService.getUserNames().then((data) {
              setState(() {
                users = data;
                isLoading = false;
              });
            }).catchError((_) {
              setState(() => isLoading = false);
            });
          }

          return AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              "Choisir utilisateur",
              style: TextStyle(color: Colors.white),
            ),
            content: isLoading
                ? const SizedBox(
                    height: 80,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // =============================
                      // 🔽 SELECT EXISTANT
                      // =============================
                      DropdownButtonFormField<String>(
                        dropdownColor: Colors.black,
                        value: selectedUser,
                        hint: const Text(
                          "Sélectionner utilisateur",
                          style: TextStyle(color: Colors.white60),
                        ),
                        items: users.map((u) {
                          return DropdownMenuItem(
                            value: u,
                            child: Text(
                              u,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedUser = v;
                            newUserController.clear(); // 🔥 reset input
                          });
                        },
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        "OU",
                        style: TextStyle(color: Colors.white54),
                      ),

                      const SizedBox(height: 10),

                      // =============================
                      // ✍️ AJOUT NOUVEAU USER
                      // =============================
                      TextField(
                        controller: newUserController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Saisir nouveau nom",
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (_) {
                          setState(() {
                            selectedUser = null; // 🔥 reset dropdown
                          });
                        },
                      ),
                    ],
                  ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final inputUser = newUserController.text.trim();

                  final finalUser =
                      inputUser.isNotEmpty ? inputUser : selectedUser;

                  if (finalUser == null || finalUser.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Veuillez choisir ou saisir un utilisateur"),
                      ),
                    );
                    return;
                  }

                  // 🔥 NORMALISATION
                  final cleanUser = finalUser.toLowerCase();

                  // 🔥 SAVE
                  authService.setUserName(cleanUser);

                  Navigator.pop(context);
                },
                child: const Text("Valider"),
              ),
            ],
          );
        },
      );
    },
  );
}