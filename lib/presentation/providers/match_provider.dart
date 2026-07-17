import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contador_app/core/services/match_simulator.dart';
import 'package:contador_app/data/league_teams.dart';
import 'package:contador_app/domain/entities/match_event.dart';
import 'package:contador_app/domain/entities/match_result.dart';
import 'package:contador_app/presentation/providers/coins_provider.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';

enum MatchPhase { playing, finished }

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

  @override
  MatchState build() {
    ref.onDispose(() => _sub?.cancel());
    return _newMatch();
  }

  // Arranca un partido nuevo: elige rival, simula y reproduce minuto a minuto.
  MatchState _newMatch() {
    final rng = Random();
    final rival = randomRival(rng, exclude: 'Real Madrid');
    final avg = ref.read(squadControllerProvider).averageRating;
    final ratingLocal = (avg >= 1 ? avg.round() : 75).clamp(1, 99);
    const localName = 'Ultime FC';

    final result = MatchSimulator.simulate(
      localName: localName,
      ratingLocal: ratingLocal,
      visitaName: rival.name,
      ratingVisita: rival.rating,
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
      visitaName: rival.name,
      ratingLocal: ratingLocal,
      ratingVisita: rival.rating,
      phase: MatchPhase.playing,
    );
  }

  // Al terminar reparte monedas (RF6) según el resultado del equipo local.
  void _finish(MatchResult result) {
    final coins = _reward(result.golLocal, result.golVisita);
    ref.read(coinsProvider.notifier).earn(coins);
    state = state.copyWith(phase: MatchPhase.finished, coinsAwarded: coins);
  }

  // Vuelve a jugar (nuevo rival y nueva simulación).
  void restart() {
    _sub?.cancel();
    state = _newMatch();
  }

  static int _reward(int golFavor, int golContra) {
    if (golFavor > golContra) return 500 + 50 * golFavor; // victoria
    if (golFavor == golContra) return 200; // empate
    return 75; // derrota (algo, para no frustrar)
  }
}
