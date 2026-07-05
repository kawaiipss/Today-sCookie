import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class FortuneResult {
  final String fortune;
  final bool cached;

  const FortuneResult({required this.fortune, required this.cached});
}

class FortuneService {
  static const _keyDate = 'fortune_date';
  static const _keyFortune = 'fortune_text';
  static const _functionUrl =
      'https://getdailyfortune-fha376a6xa-du.a.run.app';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  static Future<FortuneResult?> getTodayFortune() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyDate) == _todayKey()) {
      final text = prefs.getString(_keyFortune);
      if (text != null) return FortuneResult(fortune: text, cached: true);
    }
    return null;
  }

  static Future<FortuneResult> pickAndSaveFortune() async {
    final result = await _callDailyFortune();
    // fallback 문구는 캐시하지 않음 — 다음 탭 시 재시도 가능
    if (result.fortune != AppStrings.fortuneFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDate, _todayKey());
      await prefs.setString(_keyFortune, result.fortune);
    }
    return result;
  }

  static Future<void> ensureAnonymousAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  static Future<FortuneResult> _callDailyFortune() async {
    try {
      await ensureAnonymousAuth().timeout(const Duration(seconds: 10));
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      // ignore: avoid_print
      print('Fortune calling uid=$uid url=$_functionUrl');

      final response = await http
          .post(
            Uri.parse(_functionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 20));

      final decodedBody = utf8.decode(response.bodyBytes);
      // ignore: avoid_print
      print('Fortune status=${response.statusCode} body=$decodedBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final fortune = (data['fortune'] as String).trim();
        final cached = data['cached'] as bool? ?? false;
        return FortuneResult(fortune: fortune, cached: cached);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Fortune error: $e');
    }
    return FortuneResult(fortune: AppStrings.fortuneFallback, cached: false);
  }
}
