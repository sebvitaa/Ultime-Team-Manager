import 'dart:math';

import 'package:ultime_team_manager/core/services/match_simulator.dart';
import 'package:ultime_team_manager/domain/entities/league_team.dart';

/// Helpers puros de simulación para la liga (RF6). El marcador de cada partido
/// sale del mismo modelo de goles por media que [MatchSimulator]; usados tanto
/// para los partidos que juega el usuario (resultado real) como para simular
/// automáticamente el resto.
class LeagueSim {
  /// Marcador de un partido [a] (local) vs [b] (visita).
  static (int, int) score(LeagueTeam a, LeagueTeam b, Random r) {
    final res = MatchSimulator.simulate(
      localName: a.name,
      ratingLocal: a.rating,
      visitaName: b.name,
      ratingVisita: b.rating,
      rng: r,
    );
    return (res.golLocal, res.golVisita);
  }

  /// Tanda de penales (favorece a la media más alta). Devuelve (penal a, penal b).
  static (int, int) pens(LeagueTeam a, LeagueTeam b, Random r) {
    final aWins = r.nextDouble() < a.rating / (a.rating + b.rating);
    final perdedor = 2 + r.nextInt(3); // 2..4
    final ganador = perdedor + 1; // marcador tipo 4-3
    return aWins ? (ganador, perdedor) : (perdedor, ganador);
  }
}
