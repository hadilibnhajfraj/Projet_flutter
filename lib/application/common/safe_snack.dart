import 'package:flutter/material.dart';

class SafeSnack {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(String title, String message, {bool isError = false}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
