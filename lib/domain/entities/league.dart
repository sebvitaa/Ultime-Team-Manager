import 'package:ultimate_team_manager/domain/entities/league_team.dart';

/// Fase actual de la liga.
enum LeaguePhase { groups, quarters, semis, finalPhase, done }

/// Fila de la tabla de un grupo (inmutable, para la UI).
class TeamStanding {
  final LeagueTeam team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  const TeamStanding(
    this.team, {
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get points => won * 3 + drawn;
  int get goalDiff => goalsFor - goalsAgainst;
}

/// Un grupo con su tabla ya ordenada.
class GroupView {
  final String name;
  final List<TeamStanding> table;
  const GroupView(this.name, this.table);
}

/// Un cruce de eliminatoria (puede estar jugado o no).
class TieView {
  final String round;
  final LeagueTeam home;
  final LeagueTeam away;
  final int? homeGoals;
  final int? awayGoals;
  final bool onPens;
  final int homePens;
  final int awayPens;

  const TieView({
    required this.round,
    required this.home,
    required this.away,
    this.homeGoals,
    this.awayGoals,
    this.onPens = false,
    this.homePens = 0,
    this.awayPens = 0,
  });

  bool get played => homeGoals != null;

  LeagueTeam? get winner {
    if (!played) return null;
    if (onPens) return homePens > awayPens ? home : away;
    return homeGoals! > awayGoals! ? home : away;
  }

  bool isWinner(LeagueTeam t) => winner != null && t.name == winner!.name;
}

/// El próximo partido que debe jugar el usuario (Ultime FC).
class UltimeFixture {
  final LeagueTeam rival;
  final String label; // "Fase de grupos · Fecha 2", "Cuartos de final", ...
  const UltimeFixture(this.rival, this.label);
}

/// Snapshot completo de la liga que observa la UI.
class LeagueState {
  final List<GroupView> groups;
  final int matchday; // fechas jugadas de la fase de grupos (0..3)
  final LeaguePhase phase;
  final List<TieView> quarters; // vacío hasta terminar los grupos
  final List<TieView> semis;
  final TieView? finalTie;
  final LeagueTeam? champion;
  final UltimeFixture? next; // null si Ultime no juega (eliminado / terminado)
  final bool ultimeEliminated;

  const LeagueState({
    required this.groups,
    required this.matchday,
    required this.phase,
    required this.quarters,
    required this.semis,
    required this.finalTie,
    required this.champion,
    required this.next,
    required this.ultimeEliminated,
  });
}
