import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignInController extends GetxController {
  TextEditingController userNameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  RxBool rememberMe = false.obs;

  FocusNode f1 = FocusNode();
  FocusNode f2 = FocusNode();

  final formKey = GlobalKey<FormState>();
  final userNameFieldFocused = false.obs;
  final passwordFieldFocused = false.obs;

  RxBool isShowPasswordIcon = true.obs;

  @override
  void onInit() {
    super.onInit();

    userNameController.text = "yourname";
    passwordController.text = "Test@123";
  }
}
