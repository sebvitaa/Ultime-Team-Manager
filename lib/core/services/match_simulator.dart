import 'dart:math';

import 'package:ultime_team_manager/domain/entities/match_event.dart';
import 'package:ultime_team_manager/domain/entities/match_result.dart';

/// Motor de simulación de partidos (RF5), **lógica pura y testeable** (sin UI).
///
/// - Punto 2: goles esperados (λ) según la valoración media de cada equipo.
/// - Punto 3: reparto de goles minuto a minuto (proceso tipo Poisson).
/// - Punto 4: relato de eventos (~30 frases, en minutos aleatorios).
/// - Punto 5: reloj de reproducción ([playback]) que revela el timeline.
class MatchSimulator {
  // --- Punto 2: constantes del modelo de goles esperados ---
  static const double base = 1.35; // goles medios por equipo y partido
  static const double k = 1.8; // cuánto pesa la diferencia de nivel
  static const double homeAdvantage = 1.15; // empujón del local

  static const int minutes = 90;

  // --- Punto 4: probabilidad de relato por minuto (Poisson ~1/6) ---
  static const double commentaryRate = 1 / 6;

  // --- Punto 5: ritmo del "en vivo" (un partido dura ~20 s) ---
  static const Duration matchDuration = Duration(seconds: 20);
  static Duration get perMinute =>
      Duration(milliseconds: matchDuration.inMilliseconds ~/ minutes);

  /// Simula el partido completo y devuelve el [MatchResult] con todo el timeline.
  /// Pasa una [rng] con semilla fija para resultados reproducibles (tests).
  static MatchResult simulate({
    required String localName,
    required int ratingLocal,
    required String visitaName,
    required int ratingVisita,
    Random? rng,
  }) {
    final r = rng ?? Random();

    // Punto 2: goles esperados por equipo (cociente de medias + ventaja local).
    final lamLocal =
        base * pow(ratingLocal / ratingVisita, k) * homeAdvantage;
    final lamVisita = base * pow(ratingVisita / ratingLocal, k);
    final pLocal = lamLocal / minutes; // prob. de gol local por minuto
    final pVisita = lamVisita / minutes; // prob. de gol visita por minuto

    final events = <MatchEvent>[
      const MatchEvent(
        minute: 0,
        type: MatchEventType.kickoff,
        text: 'Rueda el balón. ¡Comienza el partido!',
      ),
    ];

    var golLocal = 0, golVisita = 0;
    var goalLastMinute = false; // ¿hubo gol en el minuto anterior?
    var lastPhrase = -1; // evita repetir la frase inmediatamente anterior

    // Punto 3: se recorre minuto a minuto.
    for (var m = 1; m <= minutes; m++) {
      var goalThisMinute = false;

      if (r.nextDouble() < pLocal) {
        golLocal++;
        goalThisMinute = true;
        events.add(MatchEvent(
          minute: m,
          type: MatchEventType.goal,
          team: MatchTeam.local,
          text: _goalText(r, localName),
        ));
      }
      if (r.nextDouble() < pVisita) {
        golVisita++;
        goalThisMinute = true;
        events.add(MatchEvent(
          minute: m,
          type: MatchEventType.goal,
          team: MatchTeam.visita,
          text: _goalText(r, visitaName),
        ));
      }

      // Punto 4: relato en minuto aleatorio (1/6), solo si NO hubo gol en este
      // minuto ni en el anterior (para no pisar la narración de un gol).
      if (!goalThisMinute &&
          !goalLastMinute &&
          r.nextDouble() < commentaryRate) {
        var idx = r.nextInt(_phrases.length);
        while (idx == lastPhrase && _phrases.length > 1) {
          idx = r.nextInt(_phrases.length);
        }
        lastPhrase = idx;
        events.add(MatchEvent(
          minute: m,
          type: MatchEventType.commentary,
          text: _phrases[idx]
              .replaceAll('{local}', localName)
              .replaceAll('{visita}', visitaName),
        ));
      }

      goalLastMinute = goalThisMinute;
    }

    events.add(MatchEvent(
      minute: minutes,
      type: MatchEventType.fullTime,
      text:
          'Final del partido. $localName $golLocal - $golVisita $visitaName.',
    ));

    return MatchResult(
      localName: localName,
      visitaName: visitaName,
      ratingLocal: ratingLocal,
      ratingVisita: ratingVisita,
      golLocal: golLocal,
      golVisita: golVisita,
      events: events,
    );
  }

  /// Punto 5: "reproduce" un resultado ya simulado minuto a minuto, emitiendo
  /// un [MatchSnapshot] por cada minuto al ritmo de [perMinute]. Es lógica pura
  /// (un `Stream`), sin UI: el controlador/pantalla se limita a escucharlo.
  static Stream<MatchSnapshot> playback(
    MatchResult result, {
    Duration? perMinute,
  }) async* {
    final step = perMinute ?? MatchSimulator.perMinute;
    var golLocal = 0, golVisita = 0;

    for (var m = 0; m <= minutes; m++) {
      final atMinute = result.events.where((e) => e.minute == m).toList();
      for (final e in atMinute) {
        if (e.isGoal) {
          if (e.team == MatchTeam.local) {
            golLocal++;
          } else {
            golVisita++;
          }
        }
      }
      yield MatchSnapshot(
        minute: m,
        golLocal: golLocal,
        golVisita: golVisita,
        newEvents: atMinute,
      );
      if (m < minutes) await Future.delayed(step);
    }
  }

  static const _goalPhrases = <String>[
    '¡GOOOL de {team}! Remate imposible para el arquero.',
    '¡GOOOL de {team}! Definición cruzada al segundo palo.',
    '¡GOOOL de {team}! Cabezazo tras un gran centro.',
    '¡GOOOL de {team}! Zurdazo desde fuera del área.',
    '¡GOOOL de {team}! Contragolpe letal y a marcar.',
    '¡GOOOL de {team}! Aprovecha un rebote dentro del área.',
    '¡GOOOL de {team}! Cambia el penal por gol.',
    '¡GOOOL de {team}! Toque sutil para picar al portero.',
  ];

  static String _goalText(Random r, String team) =>
      _goalPhrases[r.nextInt(_goalPhrases.length)].replaceAll('{team}', team);

  // ~30 frases de relato para que no suene repetitivo.
  static const _phrases = <String>[
    'Circula el balón por el mediocampo sin apuro.',
    '{local} adelanta líneas y presiona arriba.',
    '{visita} recupera y sale rápido al contragolpe.',
    'Centro al área, la defensa despeja de cabeza.',
    'Falta peligrosa cerca del borde del área.',
    'Pase filtrado, pero se anticipa el arquero.',
    'Remate desde lejos que se va desviado.',
    'Gran jugada individual que termina en córner.',
    'El árbitro deja seguir una acción dudosa.',
    'Cambio de frente y el juego se abre a las bandas.',
    '{local} domina la posesión en este tramo.',
    '{visita} se cierra bien y aguanta atrás.',
    'Amarilla por una entrada dura en la mitad de la cancha.',
    'Tiro de esquina que despeja el primer palo.',
    'El delantero cae en el área, el árbitro no cobra nada.',
    'Contra rápida que la defensa corta a tiempo.',
    'Buena combinación por la banda derecha.',
    'El portero achica y ahoga el grito de gol.',
    'Balón largo que controla el central sin problemas.',
    'Ritmo alto de partido, ida y vuelta constante.',
    'Se pierde una clarísima {local} de cara al arco.',
    '{visita} responde con un mano a mano salvado.',
    'El mediocampo se adueña del control del juego.',
    'Robo en tres cuartos y llega el peligro.',
    'Disparo a la barrera tras el tiro libre.',
    'Pausa en el juego por atención a un jugador.',
    'El técnico pide más intensidad desde la banda.',
    'Amague y sombrero para dejar atrás a la marca.',
    'Dominan las marcas, pocas opciones claras.',
    'El público empuja a {local} en busca del gol.',
  ];
}

/// Estado del partido en un minuto concreto, emitido por [MatchSimulator.playback].
class MatchSnapshot {
  final int minute;
  final int golLocal;
  final int golVisita;
  final List<MatchEvent> newEvents; // eventos ocurridos en este minuto

  const MatchSnapshot({
    required this.minute,
    required this.golLocal,
    required this.golVisita,
    required this.newEvents,
  });
}
