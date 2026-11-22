import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_locale_code';
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  LocaleProvider() {
    _loadLocaleFromPrefs();
  }

  Future<void> _loadLocaleFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null && (code == 'ar' || code == 'en')) {
        _locale = Locale(code);
      } else {
        _locale = const Locale('ar');
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
    } catch (_) {}
  }

  Future<void> toggleLocale() async {
    final nextCode = _locale.languageCode == 'ar' ? 'en' : 'ar';
    await setLocale(Locale(nextCode));
  }
}
