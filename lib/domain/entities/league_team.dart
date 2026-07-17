/// Un equipo de la liga con una valoración media **estimada** (dato artificial,
/// no viene de la API). Sirve como rival en la simulación de partidos.
class LeagueTeam {
  final String name;
  final String country;
  final int rating; // media estimada, escala 1-100

  const LeagueTeam({
    required this.name,
    required this.country,
    required this.rating,
  });
}
