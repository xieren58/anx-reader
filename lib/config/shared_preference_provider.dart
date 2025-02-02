import 'package:anx_reader/models/book_style.dart';
import 'package:anx_reader/models/read_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesProvider extends ChangeNotifier {
  late SharedPreferences prefs;
  static final SharedPreferencesProvider _instance =
      SharedPreferencesProvider._internal();

  factory SharedPreferencesProvider() {
    return _instance;
  }

  SharedPreferencesProvider._internal() {
    initPrefs();
  }

  Future<void> initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    saveBeginDate();
    notifyListeners();
  }

  Color get themeColor {
    int colorValue = prefs.getInt('themeColor') ?? Colors.green.value;
    return Color(colorValue);
  }

  Future<void> saveThemeToPrefs(int colorValue) async {
    await prefs.setInt('themeColor', colorValue);
    notifyListeners();
  }

  Locale? get locale {
    String? localeCode = prefs.getString('locale');
    if (localeCode == null) return null;
    return Locale(localeCode);
  }

  Future<void> saveLocaleToPrefs(String localeCode) async {
    await prefs.setString('locale', localeCode);
    notifyListeners();
  }

  ThemeMode get themeMode {
    String themeMode = prefs.getString('themeMode') ?? 'system';
    switch (themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeModeToPrefs(String themeMode) async {
    await prefs.setString('themeMode', themeMode);
    notifyListeners();
  }

  Future<void> saveBookStyleToPrefs(BookStyle bookStyle) async {
    await prefs.setString('readStyle', bookStyle.toJson());
    notifyListeners();
  }

  BookStyle get bookStyle {
    String? bookStyleJson = prefs.getString('readStyle');
    if (bookStyleJson == null) return BookStyle();
    return BookStyle.fromJson(bookStyleJson);
  }

  void saveReadThemeToPrefs(ReadTheme readTheme) {
    prefs.setString('readTheme', readTheme.toJson());
    notifyListeners();
  }

  ReadTheme get readTheme {
    String? readThemeJson = prefs.getString('readTheme');
    if (readThemeJson == null) {
      return ReadTheme(
          backgroundColor: 'ffFFFFFF',
          textColor: 'ff000000',
          backgroundImagePath: '');
    }
    return ReadTheme.fromJson(readThemeJson);
  }

  void saveBeginDate() {
    String? beginDate = prefs.getString('beginDate');
    if (beginDate == null) {
      prefs.setString('beginDate', DateTime.now().toIso8601String());
    }
  }

  DateTime? get beginDate {
    String? beginDateStr = prefs.getString('beginDate');
    if (beginDateStr == null) return null;
    return DateTime.parse(beginDateStr);
  }
}
