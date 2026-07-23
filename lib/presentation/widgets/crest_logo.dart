import 'package:flutter/material.dart';

/// Escudo/logo vectorial de "Ultimate Team Manager" dibujado con [CustomPaint]
/// (sin emojis ni dependencias externas). Shield + balón lineal + monograma UTM.
class CrestLogo extends StatelessWidget {
  final double size;
  const CrestLogo({super.key, this.size = 66});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 112 / 100, // el escudo es un poco más alto que ancho
      child: CustomPaint(painter: _CrestPainter()),
    );
  }
}

class _CrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    // El diseño está pensado en un lienzo 100x112; escalamos a la medida real.
    final sx = s.width / 100, sy = s.height / 112;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final rect = Offset.zero & s;
    final grad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFBDF7D3), Color(0xFF12A355)],
    ).createShader(rect);

    // 1) Cuerpo del escudo (relleno oscuro + borde con degradado).
    final shield = Path()
      ..moveTo(50 * sx, 3 * sy)
      ..lineTo(94 * sx, 19 * sy)
      ..lineTo(94 * sx, 57 * sy)
      ..cubicTo(94 * sx, 85 * sy, 74 * sx, 102 * sy, 50 * sx, 109 * sy)
      ..cubicTo(26 * sx, 102 * sy, 6 * sx, 85 * sy, 6 * sx, 57 * sy)
      ..lineTo(6 * sx, 19 * sy)
      ..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xF00A140E));
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * sx
        ..strokeJoin = StrokeJoin.round
        ..shader = grad,
    );

    // 2) Emblema de balón (círculo + costuras).
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = grad;
    canvas.drawCircle(p(50, 63), 23 * sx, line);
    const seams = <List<double>>[
      [50, 49, 50, 40],
      [59.1, 57.5, 67.9, 53.9],
      [55.6, 69.5, 61.6, 77.6],
      [44.4, 69.5, 38.4, 77.6],
      [40.9, 57.5, 32.1, 53.9],
    ];
    for (final l in seams) {
      canvas.drawLine(p(l[0], l[1]), p(l[2], l[3]), line);
    }
    // Pentágono central relleno.
    final pent = Path()
      ..moveTo(50 * sx, 55 * sy)
      ..lineTo(57.6 * sx, 60.5 * sy)
      ..lineTo(54.7 * sx, 69.5 * sy)
      ..lineTo(45.3 * sx, 69.5 * sy)
      ..lineTo(42.4 * sx, 60.5 * sy)
      ..close();
    canvas.drawPath(pent, Paint()..shader = grad);

    // 3) Monograma "UTM" en la parte alta del escudo.
    final tp = TextPainter(
      text: TextSpan(
        text: 'UTM',
        style: TextStyle(
          fontSize: 13 * sx,
          fontWeight: FontWeight.w800,
          letterSpacing: 2 * sx,
          foreground: Paint()..shader = grad,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 * sx - tp.width / 2, 14 * sy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
