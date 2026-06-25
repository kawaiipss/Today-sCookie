import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_strings.dart';
import 'fortune_service.dart';
import 'ad_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _adService = AdService();
  String? _fortune;
  bool _alreadyChecked = false;
  bool _isLoading = true;
  bool _isShowingAd = false;
  bool _showFortuneCard = false;
  bool _isFadingToWhite = false;
  bool _showCrackedCookieTransition = false;

  BannerAd? _bannerAd;
  static const _bannerAdUnitId = 'ca-app-pub-3117796092766601/8164485532';

  // 종이 등장 애니메이션
  late final AnimationController _revealController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // 화면 화이트 페이드 애니메이션 (1초)
  late final AnimationController _whiteController;
  late final Animation<double> _whiteAnim;

  // 깨진 쿠키 포커스 아웃 애니메이션 (1초)
  late final AnimationController _focusOutController;
  late final Animation<double> _focusOutAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _revealController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _revealController, curve: Curves.easeOut));

    _whiteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _whiteAnim = CurvedAnimation(parent: _whiteController, curve: Curves.easeIn);

    _focusOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _focusOutAnim = CurvedAnimation(parent: _focusOutController, curve: Curves.easeIn);

    _init();
  }

  Future<void> _init() async {
    final result = await FortuneService.getTodayFortune();
    if (!mounted) return;
    setState(() {
      _fortune = result?.fortune;
      _alreadyChecked = result != null;
      _isLoading = false;
    });
    if (result == null) {
      FortuneService.ensureAnonymousAuth(); // 광고 로드와 병렬로 사전 인증
      _adService.loadAd();
    } else {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    if (kIsWeb) return;
    BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    ).load();
  }

  Future<void> _onCookieTap() async {
    if (_isShowingAd || _isFadingToWhite) return;

    // 1단계: 1초 화이트 페이드
    _whiteController.reset();
    setState(() => _isFadingToWhite = true);
    await _whiteController.forward();

    // 2단계: 광고 노출 — 사용자가 광고를 완전히 닫을 때까지 await
    setState(() {
      _isShowingAd = true;
      _isFadingToWhite = false;
    });
    await _adService.showAd();

    // ↑ 여기서 광고 시청 완료가 보장된 이후에만 아래 코드 실행
    if (!mounted) return;

    // 3단계: 깨진 쿠키 포커스 아웃 애니메이션 + getDailyFortune 병렬 호출
    // getDailyFortune은 반드시 광고 완료 이후에만 트리거됨
    _focusOutController.reset();
    setState(() {
      _isShowingAd = false;
      _showCrackedCookieTransition = true;
    });

    final fortuneFuture = FortuneService.pickAndSaveFortune();
    await _focusOutController.forward();

    final result = await fortuneFuture;
    if (!mounted) return;

    // 4단계: 종이 포커싱 등장
    setState(() {
      _fortune = result.fortune;
      _alreadyChecked = result.cached;
      _showCrackedCookieTransition = false;
      _showFortuneCard = true;
    });
    _revealController.forward();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _adService.dispose();
    _bannerAd?.dispose();
    _revealController.dispose();
    _whiteController.dispose();
    _focusOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _fortune != null && _bannerAd != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      bottomNavigationBar: showBanner
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Background(),
          SafeArea(child: _buildBody()),
          // 광고 전환용 화이트 오버레이
          if (_isFadingToWhite)
            AnimatedBuilder(
              animation: _whiteAnim,
              builder: (context, _) => IgnorePointer(
                child: Opacity(
                  opacity: _whiteAnim.value,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8960C)),
      );
    }
    if (_showCrackedCookieTransition) {
      return _buildCrackedCookieTransition();
    }
    if (_fortune == null) {
      return _buildCookieView();
    }
    if (_showFortuneCard) {
      return _buildFortuneView();
    }
    return _buildBrokenCookieView();
  }

  // 기본 쿠키 버튼 화면 — 이미지가 화면을 꽉 채우고 텍스트는 위아래 오버레이
  Widget _buildCookieView() {
    return GestureDetector(
      onTap: _isShowingAd ? null : _onCookieTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Image.asset(
              'assets/images/defaultFortuneCookie.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Text(
              AppStrings.appTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5C3800),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              AppStrings.tapHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB07A0A),
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 광고 후 깨진 쿠키 포커스 아웃 전환 화면
  Widget _buildCrackedCookieTransition() {
    return AnimatedBuilder(
      animation: _focusOutAnim,
      builder: (context, _) {
        final t = _focusOutAnim.value;
        return Opacity(
          opacity: 1.0 - t,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: t * 20,
              sigmaY: t * 20,
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Image.asset(
                'assets/images/crackedFortuneCookie.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  // 이번 세션 첫 운세: 깨진 쿠키 위에 종이 슬라이드 인
  Widget _buildFortuneView() {
    final now = DateTime.now();
    final dateStr = AppStrings.dateString(now);

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Image.asset(
            'assets/images/crackedFortuneCookie.png',
            fit: BoxFit.contain,
          ),
        ),
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildFortunePaper(dateStr, alreadyChecked: _alreadyChecked),
          ),
        ),
      ],
    );
  }

  // 앱 재진입 (오늘 이미 확인): 깨진 쿠키 위에 종이 바로 표시
  Widget _buildBrokenCookieView() {
    final now = DateTime.now();
    final dateStr = AppStrings.dateString(now);

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Image.asset(
            'assets/images/crackedFortuneCookie.png',
            fit: BoxFit.contain,
          ),
        ),
        _buildFortunePaper(dateStr, alreadyChecked: true),
      ],
    );
  }

  // 점괘 종이 — 깨진 쿠키 위 레이어, 화면 꽉 채움
  Widget _buildFortunePaper(String dateStr, {bool alreadyChecked = false}) {
    return Container(
      color: const Color(0xEEFFFAEE),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.appTitle,
              style: const TextStyle(
                color: Color(0xFF5C3800),
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            if (alreadyChecked) ...[
              const SizedBox(height: 6),
              Text(
                AppStrings.alreadyCheckedNote,
                style: const TextStyle(
                  color: Color(0xFFB07A0A),
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: const TextStyle(
                color: Color(0xFF8B6020),
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xAAC8960C), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28C8960C),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '✦',
                    style: TextStyle(color: Color(0xFFC8960C), fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _fortune!,
                    style: const TextStyle(
                      color: Color(0xFF3E2000),
                      fontSize: 20,
                      height: 1.8,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '✦',
                    style: TextStyle(color: Color(0xFFC8960C), fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.nextDayNote,
              style: const TextStyle(
                color: Color(0xCC8B6020),
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/background.svg',
      fit: BoxFit.cover,
    );
  }
}
