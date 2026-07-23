import 'dart:math';

import 'package:ultimate_team_manager/data/league_teams.dart';
import 'package:ultimate_team_manager/data/services/league_engine.dart';
import 'package:ultimate_team_manager/domain/entities/league.dart';
import 'package:ultimate_team_manager/presentation/providers/league_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/squad_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Squad falso: evita cargar assets; deja media 0 -> la liga usa 75 por defecto.
class _FakeSquad extends SquadController {
  @override
  SquadState build() => const SquadState();
}

void main() {
  group('LeagueSim', () {
    test('pens nunca termina en empate', () {
      final r = Random(2);
      for (var i = 0; i < 100; i++) {
        final (a, b) = LeagueSim.pens(kLeagueTeams[0], kLeagueTeams[1], r);
        expect(a == b, isFalse);
      }
    });

    test('el favorito marca más goles en promedio', () {
      final r = Random(3);
      final fuerte = kLeagueTeams.firstWhere((t) => t.rating == 85);
      final debil = kLeagueTeams.firstWhere((t) => t.rating == 79);
      var gf = 0, gc = 0;
      for (var i = 0; i < 300; i++) {
        final (a, b) = LeagueSim.score(fuerte, debil, r);
        gf += a;
        gc += b;
      }
      expect(gf, greaterThan(gc));
    });
  });

  group('LeagueController (flujo jugable)', () {
    ProviderContainer makeContainer() => ProviderContainer(overrides: [
          squadControllerProvider.overrideWith(() => _FakeSquad()),
        ]);

    test('arranca en grupos: 4 grupos de 4 y un partido pendiente', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final s = c.read(leagueProvider);
      expect(s.phase, LeaguePhase.groups);
      expect(s.groups.length, 4);
      for (final g in s.groups) {
        expect(g.table.length, 4);
      }
      expect(s.matchday, 0);
      expect(s.next, isNotNull);
    });

    test('jugar 3 fechas cierra los grupos y arma el bracket', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(leagueProvider.notifier);
      for (var i = 0; i < 3; i++) {
        ctrl.reportUltimeMatch(3, 0); // Ultime golea cada fecha
      }
      final s = c.read(leagueProvider);
      for (final g in s.groups) {
        for (final t in g.table) {
          expect(t.played, 3); // se guardaron todos los partidos
        }
      }
      expect(s.quarters.length, 4);
      expect(s.phase, isNot(LeaguePhase.groups));
    });

    test('ganando siempre, Ultime FC termina campeón', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(leagueProvider.notifier);
      var guard = 0;
      while (c.read(leagueProvider).next != null && guard < 20) {
        ctrl.reportUltimeMatch(3, 0);
        guard++;
      }
      final s = c.read(leagueProvider);
      expect(s.phase, LeaguePhase.done);
      expect(s.champion?.name, 'Ultime FC');
    });
  });
}
