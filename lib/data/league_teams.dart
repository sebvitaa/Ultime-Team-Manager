import 'dart:math';

import 'package:ultime_team_manager/domain/entities/league_team.dart';

/// Liga artificial: los 15 mejores clubes del mundo (principalmente Europa) con
/// valoraciones **estimadas**. Son los rivales de la simulación de partidos.
const List<LeagueTeam> kLeagueTeams = [
  LeagueTeam(name: 'Manchester City', country: 'Inglaterra', rating: 85),
  LeagueTeam(name: 'Real Madrid', country: 'España', rating: 85),
  LeagueTeam(name: 'Bayern München', country: 'Alemania', rating: 84),
  LeagueTeam(name: 'Arsenal', country: 'Inglaterra', rating: 83),
  LeagueTeam(name: 'Liverpool', country: 'Inglaterra', rating: 83),
  LeagueTeam(name: 'Inter de Milán', country: 'Italia', rating: 82),
  LeagueTeam(name: 'Paris Saint-Germain', country: 'Francia', rating: 82),
  LeagueTeam(name: 'Barcelona', country: 'España', rating: 82),
  LeagueTeam(name: 'Atlético de Madrid', country: 'España', rating: 81),
  LeagueTeam(name: 'Bayer Leverkusen', country: 'Alemania', rating: 81),
  LeagueTeam(name: 'Borussia Dortmund', country: 'Alemania', rating: 80),
  LeagueTeam(name: 'Juventus', country: 'Italia', rating: 80),
  LeagueTeam(name: 'AC Milan', country: 'Italia', rating: 80),
  LeagueTeam(name: 'Napoli', country: 'Italia', rating: 79),
  LeagueTeam(name: 'Tottenham', country: 'Inglaterra', rating: 79),
];

/// Elige un rival al azar, opcionalmente excluyendo un club por nombre (p. ej.
/// el propio equipo del usuario si comparte nombre con uno de la lista).
LeagueTeam randomRival(Random rng, {String? exclude}) {
  final pool = exclude == null
      ? kLeagueTeams
      : kLeagueTeams.where((t) => t.name != exclude).toList();
  return pool[rng.nextInt(pool.length)];
}
