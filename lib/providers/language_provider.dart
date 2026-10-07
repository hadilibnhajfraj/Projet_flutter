import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;

class AppLanguageProvider extends ChangeNotifier {
  // Supported Languages
  final locales = const <String, Locale>{
    "Arabic": Locale('ar', 'SA'), // Arabic, Saudi Arabia
    "Bengali": Locale('bn', 'BD'), // Bengali, Bangladesh
    "English": Locale('en', 'US'), // English, United States
    "French": Locale('fr', 'FR'), // French, France
    "Hindi": Locale('hi', 'IN'), // Hindi, India
    "Indonesian": Locale('id', 'ID'), // Indonesian, Indonesia
    "Russian": Locale('ru', 'RU'), // Russian, Russia
  };

  bool isRTL = false;
  final GetStorage _box = GetStorage();
  Locale _currentLocale = const Locale('en');

  AppLanguageProvider() {
    String? savedLanguage = _box.read('language_code');
    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage);
    }
    // Module Contrôle Qualité : même langue que l'application.
    QcI18n.language.value = _currentLocale.languageCode;
  }

  Locale get currentLocale => _currentLocale;

  void changeLocale(Locale newLocale) {
    _currentLocale = newLocale;
    QcI18n.language.value = newLocale.languageCode;
    _box.write('language_code', newLocale.languageCode);
    notifyListeners();
  }

  String getSelectedLanguage() {
    return _currentLocale.languageCode; // Returns "en" or "ar"
  }
}
