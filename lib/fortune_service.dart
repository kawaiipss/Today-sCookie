import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class FortuneResult {
  final String fortune;
  final bool cached; // true = 오늘 이미 서버에서 생성된 운세

  const FortuneResult({required this.fortune, required this.cached});
}

class FortuneService {
  static const _keyDate = 'fortune_date';
  static const _keyFortune = 'fortune_text';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDate, _todayKey());
    await prefs.setString(_keyFortune, result.fortune);
    return result;
  }

  // home_screen의 _init()에서 광고 로드와 병렬로 사전 인증
  static Future<void> ensureAnonymousAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  static Future<FortuneResult> _callDailyFortune() async {
    try {
      await ensureAnonymousAuth().timeout(const Duration(seconds: 10));
      final callable =
          FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable(
        'getDailyFortune',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final response = await callable.call();
      final fortune = (response.data['fortune'] as String).trim();
      final cached = response.data['cached'] as bool? ?? false;
      return FortuneResult(fortune: fortune, cached: cached);
    } catch (e) {
      // ignore: avoid_print
      print('Fortune error: $e');
    }
    return FortuneResult(fortune: AppStrings.fortuneFallback, cached: false);
  }
}
