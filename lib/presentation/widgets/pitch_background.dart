import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ultime_team_manager/config/theme/app_colors.dart';

/// Fondo animado de la pantalla de intro: una cancha en neón verde con un balón
/// que da pases aleatorios (ritmo de partido) rodando en 3D, más un barrido de
/// luz que recorre el campo. Todo dibujado con [CustomPaint] sobre un [Ticker].
class PitchBackground extends StatefulWidget {
  const PitchBackground({super.key});

  @override
  State<PitchBackground> createState() => _PitchBackgroundState();
}

class _PitchBackgroundState extends State<PitchBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0); // dispara el repaint sin rebuild
  final _rng = math.Random();
  final _scene = _Scene();

  double _t = 0; // segundos transcurridos
  double _last = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  // ---------- bucle de animación (delta-time real) ----------
  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    var dt = now - _last;
    _last = now;
    if (dt > 0.05) dt = 0.05; // evita saltos tras pausas
    _t = now;
    _scene.t = now;

    final pitch = _scene.pitch;
    if (pitch.width <= 0) {
      _repaint.value++;
      return;
    }

    final b = _scene.ball;
    if (b.r == 0) _initBall();

    if (b.esperando) {
      if (now >= b.esperaHasta) {
        final destino = _siguiente(b.pos);
        b.from = b.pos;
        b.to = destino.$1;
        b.tipo = destino.$2;
        b.prog = 0;
        b.dur = _duracion(b.from, b.to, b.tipo);
        b.esperando = false;
      }
    } else {
      final prev = b.pos;
      b.prog += dt / b.dur;
      if (b.prog > 1) b.prog = 1;
      final e = _easeOut(b.prog);
      b.pos = Offset(
        b.from.dx + (b.to.dx - b.from.dx) * e,
        b.from.dy + (b.to.dy - b.from.dy) * e,
      );
      // Rodadura 3D: gira sobre el eje perpendicular al movimiento.
      final d = b.pos - prev;
      final dl = d.distance;
      if (dl > 0.001) {
        final ang = dl / b.r; // ángulo = distancia / radio (rodadura real)
        b.R = _mul(_rotAxis(-d.dy / dl, d.dx / dl, 0, ang), b.R);
      }
      if (b.prog >= 1) {
        b.esperando = true;
        b.esperaHasta = now + _delay(b.tipo);
      }
    }
    _repaint.value++;
  }

  // ---------- física de pases ----------
  void _initBall() {
    final b = _scene.ball;
    b.r = (_scene.pitch.width * 0.016).clamp(6.0, 12.0);
    final p = _puntoCampo();
    b.pos = p;
    b.from = p;
    b.to = p;
    b.esperando = true;
    b.esperaHasta = _t + 0.3;
    b.R = [1, 0, 0, 0, 1, 0, 0, 0, 1];
  }

  Offset _puntoCampo() {
    final p = _scene.pitch;
    final mx = p.width * 0.08, my = p.height * 0.12;
    return Offset(
      p.left + mx + _rng.nextDouble() * (p.width - 2 * mx),
      p.top + my + _rng.nextDouble() * (p.height - 2 * my),
    );
  }

  Offset _clampCampo(Offset o) {
    final p = _scene.pitch;
    final mx = p.width * 0.07, my = p.height * 0.11;
    return Offset(
      o.dx.clamp(p.left + mx, p.right - mx),
      o.dy.clamp(p.top + my, p.bottom - my),
    );
  }

  // Pase corto: destino entre un radio mínimo y máximo alrededor del balón.
  Offset _destinoCorto(Offset pos) {
    final w = _scene.pitch.width;
    final minR = w * 0.12, maxR = w * 0.30;
    for (var i = 0; i < 14; i++) {
      final ang = _rng.nextDouble() * 2 * math.pi;
      final dist = minR + _rng.nextDouble() * (maxR - minR);
      final p = _clampCampo(
        Offset(pos.dx + math.cos(ang) * dist, pos.dy + math.sin(ang) * dist),
      );
      if ((p - pos).distance >= minR * 0.8) return p;
    }
    return _puntoCampo();
  }

  // Pase largo: a un sector aleatorio, preferiblemente lejos.
  Offset _destinoLargo(Offset pos) {
    final w = _scene.pitch.width;
    var p = _puntoCampo();
    for (var i = 0; i < 14; i++) {
      p = _puntoCampo();
      if ((p - pos).distance > w * 0.36) break;
    }
    return p;
  }

  // 80% pase corto | 20% pase largo a sector aleatorio.
  (Offset, String) _siguiente(Offset pos) {
    return _rng.nextDouble() < 0.2
        ? (_destinoLargo(pos), 'largo')
        : (_destinoCorto(pos), 'corto');
  }

  // Velocidad de partido: corto casi instantáneo, largo con recuperación.
  double _duracion(Offset a, Offset b, String tipo) {
    final d = (b - a).distance;
    return tipo == 'corto'
        ? math.min(0.85, math.max(0.38, d / 330))
        : math.min(1.05, math.max(0.55, d / 470));
  }

  // Más delay tras un pase corto (control); menos tras uno aleatorio.
  double _delay(String tipo) => tipo == 'corto'
      ? 0.28 + _rng.nextDouble() * 0.26
      : 0.09 + _rng.nextDouble() * 0.17;

  double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();

  // Matriz de rotación 3x3 a partir de eje-ángulo (Rodrigues).
  List<double> _rotAxis(double x, double y, double z, double ang) {
    final c = math.cos(ang), s = math.sin(ang), t = 1 - c;
    return [
      t * x * x + c, t * x * y - s * z, t * x * z + s * y,
      t * x * y + s * z, t * y * y + c, t * y * z - s * x,
      t * x * z - s * y, t * y * z + s * x, t * z * z + c,
    ];
  }

  List<double> _mul(List<double> a, List<double> b) {
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        r[i * 3 + j] =
            a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
      }
    }
    return r;
  }

  Rect _computePitch(Size s) {
    var w = s.width * 0.94;
    var h = w * 10 / 16;
    final maxH = s.height * 0.72;
    if (h > maxH) {
      h = maxH;
      w = h * 16 / 10;
    }
    return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _scene.pitch = _computePitch(size); // el bucle usa este rect
        return CustomPaint(
          size: size,
          painter: _PitchPainter(_scene, repaint: _repaint),
        );
      },
    );
  }
}

/// Estado compartido entre el bucle y el pintor (se muta en el sitio).
class _Scene {
  final _Ball ball = _Ball();
  double t = 0;
  Rect pitch = Rect.zero;
}

class _Ball {
  Offset pos = Offset.zero, from = Offset.zero, to = Offset.zero;
  double prog = 1, dur = 1;
  String tipo = 'corto';
  bool esperando = true;
  double esperaHasta = 0;
  List<double> R = [1, 0, 0, 0, 1, 0, 0, 0, 1];
  double r = 0;
}

// 12 pentágonos del balón = vértices de un icosaedro (normalizados).
final List<List<double>> _sphere = () {
  const phi = 1.618033988749895;
  final raw = <List<double>>[
    [0, 1, phi], [0, 1, -phi], [0, -1, phi], [0, -1, -phi],
    [1, phi, 0], [1, -phi, 0], [-1, phi, 0], [-1, -phi, 0],
    [phi, 0, 1], [phi, 0, -1], [-phi, 0, 1], [-phi, 0, -1],
  ];
  return raw.map((v) {
    final n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [v[0] / n, v[1] / n, v[2] / n];
  }).toList();
}();

List<double> _applyR(List<double> r, List<double> p) => [
      r[0] * p[0] + r[1] * p[1] + r[2] * p[2],
      r[3] * p[0] + r[4] * p[1] + r[5] * p[2],
      r[6] * p[0] + r[7] * p[1] + r[8] * p[2],
    ];

class _PitchPainter extends CustomPainter {
  final _Scene scene;
  _PitchPainter(this.scene, {required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;

    // Fondo (verde carbón) + brillo que respira.
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
    final glow = 0.5 + 0.45 * math.sin(scene.t * 2 * math.pi / 6);
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.12),
          radius: 0.7,
          colors: [AppColors.verde.withValues(alpha: 0.16 * glow), Colors.transparent],
        ).createShader(all),
    );

    final p = scene.pitch;
    if (p.width > 0) {
      _drawDots(canvas, p);
      _drawPitch(canvas, p);
      _drawScan(canvas, p);
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

    if (p.width > 0 && scene.ball.r > 0) _drawBall(canvas, scene.ball);
  }

  void _drawDots(Canvas canvas, Rect p) {
    final paint = Paint()..color = AppColors.verde.withValues(alpha: 0.12);
    const gap = 34.0;
    for (var gx = p.left; gx < p.right; gx += gap) {
      for (var gy = p.top; gy < p.bottom; gy += gap) {
        canvas.drawCircle(Offset(gx, gy), 1.2, paint);
      }
    }
  }

  void _drawPitch(Canvas canvas, Rect p) {
    Paint linea(double op, [double w = 2]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = AppColors.verde.withValues(alpha: op);

    // Borde exterior + línea de medio campo + círculo central.
    canvas.drawRRect(
        RRect.fromRectAndRadius(p, const Radius.circular(6)), linea(0.55));
    canvas.drawLine(
        Offset(p.center.dx, p.top), Offset(p.center.dx, p.bottom), linea(0.45));
    canvas.drawCircle(p.center, p.width * 0.12, linea(0.45));

    // Áreas (grande y chica) a ambos lados.
    void areaRect(double wf, double hf, double op) {
      final aw = p.width * wf, ah = p.height * hf;
      canvas.drawRect(
          Rect.fromLTWH(p.left, p.center.dy - ah / 2, aw, ah), linea(op));
      canvas.drawRect(
          Rect.fromLTWH(p.right - aw, p.center.dy - ah / 2, aw, ah), linea(op));
    }

    areaRect(0.15, 0.50, 0.40); // área grande
    areaRect(0.065, 0.26, 0.32); // área chica

    // Puntos: central y de penalti.
    final punto = Paint()..color = const Color(0xCC8CF0B4);
    canvas.drawCircle(p.center, 3, punto);
    canvas.drawCircle(
        Offset(p.left + p.width * 0.105, p.center.dy), 3, punto);
    canvas.drawCircle(
        Offset(p.right - p.width * 0.105, p.center.dy), 3, punto);

    // Porterías (fuera de la línea).
    final gh = p.height * 0.18;
    canvas.drawRect(
        Rect.fromLTWH(p.left - 8, p.center.dy - gh / 2, 8, gh), linea(0.55));
    canvas.drawRect(
        Rect.fromLTWH(p.right, p.center.dy - gh / 2, 8, gh), linea(0.55));

    // Arcos de córner (un cuarto de círculo en cada esquina).
    final corner = linea(0.38);
    const r = 12.0;
    canvas.drawArc(Rect.fromCircle(center: p.topLeft, radius: r), 0,
        math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.topRight, radius: r), math.pi / 2,
        math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.bottomRight, radius: r), math.pi,
        math.pi / 2, false, corner);
    canvas.drawArc(Rect.fromCircle(center: p.bottomLeft, radius: r),
        3 * math.pi / 2, math.pi / 2, false, corner);
  }

  void _drawScan(Canvas canvas, Rect p) {
    final phase = (scene.t % 6.5) / 6.5;
    final bandW = p.width * 0.36;
    final x = (p.left - bandW) + phase * (p.width + bandW);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(p, const Radius.circular(6)));
    final band = Rect.fromLTWH(x, p.top, bandW, p.height);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.verde.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  void _drawBall(Canvas canvas, _Ball b) {
    final c = b.pos, r = b.r;

    // Sombra en el césped.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.92), width: r * 1.9, height: r * 0.8),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Cuerpo esférico con sombreado.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFC3CCD4)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x59061608),
    );

    // Pentágonos del hemisferio frontal (rotan en 3D).
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    for (final p0 in _sphere) {
      final q = _applyR(b.R, p0);
      if (q[2] <= 0.02) continue; // solo la cara visible
      final d = q[2];
      final size = r * 0.34 * (0.45 + 0.55 * d);
      canvas.drawCircle(
        Offset(c.dx + q[0] * r, c.dy + q[1] * r),
        size,
        Paint()..color = const Color(0xFF0D1C13).withValues(alpha: 0.30 + 0.6 * d),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}
