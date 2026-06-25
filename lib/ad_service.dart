import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _adUnitId = 'ca-app-pub-3117796092766601/4014017769';

  InterstitialAd? _ad;

  Future<void> loadAd() async {
    if (kIsWeb) return;
    await InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  // 광고가 완전히 닫혔을 때 완료되는 Future를 반환한다.
  // 광고 없음(웹·미로드) 또는 표시 실패 시에도 정상 완료(폴백)하여
  // 호출부에서 항상 다음 단계로 진행할 수 있도록 보장한다.
  Future<void> showAd() async {
    if (kIsWeb) return;
    final ad = _ad;
    if (ad == null) return;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _ad = null;
        completer.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _ad = null;
        completer.complete(); // 실패도 완료 처리 → 폴백으로 운세 생성 진행
      },
    );
    await ad.show();
    return completer.future;
  }

  void dispose() => _ad?.dispose();
}
