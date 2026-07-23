import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultimate_team_manager/core/services/match_simulator.dart';
import 'package:ultimate_team_manager/data/league_teams.dart';
import 'package:ultimate_team_manager/domain/entities/match_event.dart';
import 'package:ultimate_team_manager/domain/entities/match_result.dart';
import 'package:ultimate_team_manager/presentation/providers/coins_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/league_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/squad_provider.dart';

enum MatchPhase { playing, finished }

/// Rival concreto para el próximo partido (lo pone la liga antes de ir a jugar).
/// Si es null, la pantalla juega un amistoso contra un rival aleatorio.
class MatchRequest {
  final String rivalName;
  final int rivalRating;
  const MatchRequest({required this.rivalName, required this.rivalRating});
}

final matchRequestProvider = StateProvider<MatchRequest?>((ref) => null);

/// Estado del partido que observa la pantalla. Los eventos van de más nuevo a
/// más viejo (para pintar el relato con el último arriba).
class MatchState {
  final String localName;
  final String visitaName;
  final int ratingLocal;
  final int ratingVisita;
  final int minute;
  final int golLocal;
  final int golVisita;
  final List<MatchEvent> events;
  final MatchPhase phase;
  final int coinsAwarded;
  final bool fromLeague; // partido de liga (no amistoso)

  const MatchState({
    this.localName = '',
    this.visitaName = '',
    this.ratingLocal = 0,
    this.ratingVisita = 0,
    this.minute = 0,
    this.golLocal = 0,
    this.golVisita = 0,
    this.events = const [],
    this.phase = MatchPhase.playing,
    this.coinsAwarded = 0,
    this.fromLeague = false,
  });

  MatchState copyWith({
    int? minute,
    int? golLocal,
    int? golVisita,
    List<MatchEvent>? events,
    MatchPhase? phase,
    int? coinsAwarded,
  }) {
    return MatchState(
      localName: localName,
      visitaName: visitaName,
      ratingLocal: ratingLocal,
      ratingVisita: ratingVisita,
      minute: minute ?? this.minute,
      golLocal: golLocal ?? this.golLocal,
      golVisita: golVisita ?? this.golVisita,
      events: events ?? this.events,
      phase: phase ?? this.phase,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      fromLeague: fromLeague,
    );
  }
}

/// autoDispose: cada vez que entras a la pantalla se juega un partido nuevo
/// (al salir se cancela la reproducción).
final matchControllerProvider =
    NotifierProvider.autoDispose<MatchController, MatchState>(
        MatchController.new);

class MatchController extends AutoDisposeNotifier<MatchState> {
  StreamSubscription<MatchSnapshot>? _sub;
  bool _fromLeague = false;

  @override
  MatchState build() {
    ref.onDispose(() => _sub?.cancel());
    return _newMatch();
  }

  // Arranca un partido nuevo. Si la liga dejó un rival (matchRequest), juega
  // contra ese; si no, contra un rival aleatorio (amistoso).
  MatchState _newMatch() {
    final rng = Random();
    final req = ref.read(matchRequestProvider);
    final avg = ref.read(squadControllerProvider).averageRating;
    final ratingLocal = (avg >= 1 ? avg.round() : 75).clamp(1, 99);
    const localName = 'Ultime FC';

    final String visitaName;
    final int ratingVisita;
    if (req != null) {
      visitaName = req.rivalName;
      ratingVisita = req.rivalRating;
      _fromLeague = true;
    } else {
      final rival = randomRival(rng, exclude: 'Real Madrid');
      visitaName = rival.name;
      ratingVisita = rival.rating;
      _fromLeague = false;
    }

    final result = MatchSimulator.simulate(
      localName: localName,
      ratingLocal: ratingLocal,
      visitaName: visitaName,
      ratingVisita: ratingVisita,
      rng: rng,
    );

    _sub?.cancel();
    _sub = MatchSimulator.playback(result).listen((snap) {
      final revealed = snap.newEvents.reversed.toList(); // más nuevo primero
      state = state.copyWith(
        minute: snap.minute,
        golLocal: snap.golLocal,
        golVisita: snap.golVisita,
        events: [...revealed, ...state.events],
      );
      if (snap.minute >= MatchSimulator.minutes) _finish(result);
    });

    return MatchState(
      localName: localName,
      visitaName: visitaName,
      ratingLocal: ratingLocal,
      ratingVisita: ratingVisita,
      phase: MatchPhase.playing,
      fromLeague: _fromLeague,
    );
  }

  // Al terminar reparte monedas y, si es de liga, guarda el resultado.
  void _finish(MatchResult result) {
    final coins = _reward(result.golLocal, result.golVisita);
    ref.read(coinsProvider.notifier).earn(coins);
    if (_fromLeague) {
      ref
          .read(leagueProvider.notifier)
          .reportUltimeMatch(result.golLocal, result.golVisita);
    }
    state = state.copyWith(phase: MatchPhase.finished, coinsAwarded: coins);
  }

  // Vuelve a jugar (solo amistosos; en liga se usa "Continuar").
  void restart() {
    if (_fromLeague) return;
    _sub?.cancel();
    state = _newMatch();
  }

  static int _reward(int golFavor, int golContra) {
    if (golFavor > golContra) return 500 + 50 * golFavor; // victoria
    if (golFavor == golContra) return 200; // empate
    return 75; // derrota (algo, para no frustrar)
  }
}
