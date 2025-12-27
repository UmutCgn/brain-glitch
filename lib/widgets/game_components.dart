import 'package:flutter/material.dart';
import 'dart:math';

// 3D GÖRÜNÜMLÜ METİN
class ThreeDText extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool isUnderlined;
  final double lineHeight;

  const ThreeDText({
    super.key,
    required this.text,
    required this.fontSize,
    this.isUnderlined = false,
    this.lineHeight = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 3,
          left: 2,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'Arial Rounded',
              fontWeight: FontWeight.w900,
              height: lineHeight,
              letterSpacing: 1.5,
              color: const Color(0xFF880E4F),
              decoration: isUnderlined ? TextDecoration.underline : TextDecoration.none,
              decorationColor: const Color(0xFF880E4F),
              decorationThickness: 4.0,
            ),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'Arial Rounded',
            fontWeight: FontWeight.w900,
            height: lineHeight,
            letterSpacing: 1.5,
            color: Colors.white,
            decoration: isUnderlined ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Colors.white,
            decorationThickness: 4.0,
            shadows: [
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 2,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// JÖLE EFEKTLİ BUTON
class JellyButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final EdgeInsets padding;
  final double fontSize;
  const JellyButton({super.key, required this.text, required this.onTap, required this.color, this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 20), this.fontSize = 20});
  @override
  State<JellyButton> createState() => _JellyButtonState();
}

class _JellyButtonState extends State<JellyButton> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override
  void initState() { _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); _s = Tween(begin: 1.0, end: 0.9).animate(_c); super.initState(); }
  @override
  Widget build(BuildContext context) => GestureDetector(onTapDown: (_) => _c.forward(), onTapUp: (_) { _c.reverse(); widget.onTap(); }, onTapCancel: () => _c.reverse(), child: ScaleTransition(scale: _s, child: Container(padding: widget.padding, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(30), boxShadow: [const BoxShadow(color: Colors.black12, offset: Offset(0, 10), blurRadius: 10), BoxShadow(color: Colors.white.withOpacity(0.4), offset: const Offset(0, -5), blurRadius: 0, spreadRadius: -2)], border: Border.all(color: Colors.white.withOpacity(0.5), width: 3)), child: Text(widget.text, style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)))));
}

// JÖLE EFEKTLİ KUTU (Container)
class JellyBox extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final Color color; final bool isCircle;
  const JellyBox({super.key, required this.child, required this.padding, required this.color, this.isCircle = false});
  @override
  Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: color, shape: isCircle ? BoxShape.circle : BoxShape.rectangle, borderRadius: isCircle ? null : BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 8), blurRadius: 15), BoxShadow(color: Colors.white.withOpacity(0.5), offset: const Offset(-4, -4), blurRadius: 0)]), child: child);
}

// TİTREME EFEKTİ
class ShakeWidget extends StatefulWidget { final Widget child; const ShakeWidget({super.key, required this.child}); @override State<ShakeWidget> createState() => _ShakeWidgetState(); }
class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _c; @override void initState() { _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat(reverse: true); super.initState(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (c, _) => Transform.rotate(angle: 0.1 * sin(_c.value * 2 * pi), child: widget.child));
}

// ARKA PLAN ŞEKERLERİ
class FloatingCandyPainter extends CustomPainter {
  final double animationValue;
  final List<Offset> positions = [const Offset(0.1, 0.2), const Offset(0.8, 0.1), const Offset(0.5, 0.5), const Offset(0.2, 0.8), const Offset(0.9, 0.7), const Offset(0.4, 0.9)];
  FloatingCandyPainter(this.animationValue);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < positions.length; i++) {
      double dy = (positions[i].dy - animationValue * (0.5 + i * 0.1)) % 1.0;
      if (dy < 0) dy += 1.0;
      final position = Offset(positions[i].dx * size.width, dy * size.height);
      paint.color = i % 2 == 0 ? Colors.white.withOpacity(0.5) : Colors.purple.withOpacity(0.5);
      if (i % 2 == 0) { canvas.drawCircle(position, 20 + i * 5, paint); } 
      else { canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: position, width: 40, height: 40), const Radius.circular(10)), paint); }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}