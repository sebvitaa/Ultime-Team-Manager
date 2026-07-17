/// Tipos de evento que produce la simulación de un partido.
enum MatchEventType { kickoff, goal, commentary, fullTime }

/// A qué equipo pertenece un evento (los relatos/inicio/fin no tienen equipo).
enum MatchTeam { local, visita }

/// Un evento del partido en un minuto concreto: gol, relato, inicio o final.
class MatchEvent {
  final int minute; // 0..90
  final MatchEventType type;
  final MatchTeam? team; // null en relato, inicio y final
  final String text;

  const MatchEvent({
    required this.minute,
    required this.type,
    required this.text,
    this.team,
  });

  bool get isGoal => type == MatchEventType.goal;
}
