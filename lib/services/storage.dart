import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class AppSettings {
  const AppSettings({
    this.readerBlocked = false,
    this.listBackground = 0xff10111a,
    this.listTextSize = 17,
  });

  final bool readerBlocked;
  final int listBackground;
  final double listTextSize;

  AppSettings copyWith({
    bool? readerBlocked,
    int? listBackground,
    double? listTextSize,
  }) =>
      AppSettings(
        readerBlocked: readerBlocked ?? this.readerBlocked,
        listBackground: listBackground ?? this.listBackground,
        listTextSize: listTextSize ?? this.listTextSize,
      );
}

class AppStorage {
  static const _lessonsKey = 'lessons';
  static const _backupKey = 'lessons_backup';
  static const _blockedKey = 'readerBlocked';
  static const _bgKey = 'listBackground';
  static const _sizeKey = 'listTextSize';

  static Future<List<Lesson>> loadLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lessonsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // لا نضيّع البيانات التالفة: نحتفظ بنسخة قبل أن تُستبدل.
      await prefs.setString(_backupKey, raw);
      return [];
    }
  }

  static Future<void> saveLessons(List<Lesson> lessons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lessonsKey,
      jsonEncode(lessons.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<String>> loadStrings(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? <String>[]).toList();
  }

  static Future<void> saveStrings(String key, List<String> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, v);
  }

  static Future<List<String>> loadFavSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favSymbols') ?? ['★', '◆', '●', '☞', '→'];
  }

  static Future<void> saveFavSymbols(List<String> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favSymbols', v);
  }

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      readerBlocked: prefs.getBool(_blockedKey) ?? false,
      listBackground: prefs.getInt(_bgKey) ?? 0xff10111a,
      listTextSize: prefs.getDouble(_sizeKey) ?? 17,
    );
  }

  static Future<void> saveSettings(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blockedKey, s.readerBlocked);
    await prefs.setInt(_bgKey, s.listBackground);
    await prefs.setDouble(_sizeKey, s.listTextSize);
  }
}
