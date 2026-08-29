import 'package:shared_preferences/shared_preferences.dart';

/// History pencarian per screen (key: mis. "search_history_form").
class SearchHistory {
  static const int maxItems = 8;

  static Future<List<String>> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> add(String key, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > maxItems) list.removeRange(maxItems, list.length);
    await prefs.setStringList(key, list);
  }

  static Future<void> remove(String key, String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.remove(query);
    await prefs.setStringList(key, list);
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
