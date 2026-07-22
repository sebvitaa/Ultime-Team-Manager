import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/match_event.dart';
import 'package:contador_app/presentation/providers/match_provider.dart';
import 'package:contador_app/presentation/widgets/match_music.dart';

/// Pantalla de partido (RF5): cara a cara en diagonal + cronómetro, marcador y
/// relato en vivo, siguiendo el mockup `match-final-vs-comentarios.html`.
class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  static const _naranja = Color(0xFFF79457);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(matchControllerProvider);
    final finished = m.phase == MatchPhase.finished;

    return PopScope(
      // No se puede salir mientras el partido está en juego (solo al terminar).
      canPop: finished,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ArenaPainter())),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // Cronómetro
                    _Clock(minute: m.minute, finished: finished),
                    const SizedBox(height: 8),
                    // Cara a cara
                    Expanded(child: _Stage(state: m, naranja: _naranja)),
                    const SizedBox(height: 8),
                    _Timeline(
                        events: m.events, minute: m.minute, naranja: _naranja),
                    const SizedBox(height: 12),
                    _Feed(events: m.events, naranja: _naranja),
                    if (finished) ...[
                      const SizedBox(height: 8),
                      _ResultBar(
                          coins: m.coinsAwarded, fromLeague: m.fromLeague),
                    ],
                  ],
                ),
              ),
            ),
            const MatchMusic(),
            // Botón volver: solo al terminar.
            if (finished)
              Positioned(
                top: 8,
                left: 4,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.texto),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Cronómetro ----------
class _Clock extends StatelessWidget {
  final int minute;
  final bool finished;
  const _Clock({required this.minute, required this.finished});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!finished) const _LiveDot(),
          if (!finished) const SizedBox(width: 8),
          Text(
            finished ? 'FINAL' : "${minute.toString().padLeft(2, '0')}'",
            style: const TextStyle(
              color: AppColors.verde,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFFF4D4D),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0xFFFF4D4D), blurRadius: 8)],
        ),
      ),
    );
  }
}

// ---------- Cara a cara ----------
class _Stage extends StatelessWidget {
  final MatchState state;
  final Color naranja;
  const _Stage({required this.state, required this.naranja});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TeamSide(
            name: state.localName,
            rating: state.ratingLocal,
            goals: state.golLocal,
            color: AppColors.verde,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('EN JUEGO',
                style: TextStyle(
                    color: AppColors.gris, fontSize: 10, letterSpacing: 1)),
            SizedBox(height: 6),
            Text('VS',
                style: TextStyle(
                    color: AppColors.gris,
                    fontSize: 30,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('LA LIGA',
                style: TextStyle(
                    color: AppColors.gris, fontSize: 10, letterSpacing: 1)),
          ],
        ),
        Expanded(
          child: _TeamSide(
            name: state.visitaName,
            rating: state.ratingVisita,
            goals: state.golVisita,
            color: naranja,
          ),
        ),
      ],
    );
  }
}

class _TeamSide extends StatelessWidget {
  final String name;
  final int rating;
  final int goals;
  final Color color;
  const _TeamSide({
    required this.name,
    required this.rating,
    required this.goals,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 44, height: 4, color: color),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'MEDIA ',
            style: const TextStyle(
                color: AppColors.gris, fontSize: 12, letterSpacing: 1),
            children: [
              TextSpan(
                text: '$rating',
                style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Marcador con "pop" al cambiar.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(begin: 1.6, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$goals',
            key: ValueKey(goals),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 64,
              height: 0.9,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Línea de tiempo ----------
class _Timeline extends StatelessWidget {
  final List<MatchEvent> events;
  final int minute;
  final Color naranja;
  const _Timeline(
      {required this.events, required this.minute, required this.naranja});

  @override
  Widget build(BuildContext context) {
    final goals = events.where((e) => e.isGoal).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.borde,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 4,
                child: Container(
                  height: 6,
                  width: w * (minute / 90).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.verde2, AppColors.verde]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final g in goals)
                Positioned(
                  left: (w * (g.minute / 90) - 5).clamp(0.0, w - 10),
                  top: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: g.team == MatchTeam.local
                          ? AppColors.verde
                          : naranja,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.fondo, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Relato ----------
class _Feed extends StatelessWidget {
  final List<MatchEvent> events;
  final Color naranja;
  const _Feed({required this.events, required this.naranja});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      // ListView: recorta/scrollea si hay muchos eventos, nunca desborda.
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [for (final e in events.take(8)) _row(e)],
      ),
    );
  }

  Widget _row(MatchEvent e) {
    final isGoal = e.isGoal;
    final goalColor = e.team == MatchTeam.local ? AppColors.verde : naranja;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "${e.minute.toString().padLeft(2, '0')}'",
              style: const TextStyle(
                  color: AppColors.verde,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              e.text,
              style: TextStyle(
                color: isGoal ? goalColor : AppColors.texto,
                fontSize: 13,
                height: 1.25,
                fontWeight: isGoal ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Barra de resultado (al terminar) ----------
class _ResultBar extends ConsumerWidget {
  final int coins;
  final bool fromLeague;
  const _ResultBar({required this.coins, required this.fromLeague});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.verde2.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.verde.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on,
                  color: AppColors.pildora, size: 18),
              const SizedBox(width: 6),
              Text('+$coins',
                  style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ],
          ),
        ),
        const Spacer(),
        if (fromLeague)
          // Partido de liga: el resultado ya se guardó, se vuelve a la liga.
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pildora,
              foregroundColor: const Color(0xFF05210F),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.pop(),
            child: const Text('Continuar'),
          )
        else ...[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gris,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.pop(),
            child: const Text('Salir'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pildora,
              foregroundColor: const Color(0xFF05210F),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () =>
                ref.read(matchControllerProvider.notifier).restart(),
            child: const Text('Jugar de nuevo'),
          ),
        ],
      ],
    );
  }
}

// ---------- Fondo diagonal (arena) ----------
class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = AppColors.fondo);

    final topX = w * 0.56, botX = w * 0.44;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(topX, 0)
      ..lineTo(botX, h)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(topX, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(botX, h)
      ..close();

    canvas.drawPath(
      left,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.25),
          radius: 0.9,
          colors: [Color(0xFF0E3A24), Color(0xFF06140D)],
        ).createShader(all),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.35, -0.25),
          radius: 0.9,
          colors: [Color(0xFF3A1A10), Color(0xFF140A06)],
        ).createShader(all),
    );

    // Costura diagonal
    canvas.drawLine(
      Offset(topX, 0),
      Offset(botX, h),
      Paint()
        ..strokeWidth = 2
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x3AFFFFFF), Colors.transparent],
        ).createShader(all),
    );

    // Viñeta
    canvas.drawRect(
      all,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.0,
          colors: [Colors.transparent, Color(0x9E010503)],
          stops: [0.4, 1],
        ).createShader(all),
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => false;
}
