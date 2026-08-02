import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedBat extends StatefulWidget {
  const AnimatedBat({super.key, required this.active, required this.connecting});
  final bool active;
  final bool connecting;

  @override
  State<AnimatedBat> createState() => _AnimatedBatState();
}

class _AnimatedBatState extends State<AnimatedBat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AnimatedBat oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = Duration(
      milliseconds: widget.connecting ? 430 : (widget.active ? 900 : 1500),
    );
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? const Color(0xFF58F0A7)
        : widget.connecting
            ? const Color(0xFF55C7FF)
            : const Color(0xFF8A63FF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final flap = math.sin(_controller.value * math.pi) *
            (widget.connecting ? 0.32 : 0.18);
        return Container(
          width: 250,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .23), blurRadius: 55),
              BoxShadow(color: color.withValues(alpha: .12), blurRadius: 95),
            ],
          ),
          child: CustomPaint(
            painter: _BatPainter(color: color, flap: flap),
          ),
        );
      },
    );
  }
}

class _BatPainter extends CustomPainter {
  const _BatPainter({required this.color, required this.flap});
  final Color color;
  final double flap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);
    final glow = Paint()
      ..color = color.withValues(alpha: .30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: .48)],
      ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    Path buildBat() {
      final wingY = 72 + flap * 42;
      final p = Path()..moveTo(center.dx, center.dy - 36);
      p.cubicTo(center.dx - 15, center.dy - 44, center.dx - 22, center.dy - 55,
          center.dx - 27, center.dy - 68);
      p.lineTo(center.dx - 37, center.dy - 56);
      p.cubicTo(center.dx - 73, wingY - 32, center.dx - 103, wingY - 20,
          center.dx - 118, wingY - 50);
      p.cubicTo(center.dx - 125, wingY - 12, center.dx - 104, wingY + 13,
          center.dx - 80, wingY + 27);
      p.cubicTo(center.dx - 64, wingY + 8, center.dx - 48, wingY + 19,
          center.dx - 37, wingY + 35);
      p.cubicTo(center.dx - 24, center.dy + 29, center.dx - 17,
          center.dy + 50, center.dx, center.dy + 67);
      p.cubicTo(center.dx + 17, center.dy + 50, center.dx + 24,
          center.dy + 29, center.dx + 37, wingY + 35);
      p.cubicTo(center.dx + 48, wingY + 19, center.dx + 64, wingY + 8,
          center.dx + 80, wingY + 27);
      p.cubicTo(center.dx + 104, wingY + 13, center.dx + 125, wingY - 12,
          center.dx + 118, wingY - 50);
      p.cubicTo(center.dx + 103, wingY - 20, center.dx + 73, wingY - 32,
          center.dx + 37, center.dy - 56);
      p.lineTo(center.dx + 27, center.dy - 68);
      p.cubicTo(center.dx + 22, center.dy - 55, center.dx + 15,
          center.dy - 44, center.dx, center.dy - 36);
      p.close();
      return p;
    }

    final bat = buildBat();
    canvas.drawPath(bat, glow);
    canvas.drawPath(bat, fill);
    canvas.drawPath(bat, stroke);

    final eye = Paint()..color = widgetEyeColor(color);
    canvas.drawCircle(center + const Offset(-8, -28), 2.3, eye);
    canvas.drawCircle(center + const Offset(8, -28), 2.3, eye);
  }

  Color widgetEyeColor(Color base) => Color.lerp(base, Colors.white, .62)!;

  @override
  bool shouldRepaint(covariant _BatPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.flap != flap;
}
