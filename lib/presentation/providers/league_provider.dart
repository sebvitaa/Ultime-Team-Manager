import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contador_app/data/league_teams.dart';
import 'package:contador_app/data/services/league_engine.dart';
import 'package:contador_app/domain/entities/league.dart';
import 'package:contador_app/domain/entities/league_team.dart';
import 'package:contador_app/presentation/providers/auth_provider.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';

const _groupNames = ['A', 'B', 'C', 'D'];

/// Liga JUGABLE (RF6): el usuario juega su partido en la pantalla de juego y el
/// resto se simula. Guarda todos los resultados y avanza por fases. Persiste
/// durante la sesión (Notifier sin autoDispose).
final leagueProvider =
    NotifierProvider<LeagueController, LeagueState>(LeagueController.new);

class LeagueController extends Notifier<LeagueState> {
  final _rng = Random();
  late String _ultimeName; // nombre del equipo del usuario en esta liga
  late LeagueTeam _ultime;
  late List<_WGroup> _groups;
  late List<List<_WFx>> _schedule; // 3 fechas x 8 partidos
  int _matchday = 0; // próxima fecha a jugar (0..3)
  LeaguePhase _phase = LeaguePhase.groups;
  List<_WTie> _quarters = [];
  List<_WTie> _semis = [];
  _WTie? _final;
  LeagueTeam? _champion;
  bool _eliminated = false;

  @override
  LeagueState build() {
    _init();
    return _snapshot();
  }

  // ---------------- API pública ----------------

  /// Vuelve a sortear y reiniciar la liga.
  void regenerate() {
    _init();
    state = _snapshot();
  }

  /// Registra el resultado del partido que jugó el usuario (Ultime local) y
  /// simula/guarda el resto de la fecha o ronda, avanzando la fase.
  void reportUltimeMatch(int ultimeGoals, int rivalGoals) {
    if (state.next == null) return; // nada pendiente
    if (_phase == LeaguePhase.groups) {
      _playGroupMatchday(ultimeGoals, rivalGoals);
    } else {
      _playKnockout(ultimeGoals, rivalGoals);
    }
    state = _snapshot();
  }

  // ---------------- inicialización ----------------

  void _init() {
    _ultimeName = ref.read(teamNameProvider);
    final avg = ref.read(squadControllerProvider).averageRating;
    final rating = (avg >= 1 ? avg.round() : 75).clamp(1, 99);
    _ultime = LeagueTeam(name: _ultimeName, country: '—', rating: rating);

    final teams = <LeagueTeam>[_ultime, ...kLeagueTeams]..shuffle(_rng);
    _groups = [
      for (var g = 0; g < 4; g++)
        _WGroup(_groupNames[g], teams.sublist(g * 4, g * 4 + 4)),
    ];
    _schedule = _buildSchedule();
    _matchday = 0;
    _phase = LeaguePhase.groups;
    _quarters = [];
    _semis = [];
    _final = null;
    _champion = null;
    _eliminated = false;
  }

  // Round-robin de 4: 3 fechas, 2 partidos por grupo cada fecha.
  List<List<_WFx>> _buildSchedule() {
    const rounds = [
      [[0, 1], [2, 3]],
      [[0, 2], [1, 3]],
      [[0, 3], [1, 2]],
    ];
    return [
      for (final round in rounds)
        [
          for (var gi = 0; gi < 4; gi++)
            for (final pair in round) _fixture(gi, pair[0], pair[1]),
        ],
    ];
  }

  // Ultime siempre de local en su partido (para la pantalla de juego).
  _WFx _fixture(int gi, int i, int j) {
    var a = _groups[gi].teams[i], b = _groups[gi].teams[j];
    if (b.name == _ultimeName) {
      final t = a;
      a = b;
      b = t;
    }
    return _WFx(gi, a, b);
  }

  // ---------------- fase de grupos ----------------

  void _playGroupMatchday(int ug, int rg) {
    for (final fx in _schedule[_matchday]) {
      if (fx.home.name == _ultimeName) {
        fx.hg = ug;
        fx.ag = rg;
      } else {
        final s = LeagueSim.score(fx.home, fx.away, _rng);
        fx.hg = s.$1;
        fx.ag = s.$2;
      }
      _applyStats(fx);
    }
    _matchday++;
    if (_matchday >= 3) _finishGroups();
  }

  void _applyStats(_WFx fx) {
    final g = _groups[fx.group];
    final home = g.stat(fx.home), away = g.stat(fx.away);
    final hg = fx.hg!, ag = fx.ag!;
    home.pj++;
    away.pj++;
    home.gf += hg;
    home.gc += ag;
    away.gf += ag;
    away.gc += hg;
    if (hg > ag) {
      home.g++;
      away.p++;
    } else if (hg < ag) {
      away.g++;
      home.p++;
    } else {
      home.e++;
      away.e++;
    }
  }

  void _finishGroups() {
    LeagueTeam pos(String name, int i) {
      final g = _groups.firstWhere((x) => x.name == name);
      return g.sorted()[i].team;
    }

    _quarters = [
      _WTie('Cuartos', pos('A', 0), pos('B', 1)),
      _WTie('Cuartos', pos('B', 0), pos('A', 1)),
      _WTie('Cuartos', pos('C', 0), pos('D', 1)),
      _WTie('Cuartos', pos('D', 0), pos('C', 1)),
    ];
    _phase = LeaguePhase.quarters;

    // ¿Ultime clasificó (top 2 de su grupo)?
    final myGroup =
        _groups.firstWhere((g) => g.teams.any((t) => t.name == _ultimeName));
    final myPos =
        myGroup.sorted().indexWhere((s) => s.team.name == _ultimeName);
    if (myPos >= 2) {
      _eliminated = true;
      _autoCompleteBracket();
    }
  }

  // ---------------- eliminatorias ----------------

  void _playKnockout(int ug, int rg) {
    final tie = _currentUltimeTie()!;
    _applyUltimeToTie(tie, ug, rg);

    // completar los demás cruces de esta ronda
    for (final t in _roundTies(_phase)) {
      _ensurePlayed(t);
    }

    final ultimeWon = tie.winner!.name == _ultimeName;
    if (!ultimeWon) {
      _eliminated = true;
      _autoCompleteBracket();
      return;
    }

    switch (_phase) {
      case LeaguePhase.quarters:
        _buildSemis();
        _phase = LeaguePhase.semis;
        break;
      case LeaguePhase.semis:
        _buildFinal();
        _phase = LeaguePhase.finalPhase;
        break;
      case LeaguePhase.finalPhase:
        _champion = tie.winner;
        _phase = LeaguePhase.done;
        break;
      default:
        break;
    }
  }

  void _applyUltimeToTie(_WTie t, int ug, int rg) {
    if (t.home.name == _ultimeName) {
      t.hg = ug;
      t.ag = rg;
    } else {
      t.hg = rg;
      t.ag = ug;
    }
    if (t.hg == t.ag) {
      final pk = LeagueSim.pens(t.home, t.away, _rng);
      t.hp = pk.$1;
      t.ap = pk.$2;
      t.pens = true;
    }
  }

  void _ensurePlayed(_WTie t) {
    if (t.played) return;
    final s = LeagueSim.score(t.home, t.away, _rng);
    t.hg = s.$1;
    t.ag = s.$2;
    if (t.hg == t.ag) {
      final pk = LeagueSim.pens(t.home, t.away, _rng);
      t.hp = pk.$1;
      t.ap = pk.$2;
      t.pens = true;
    }
  }

  void _buildSemis() {
    _semis = [
      _WTie('Semis', _quarters[0].winner!, _quarters[1].winner!),
      _WTie('Semis', _quarters[2].winner!, _quarters[3].winner!),
    ];
  }

  void _buildFinal() {
    _final = _WTie('Final', _semis[0].winner!, _semis[1].winner!);
  }

  // Simula todo lo que falte hasta el campeón (cuando Ultime queda eliminado).
  void _autoCompleteBracket() {
    for (final t in _quarters) {
      _ensurePlayed(t);
    }
    if (_semis.isEmpty) _buildSemis();
    for (final t in _semis) {
      _ensurePlayed(t);
    }
    _final ??= _WTie('Final', _semis[0].winner!, _semis[1].winner!);
    _ensurePlayed(_final!);
    _champion = _final!.winner;
    _phase = LeaguePhase.done;
  }

  List<_WTie> _roundTies(LeaguePhase phase) => switch (phase) {
        LeaguePhase.quarters => _quarters,
        LeaguePhase.semis => _semis,
        LeaguePhase.finalPhase => [?_final],
        _ => const [],
      };

  _WTie? _currentUltimeTie() {
    for (final t in _roundTies(_phase)) {
      if (!t.played &&
          (t.home.name == _ultimeName || t.away.name == _ultimeName)) {
        return t;
      }
    }
    return null;
  }

  // ---------------- snapshot ----------------

  UltimeFixture? _nextFixture() {
    if (_phase == LeaguePhase.groups && _matchday < 3) {
      final fx = _schedule[_matchday].firstWhere(
          (f) => f.home.name == _ultimeName || f.away.name == _ultimeName);
      final rival = fx.home.name == _ultimeName ? fx.away : fx.home;
      return UltimeFixture(rival, 'Fase de grupos · Fecha ${_matchday + 1}');
    }
    if (_eliminated || _phase == LeaguePhase.done) return null;
    final tie = _currentUltimeTie();
    if (tie == null) return null;
    final rival = tie.home.name == _ultimeName ? tie.away : tie.home;
    final label = switch (_phase) {
      LeaguePhase.quarters => 'Cuartos de final',
      LeaguePhase.semis => 'Semifinal',
      LeaguePhase.finalPhase => 'Final',
      _ => '',
    };
    return UltimeFixture(rival, label);
  }

  LeagueState _snapshot() {
    return LeagueState(
      groups: [
        for (final g in _groups) GroupView(g.name, g.standings()),
      ],
      matchday: _matchday,
      phase: _phase,
      quarters: _quarters.map((t) => t.view()).toList(),
      semis: _semis.map((t) => t.view()).toList(),
      finalTie: _final?.view(),
      champion: _champion,
      next: _nextFixture(),
      ultimeEliminated: _eliminated,
      ultimeName: _ultimeName,
    );
  }
}

// ---------------- estructuras internas (mutables) ----------------

class _WStat {
  final LeagueTeam team;
  int pj = 0, g = 0, e = 0, p = 0, gf = 0, gc = 0;
  _WStat(this.team);
  int get pts => g * 3 + e;
  int get dg => gf - gc;
}

class _WGroup {
  final String name;
  final List<LeagueTeam> teams;
  final Map<String, _WStat> _stats;
  _WGroup(this.name, this.teams)
      : _stats = {for (final t in teams) t.name: _WStat(t)};

  _WStat stat(LeagueTeam t) => _stats[t.name]!;

  List<_WStat> sorted() {
    final list = _stats.values.toList();
    list.sort((x, y) {
      if (y.pts != x.pts) return y.pts - x.pts;
      if (y.dg != x.dg) return y.dg - x.dg;
      return y.gf - x.gf;
    });
    return list;
  }

  List<TeamStanding> standings() => [
        for (final s in sorted())
          TeamStanding(s.team,
              played: s.pj,
              won: s.g,
              drawn: s.e,
              lost: s.p,
              goalsFor: s.gf,
              goalsAgainst: s.gc),
      ];
}

class _WFx {
  final int group;
  final LeagueTeam home;
  final LeagueTeam away;
  int? hg;
  int? ag;
  _WFx(this.group, this.home, this.away);
  bool get played => hg != null;
}

class _WTie {
  final String round;
  final LeagueTeam home;
  final LeagueTeam away;
  int? hg;
  int? ag;
  int hp = 0;
  int ap = 0;
  bool pens = false;
  _WTie(this.round, this.home, this.away);

  bool get played => hg != null;

  LeagueTeam? get winner {
    if (!played) return null;
    if (pens) return hp > ap ? home : away;
    return hg! > ag! ? home : away;
  }

  TieView view() => TieView(
        round: round,
        home: home,
        away: away,
        homeGoals: hg,
        awayGoals: ag,
        onPens: pens,
        homePens: hp,
        awayPens: ap,
      );
}
