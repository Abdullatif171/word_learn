import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_card.dart';

class SaveService {
  static const String _lastSaveKey = "last_save";
  static const String _allSavesKey = "all_saves";

  // Convert lists to a serializable map
  static Map<String, dynamic> _toSave(
    List<WordCard> mainWords,
    List<WordCard> learnedWords,
    List<WordCard> unLearnedWords,
  ) {
    return {
      "main": mainWords.map((e) => e.toJson()).toList(),
      "learned": learnedWords.map((e) => e.toJson()).toList(),
      "unlearned": unLearnedWords.map((e) => e.toJson()).toList(),
      "saved_at": DateTime.now().toIso8601String(),
    };
  }

  // Save the "last" slot (automatically used for continue-from-last)
  static Future<void> saveLast(
    List<WordCard> mainWords,
    List<WordCard> learnedWords,
    List<WordCard> unLearnedWords,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _toSave(mainWords, learnedWords, unLearnedWords);
    await prefs.setString(_lastSaveKey, jsonEncode(map));
  }

  // Load the "last" slot. Returns map with lists or empty lists.
  static Future<Map<String, List<WordCard>>> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_lastSaveKey)) {
      return {"main": [], "learned": [], "unlearned": []};
    }
    try {
      final raw = prefs.getString(_lastSaveKey)!;
      final Map<String, dynamic> decoded = jsonDecode(raw);
      List<WordCard> toCards(List<dynamic>? arr) {
        if (arr == null) return [];
        return arr.map((e) => WordCard.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      return {
        "main": toCards(decoded["main"] as List?),
        "learned": toCards(decoded["learned"] as List?),
        "unlearned": toCards(decoded["unlearned"] as List?),
      };
    } catch (e) {
      // If something went wrong reading, clear the key to avoid repeated crashes
      await prefs.remove(_lastSaveKey);
      return {"main": [], "learned": [], "unlearned": []};
    }
  }

  // Save a named slot
  static Future<void> saveSlot(
    String name,
    List<WordCard> mainWords,
    List<WordCard> learnedWords,
    List<WordCard> unLearnedWords,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAllSlots();
    final map = _toSave(mainWords, learnedWords, unLearnedWords);
    all[name] = map;
    await prefs.setString(_allSavesKey, jsonEncode(all));
  }

  static Future<Map<String, dynamic>> loadAllSlots() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_allSavesKey)) return {};
    try {
      final raw = prefs.getString(_allSavesKey)!;
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (e) {
      await prefs.remove(_allSavesKey);
      return {};
    }
  }

  static Future<Map<String, List<WordCard>>> loadSlot(String name) async {
    final slots = await loadAllSlots();
    if (!slots.containsKey(name)) return {"main": [], "learned": [], "unlearned": []};
    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(slots[name]);
      List<WordCard> toCards(List<dynamic>? arr) {
        if (arr == null) return [];
        return arr.map((e) => WordCard.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      return {
        "main": toCards(decoded["main"] as List?),
        "learned": toCards(decoded["learned"] as List?),
        "unlearned": toCards(decoded["unlearned"] as List?),
      };
    } catch (e) {
      // corrupt slot: remove it
      final prefs = await SharedPreferences.getInstance();
      final all = await loadAllSlots();
      all.remove(name);
      await prefs.setString(_allSavesKey, jsonEncode(all));
      return {"main": [], "learned": [], "unlearned": []};
    }
  }

  static Future<void> deleteSlot(String slotName) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAllSlots();
    all.remove(slotName);
    await prefs.setString(_allSavesKey, jsonEncode(all));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSaveKey);
    await prefs.remove(_allSavesKey);
  }
}
