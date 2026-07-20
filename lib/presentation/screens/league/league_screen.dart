import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/league.dart';
import 'package:contador_app/domain/entities/league_team.dart';
import 'package:contador_app/presentation/providers/league_provider.dart';
import 'package:contador_app/presentation/providers/match_provider.dart';

const _maxW = 560.0;

/// Liga jugable (RF6): juegas tu partido, se simula el resto y avanza por fases.
class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leagueProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          backgroundColor: AppColors.fondo,
          foregroundColor: AppColors.texto,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Liga Ultime',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          actions: [
            IconButton(
              tooltip: 'Nueva liga',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(leagueProvider.notifier).regenerate(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PhaseStepper(phase: data.phase),
                const TabBar(
                  indicatorColor: AppColors.verde,
                  labelColor: AppColors.texto,
                  unselectedLabelColor: AppColors.gris,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: [Tab(text: 'Grupos'), Tab(text: 'Eliminatorias')],
                ),
              ],
            ),
          ),
        ),
        // Cuerpo + barra de acción en una Column (no bottomNavigationBar, que
        // se descolocaba en pantallas anchas).
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _GroupsView(data),
                  _BracketView(data),
                ],
              ),
            ),
            _ActionBar(data),
          ],
        ),
      ),
    );
  }
}

// ---------------- Indicador de fases ----------------
class _PhaseStepper extends StatelessWidget {
  final LeaguePhase phase;
  const _PhaseStepper({required this.phase});

  int get _current => switch (phase) {
        LeaguePhase.groups => 0,
        LeaguePhase.quarters => 1,
        LeaguePhase.semis => 2,
        LeaguePhase.finalPhase => 3,
        LeaguePhase.done => 3,
      };

  @override
  Widget build(BuildContext context) {
    const labels = ['Grupos', 'Cuartos', 'Semis', 'Final'];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxW),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(child: _pill(labels[i], i)),
                if (i < labels.length - 1)
                  const Icon(Icons.chevron_right,
                      size: 14, color: AppColors.gris),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, int i) {
    final current = i == _current;
    final done = i < _current;
    final bg = current
        ? AppColors.verde
        : (done
            ? AppColors.verde2.withValues(alpha: 0.25)
            : Colors.transparent);
    final fg = current
        ? const Color(0xFF04150D)
        : (done ? AppColors.verde : AppColors.gris);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: (current || done) ? Colors.transparent : AppColors.borde),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

// ---------------- Barra de acción: Jugar / Campeón ----------------
class _ActionBar extends ConsumerWidget {
  final LeagueState data;
  const _ActionBar(this.data);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = data.next;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.carbon,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxW),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: next != null
                  ? _NextRow(next: next, ultimeName: data.ultimeName)
                  : _EndRow(data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextRow extends ConsumerWidget {
  final UltimeFixture next;
  final String ultimeName;
  const _NextRow({required this.next, required this.ultimeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SIGUIENTE',
                  style: TextStyle(
                      color: AppColors.gris, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text('$ultimeName  vs  ${next.rival.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              Text(next.label,
                  style:
                      const TextStyle(color: AppColors.gris, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pildora,
            foregroundColor: const Color(0xFF05210F),
            shape: const StadiumBorder(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          ),
          onPressed: () {
            ref.read(matchRequestProvider.notifier).state = MatchRequest(
              rivalName: next.rival.name,
              rivalRating: next.rival.rating,
            );
            context.push('/match');
          },
          child: const Text('Jugar',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _EndRow extends ConsumerWidget {
  final LeagueState data;
  const _EndRow({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final champ = data.champion?.name ?? '';
    final youWon = champ == data.ultimeName;
    return Row(
      children: [
        const Icon(Icons.emoji_events, color: AppColors.oro, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(youWon ? '¡Eres campeón!' : 'Campeón: $champ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              if (data.ultimeEliminated)
                Text('${data.ultimeName} quedó eliminado',
                    style: const TextStyle(
                        color: AppColors.gris, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.verde2,
            foregroundColor: AppColors.texto,
            shape: const StadiumBorder(),
          ),
          onPressed: () => ref.read(leagueProvider.notifier).regenerate(),
          child: const Text('Nueva liga'),
        ),
      ],
    );
  }
}

// ---------------- Grupos ----------------
class _GroupsView extends StatelessWidget {
  final LeagueState data;
  const _GroupsView(this.data);

  @override
  Widget build(BuildContext context) {
    final fecha = data.phase == LeaguePhase.groups
        ? 'Fase de grupos · ${data.matchday} de 3 fechas jugadas'
        : 'Fase de grupos finalizada';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, color: AppColors.verde),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(fecha,
                        style: const TextStyle(
                            color: AppColors.gris, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final g in data.groups) ...[
                _GroupCard(g, data.ultimeName),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupView group;
  final String ultimeName;
  const _GroupCard(this.group, this.ultimeName);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GRUPO ${group.name}',
                    style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1)),
                const Text('Clasifican 2',
                    style: TextStyle(color: AppColors.gris, fontSize: 11)),
              ],
            ),
          ),
          const _HeaderRow(),
          for (var i = 0; i < group.table.length; i++)
            _TeamRow(
                pos: i + 1,
                s: group.table[i],
                qualifies: i < 2,
                ultimeName: ultimeName),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(
        color: AppColors.gris,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .5);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text('#', style: st)),
          Expanded(child: Text('EQUIPO', style: st)),
          SizedBox(
              width: 28,
              child: Text('PJ', style: st, textAlign: TextAlign.center)),
          SizedBox(
              width: 36,
              child: Text('DG', style: st, textAlign: TextAlign.center)),
          SizedBox(
              width: 30,
              child: Text('PTS', style: st, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final int pos;
  final TeamStanding s;
  final bool qualifies;
  final String ultimeName;
  const _TeamRow({
    required this.pos,
    required this.s,
    required this.qualifies,
    required this.ultimeName,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = s.team.name == ultimeName;
    final dg = s.goalDiff;
    return Container(
      decoration: BoxDecoration(
        color: qualifies ? AppColors.verde.withValues(alpha: 0.07) : null,
        border: Border(
          left: BorderSide(
              color: qualifies ? AppColors.verde : Colors.transparent,
              width: 3),
          top: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$pos',
                style: TextStyle(
                    color: qualifies ? AppColors.verde : AppColors.gris,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5)),
          ),
          Expanded(
            child: Text(s.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isMe ? AppColors.verde : AppColors.texto,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13)),
          ),
          _cell('${s.played}', 28),
          _cell(dg > 0 ? '+$dg' : '$dg', 36),
          _cell('${s.points}', 30, bold: true),
        ],
      ),
    );
  }

  Widget _cell(String t, double w, {bool bold = false}) => SizedBox(
        width: w,
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.texto,
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
      );
}

// ---------------- Eliminatorias ----------------
class _BracketView extends StatelessWidget {
  final LeagueState data;
  const _BracketView(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.quarters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Las eliminatorias se definen al terminar la fase de grupos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gris, fontSize: 14),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundColumn('Cuartos', [
              for (final t in data.quarters) _MatchCard(t, data.ultimeName),
            ]),
            _RoundColumn('Semis', [
              if (data.semis.isEmpty) ...[
                const _Placeholder(),
                const _Placeholder(),
              ] else
                for (final t in data.semis) _MatchCard(t, data.ultimeName),
            ]),
            _RoundColumn('Final', [
              if (data.finalTie == null)
                const _Placeholder()
              else
                _MatchCard(data.finalTie!, data.ultimeName),
            ]),
            _RoundColumn('Campeón', [
              _ChampionCard(champion: data.champion?.name),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  final String label;
  final List<Widget> cards;
  const _RoundColumn(this.label, this.cards);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.gris,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
          ),
          for (final c in cards) ...[c, const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final TieView tie;
  final String ultimeName;
  const _MatchCard(this.tie, this.ultimeName);

  @override
  Widget build(BuildContext context) {
    final hasMe =
        tie.home.name == ultimeName || tie.away.name == ultimeName;
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hasMe
                ? AppColors.verde.withValues(alpha: 0.45)
                : AppColors.borde),
      ),
      child: Column(
        children: [
          _row(tie.home, tie.homeGoals, tie.homePens, tie.isWinner(tie.home)),
          const Divider(height: 1, color: Color(0x0FFFFFFF)),
          _row(tie.away, tie.awayGoals, tie.awayPens, tie.isWinner(tie.away)),
        ],
      ),
    );
  }

  Widget _row(LeagueTeam team, int? goals, int pens, bool win) {
    final played = goals != null;
    final score = !played ? '–' : (tie.onPens ? '$goals ($pens)' : '$goals');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: win ? AppColors.verde : AppColors.texto,
                    fontSize: 12.5,
                    fontWeight: win ? FontWeight.w800 : FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Text(score,
              style: TextStyle(
                  color: win ? AppColors.verde : AppColors.gris,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: const Text('Por definir',
          style: TextStyle(color: AppColors.gris, fontSize: 12)),
    );
  }
}

class _ChampionCard extends StatelessWidget {
  final String? champion;
  const _ChampionCard({required this.champion});

  @override
  Widget build(BuildContext context) {
    if (champion == null) return const _Placeholder();
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.oro.withValues(alpha: 0.16), AppColors.carbon],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.oro.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.oro, size: 44),
          const SizedBox(height: 8),
          Text(champion!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          const SizedBox(height: 3),
          const Text('CAMPEÓN',
              style: TextStyle(
                  color: AppColors.oro,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
        ],
      ),
    );
  }
}
