import 'dart:math';

import 'package:ultime_team_manager/core/services/match_simulator.dart';
import 'package:ultime_team_manager/domain/entities/match_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchSimulator', () {
    test('el marcador coincide con la cantidad de eventos de gol', () {
      for (var seed = 0; seed < 50; seed++) {
        final res = MatchSimulator.simulate(
          localName: 'Ultime FC',
          ratingLocal: 78,
          visitaName: 'Real Madrid',
          ratingVisita: 85,
          rng: Random(seed),
        );
        final golesLocal = res.events
            .where((e) => e.isGoal && e.team == MatchTeam.local)
            .length;
        final golesVisita = res.events
            .where((e) => e.isGoal && e.team == MatchTeam.visita)
            .length;
        expect(res.golLocal, golesLocal);
        expect(res.golVisita, golesVisita);
      }
    });

    test('no hay relato en un minuto con gol ni justo después', () {
      final res = MatchSimulator.simulate(
        localName: 'A',
        ratingLocal: 80,
        visitaName: 'B',
        ratingVisita: 80,
        rng: Random(7),
      );
      final golMinutes = res.events
          .where((e) => e.isGoal)
          .map((e) => e.minute)
          .toSet();
      for (final e in res.events) {
        if (e.type == MatchEventType.commentary) {
          expect(golMinutes.contains(e.minute), isFalse,
              reason: 'relato en minuto con gol (${e.minute})');
          expect(golMinutes.contains(e.minute - 1), isFalse,
              reason: 'relato justo tras un gol (${e.minute})');
        }
      }
    });

    test('empieza en kickoff (0) y termina en fullTime (90), en orden', () {
      final res = MatchSimulator.simulate(
        localName: 'A',
        ratingLocal: 82,
        visitaName: 'B',
        ratingVisita: 79,
        rng: Random(3),
      );
      expect(res.events.first.type, MatchEventType.kickoff);
      expect(res.events.first.minute, 0);
      expect(res.events.last.type, MatchEventType.fullTime);
      expect(res.events.last.minute, 90);
      for (var i = 1; i < res.events.length; i++) {
        expect(res.events[i].minute >= res.events[i - 1].minute, isTrue);
      }
    });

    test('el favorito marca más goles en promedio', () {
      var golesFuerte = 0, golesDebil = 0;
      for (var seed = 0; seed < 200; seed++) {
        final res = MatchSimulator.simulate(
          localName: 'Fuerte',
          ratingLocal: 88,
          visitaName: 'Debil',
          ratingVisita: 72,
          rng: Random(seed),
        );
        golesFuerte += res.golLocal;
        golesDebil += res.golVisita;
      }
      expect(golesFuerte, greaterThan(golesDebil));
    });
  });
}
