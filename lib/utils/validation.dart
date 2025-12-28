import 'package:flutter/cupertino.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

String? validatePhoneNumber(String phoneNumber, BuildContext context) {
  // Define the minimum and maximum length for a valid phone number
  const int minDigits = 7; // Minimum number of digits
  const int maxDigits = 15; // Maximum number of digits

  // Remove non-numeric characters from the phone number
  String numericPhoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

  // Check if the length falls within the valid range
  int phoneNumberLength = numericPhoneNumber.length;
  if (phoneNumberLength == 0) {
    return AppLocalizations.of(context).translate("phoneNumberIsRequired");
  }
  if (phoneNumberLength < minDigits) {
    return AppLocalizations.of(context).translate("phoneNumberIsTooShort");
  } else if (phoneNumberLength > maxDigits) {
    return AppLocalizations.of(context).translate("phoneNumberIsTooLong");
  }

  // The phone number is considered valid
  return null;
}

String? validateEmail(String? value, BuildContext context) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context).translate("emailIsRequired");
  }
  // Use regex for email validation
  if (!RegExp(
          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
      .hasMatch(value)) {
    return AppLocalizations.of(context).translate("pleaseEnterValidEmail");
  }
  return null;
}

String? validateText(String? value, String message) {
  if (value == null || value.isEmpty) {
    return message;
  }
  /* // Use regex for email validation
  if (value.length < 3 || value.length > 10) {
    return 'Text length must be between 3 and 10 characters';
  }*/
  return null;
}

String? validateTextWithMaxLength(String? value, String message,AppLocalizations lang) {
  if (value == null || value.isEmpty) {
    return message;
  }
  // Use regex for email validation
  if (value.length < 3 || value.length > 10) {
    return lang.translate('textLengthErrMsg');
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your password';
  }
  // Check if the password length is at least 6 characters
  if (value.length < 6) {
    return 'Password must be at least 6 characters long';
  }
  // You can add additional password complexity rules here
  return null;
}

String? validatePasswordWithMessage(String? value, String msg) {
  if (value == null || value.isEmpty) {
    return 'Please enter your $msg';
  }
  // Check if the password length is at least 6 characters
  if (value.length < 6) {
    return '$msg must be at least 6 characters long';
  }
  // You can add additional password complexity rules here
  return null;
}

String? validateConfirmPassword(String? password, String? confirmPassword) {
  if (confirmPassword == null || confirmPassword.isEmpty) {
    return 'Please confirm your password';
  }
  if (password != confirmPassword) {
    return 'Passwords do not match';
  }
  return null;
}

String? validateZipCode(String? value) {
  if (value == null || value.isEmpty) {
    return "Please enter ZIP code";
  }

  /* // US ZIP Code: 5 digits or 5+4 format (e.g., 12345 or 12345-6789)
  final zipCodeRegex = RegExp(r'^\d{5}(-\d{4})?$');

  if (!zipCodeRegex.hasMatch(value)) {
    return "Please enter a valid ZIP code (e.g., 12345 or 12345-6789)";
  }*/

  return null; // Valid ZIP code
}

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) {
    return 'Username is required';
  }
  if (value.length < 3) {
    return 'Username must be at least 3 characters long';
  }
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  return null; // Valid username
}

String? validateUsernameOrEmail(String? value) {
  if (value == null || value.isEmpty) {
    return "Username or Email is required";
  }

  // Regular expressions
  final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');
  final RegExp emailRegExp = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

  // Check if value is an email
  if (emailRegExp.hasMatch(value)) {
    return null; // Valid email
  }

  // Check if value is a valid username
  if (value.length >= 3 && usernameRegExp.hasMatch(value)) {
    return null; // Valid username
  }

  return "Enter a valid username (3+ letters, numbers, _) or email";
}
