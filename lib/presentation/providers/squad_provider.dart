import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/entities/squad.dart';
import 'package:contador_app/domain/repositories/squad_repository.dart';
import 'package:contador_app/data/repositories/squad_repository_local.dart';

// 1) Provider del repositorio. Para pasar a online, cambia SOLO esta línea
//    por SquadRepositorySupabase().
final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepositoryLocal();
});

// 2) El estado inmutable que observa la UI.
class SquadState {
  final List<Player> players; // 11 titular
  final List<Player> bench; // suplentes disponibles
  final bool isLoading;
  final String? errorMessage;

  const SquadState({
    this.players = const [],
    this.bench = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  // Media de valoración del 11 (0 si aún no hay jugadores cargados).
  double get averageRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (acc, p) => acc + p.rating);
    return sum / players.length;
  }

  // Suplentes disponibles para la misma LÍNEA que [player] (def/med/del/por):
  // los comprados en el mercado traen solo su línea, así cualquier defensa
  // puede cubrir cualquier puesto de la defensa, etc.
  List<Player> benchFor(Player player) =>
      bench.where((b) => b.position.group == player.position.group).toList();

  SquadState copyWith({
    List<Player>? players,
    List<Player>? bench,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SquadState(
      players: players ?? this.players,
      bench: bench ?? this.bench,
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
      final squad = await _repo.getSquad();
      state = state.copyWith(
        players: squad.starters,
        bench: squad.bench,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo cargar la plantilla',
      );
    }
  }

  // Manda a la banca al titular y sube al suplente elegido a su lugar.
  // El suplente hereda el puesto EXACTO del titular (ej: un central que
  // reemplaza al lateral izquierdo pasa a jugar de LI) para que el 4-3-3
  // siga completo en la cancha.
  void swapWithBench(Player starter, Player substitute) {
    final promoted = substitute.copyWith(position: starter.position);
    final players = [
      for (final p in state.players) p.id == starter.id ? promoted : p,
    ];
    final bench = [
      for (final b in state.bench) b.id == substitute.id ? starter : b,
    ];
    state = state.copyWith(players: players, bench: bench);
    _persist();
  }

  // Agrega un jugador comprado en el mercado a la banca.
  void addToBench(Player player) {
    if (state.bench.any((b) => b.id == player.id) ||
        state.players.any((p) => p.id == player.id)) {
      return; // ya es parte del club
    }
    state = state.copyWith(bench: [...state.bench, player]);
    _persist();
  }

  // Quita de la banca un jugador vendido en el mercado.
  void removeFromBench(Player player) {
    state = state.copyWith(
      bench: state.bench.where((b) => b.id != player.id).toList(),
    );
    _persist();
  }

  void _persist() =>
      _repo.saveSquad(Squad(starters: state.players, bench: state.bench));
}
