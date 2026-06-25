import 'package:flutter/material.dart';
import 'app_strings.dart';

class FortuneCookieButton extends StatefulWidget {
  final VoidCallback onTap;

  const FortuneCookieButton({super.key, required this.onTap});

  @override
  State<FortuneCookieButton> createState() => _FortuneCookieButtonState();
}

class _FortuneCookieButtonState extends State<FortuneCookieButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 260,
              height: 185,
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x50C8960C),
                    blurRadius: 36,
                    spreadRadius: 8,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/defaultFortuneCookie.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            AppStrings.tapHint,
            style: const TextStyle(
              color: Color(0xFFB07A0A),
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
