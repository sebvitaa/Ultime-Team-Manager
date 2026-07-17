import 'package:contador_app/domain/entities/match_event.dart';

/// Resultado completo de un partido simulado: marcador final y **todo** el
/// timeline de eventos (ya con su minuto). La UI luego solo lo va revelando.
class MatchResult {
  final String localName;
  final String visitaName;
  final int ratingLocal;
  final int ratingVisita;
  final int golLocal;
  final int golVisita;
  final List<MatchEvent> events; // orden cronológico: inicio -> ... -> final

  const MatchResult({
    required this.localName,
    required this.visitaName,
    required this.ratingLocal,
    required this.ratingVisita,
    required this.golLocal,
    required this.golVisita,
    required this.events,
  });

  bool get localWon => golLocal > golVisita;
  bool get isDraw => golLocal == golVisita;
  bool get visitaWon => golVisita > golLocal;

  String get scoreline => '$golLocal - $golVisita';
}
