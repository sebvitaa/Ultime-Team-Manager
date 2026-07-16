import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/squad_repository.dart';
import 'package:contador_app/data/repositories/squad_repository_local.dart';

// 1) Provider del repositorio. Para pasar a online, cambia SOLO esta línea
//    por SquadRepositorySupabase().
final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepositoryLocal();
});

// 2) El estado inmutable que observa la UI.
class SquadState {
  final List<Player> players;
  final bool isLoading;
  final String? errorMessage;

  const SquadState({
    this.players = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  // Media de valoración del 11 (0 si aún no hay jugadores cargados).
  double get averageRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (acc, p) => acc + p.rating);
    return sum / players.length;
  }

  SquadState copyWith({
    List<Player>? players,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SquadState(
      players: players ?? this.players,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // se limpia si no se pasa
    );
  }
}

// 3) El controlador: mantiene el SquadState y expone las acciones.
final squadControllerProvider =
    NotifierProvider<SquadController, SquadState>(SquadController.new);

class SquadController extends Notifier<SquadState> {
  @override
  SquadState build() {
    _loadSquad(); // carga la plantilla al arrancar
    return const SquadState(isLoading: true);
  }

  SquadRepository get _repo => ref.read(squadRepositoryProvider);

  Future<void> _loadSquad() async {
    try {
      final players = await _repo.getSquad();
      state = state.copyWith(players: players, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo cargar la plantilla',
      );
    }
  }
}
