import 'dart:ui';

class AppStrings {
  AppStrings._();

  static bool get _isKo =>
      PlatformDispatcher.instance.locale.languageCode == 'ko';

  static String get appTitle => _isKo ? '오늘의 쿠키' : "Today's Cookie";

  static String get tapHint =>
      _isKo ? '탭하여 오늘의 쿠키 확인' : "Tap to open today's cookie";

  static String get nextDayNote => _isKo
      ? '내일 자정 이후 새로운 운세를 확인하세요'
      : 'Come back after midnight for a new fortune';

  static String get fortuneFallback => _isKo
      ? '오늘도 당신의 하루가 빛나기를 바랍니다.'
      : 'May today be the start of something wonderful.';

  static String get alreadyCheckedNote => _isKo
      ? '오늘 운세는 이미 확인했어요'
      : 'Already checked today';

  static String dateString(DateTime d) => _isKo
      ? '${d.year}년 ${d.month}월 ${d.day}일'
      : '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}
