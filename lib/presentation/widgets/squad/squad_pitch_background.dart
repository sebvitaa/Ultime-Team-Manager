import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ultime_team_manager/config/theme/app_colors.dart';
import 'package:ultime_team_manager/presentation/widgets/squad/pitch_geometry.dart';

/// Fondo ESTÁTICO de la pantalla de plantilla: una cancha vertical (arco
/// arriba y abajo) dibujada con [CustomPaint], misma paleta que
/// [PitchBackground] pero sin balón ni animación — encima van 11 cartas
/// superpuestas, así que conviene que el pintor no repinte en cada frame.
class SquadPitchBackground extends StatelessWidget {
  const SquadPitchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: size,
          painter: _SquadPitchPainter(computePitchRect(size)),
        );
      },
    );
  }
}

class _SquadPitchPainter extends CustomPainter {
  final Rect pitch;
  const _SquadPitchPainter(this.pitch);

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;

    // Fondo verde-carbón con un brillo suave centrado en la cancha.
    canvas.drawRect(
      all,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.16),
          radius: 0.9,
          colors: [Color(0xFF0A2A1A), Color(0xFF06140D), Color(0xFF02060A)],
          stops: [0, 0.55, 1],
        ).createShader(all),
    );
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.12),
          radius: 0.7,
          colors: [AppColors.verde.withValues(alpha: 0.14), Colors.transparent],
        ).createShader(all),
    );

    if (pitch.width > 0) {
      _drawDots(canvas, pitch);
      _drawPitch(canvas, pitch);
    }

    // Viñeta para dar profundidad.
    canvas.drawRect(
      all,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.0,
          colors: [Colors.transparent, Color(0xA8010503)],
          stops: [0.5, 1],
        ).createShader(all),
    );
  }

  void _drawDots(Canvas canvas, Rect p) {
    final paint = Paint()..color = AppColors.verde.withValues(alpha: 0.12);
    const gap = 28.0;
    for (var gx = p.left; gx < p.right; gx += gap) {
      for (var gy = p.top; gy < p.bottom; gy += gap) {
        canvas.drawCircle(Offset(gx, gy), 1.1, paint);
      }
    }
  }

  // Cancha en VERTICAL: arco arriba y abajo (a diferencia del fondo animado
  // de la intro, que la dibuja horizontal tipo toma de estadio).
  void _drawPitch(Canvas canvas, Rect p) {
    Paint linea(double op, [double w = 2]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = AppColors.verde.withValues(alpha: op);

    // Borde exterior + línea de medio campo + círculo central.
    canvas.drawRRect(
        RRect.fromRectAndRadius(p, const Radius.circular(6)), linea(0.55));
    canvas.drawLine(
        Offset(p.left, p.center.dy), Offset(p.right, p.center.dy), linea(0.45));
    canvas.drawCircle(p.center, p.width * 0.18, linea(0.45));

    // Áreas (grande y chica) arriba y abajo.
    void areaRect(double hf, double wf, double op) {
      final aw = p.width * wf, ah = p.height * hf;
      canvas.drawRect(
          Rect.fromLTWH(p.center.dx - aw / 2, p.top, aw, ah), linea(op));
      canvas.drawRect(
          Rect.fromLTWH(p.center.dx - aw / 2, p.bottom - ah, aw, ah),
          linea(op));
    }

    areaRect(0.16, 0.62, 0.40); // área grande
    areaRect(0.07, 0.30, 0.32); // área chica

    // Puntos: central y de penalti.
    final punto = Paint()..color = const Color(0xCC8CF0B4);
    canvas.drawCircle(p.center, 3, punto);
    canvas.drawCircle(Offset(p.center.dx, p.top + p.height * 0.12), 3, punto);
    canvas.drawCircle(
        Offset(p.center.dx, p.bottom - p.height * 0.12), 3, punto);

    // Porterías (fuera de la línea, centradas).
    final gw = p.width * 0.20;
    canvas.drawRect(
        Rect.fromLTWH(p.center.dx - gw / 2, p.top - 8, gw, 8), linea(0.55));
    canvas.drawRect(
        Rect.fromLTWH(p.center.dx - gw / 2, p.bottom, gw, 8), linea(0.55));

    // Arcos de córner (un cuarto de círculo en cada esquina).
    final corner = linea(0.38);
    const r = 12.0;
    canvas.drawArc(Rect.fromCircle(center: p.topLeft, radius: r), 0,
        math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.topRight, radius: r),
        math.pi / 2, math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.bottomRight, radius: r),
        math.pi, math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.bottomLeft, radius: r),
        3 * math.pi / 2, math.pi / 2, false, corner);
  }

  @override
  bool shouldRepaint(covariant _SquadPitchPainter oldDelegate) =>
      oldDelegate.pitch != pitch;
}
