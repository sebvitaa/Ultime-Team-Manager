import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contador_app/data/repositories/market_repository_supabase.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/market_repository.dart';
import 'package:contador_app/presentation/providers/coins_provider.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';

// 1) Provider del repositorio. Para cambiar de fuente (otra API, Supabase),
//    cambia SOLO esta línea.
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepositorySupabase();
});

// 2) Modos y criterios de orden del mercado.
enum MarketMode { buy, sell }

enum MarketSort { ratingDesc, ratingAsc, priceDesc, priceAsc, alphabetical }

extension MarketSortX on MarketSort {
  String get displayLabel => switch (this) {
        MarketSort.ratingDesc => 'Puntaje ↓',
        MarketSort.ratingAsc => 'Puntaje ↑',
        MarketSort.priceDesc => 'Precio ↓',
        MarketSort.priceAsc => 'Precio ↑',
        MarketSort.alphabetical => 'A-Z',
      };
}

// 3) El estado inmutable que observa la UI.
class MarketState {
  final MarketMode mode;
  final String query;
  final PlayerPositionGroup? positionFilter; // null = todas
  final MarketSort sort;
  final List<Player> listings; // traídos de la API
  final List<Player> soldPlayers; // vendidos por el usuario, vuelven al mercado
  final bool isLoading;
  final String? errorMessage;

  const MarketState({
    this.mode = MarketMode.buy,
    this.query = '',
    this.positionFilter,
    this.sort = MarketSort.ratingDesc,
    this.listings = const [],
    this.soldPlayers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  // Jugadores visibles según modo, búsqueda, filtro y orden.
  // En Comprar: mercado (API + vendidos) sin los que ya son del club.
  // En Vender: la banca propia (los titulares no se pueden vender).
  List<Player> visiblePlayers(SquadState squad) {
    final ownedIds = {
      for (final p in squad.players) p.id,
      for (final b in squad.bench) b.id,
    };

    var players = mode == MarketMode.buy
        ? [
            ...listings.where((p) => !ownedIds.contains(p.id)),
            ...soldPlayers.where((p) => !ownedIds.contains(p.id)),
          ]
        : List<Player>.from(squad.bench);

    if (positionFilter != null) {
      players =
          players.where((p) => p.position.group == positionFilter).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      players =
          players.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    players.sort(switch (sort) {
      MarketSort.ratingDesc => (a, b) => b.rating.compareTo(a.rating),
      MarketSort.ratingAsc => (a, b) => a.rating.compareTo(b.rating),
      MarketSort.priceDesc => (a, b) => b.price.compareTo(a.price),
      MarketSort.priceAsc => (a, b) => a.price.compareTo(b.price),
      MarketSort.alphabetical => (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    });
    return players;
  }

  MarketState copyWith({
    MarketMode? mode,
    String? query,
    PlayerPositionGroup? positionFilter,
    bool clearPositionFilter = false,
    MarketSort? sort,
    List<Player>? listings,
    List<Player>? soldPlayers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MarketState(
      mode: mode ?? this.mode,
      query: query ?? this.query,
      positionFilter: clearPositionFilter
          ? null
          : (positionFilter ?? this.positionFilter),
      sort: sort ?? this.sort,
      listings: listings ?? this.listings,
      soldPlayers: soldPlayers ?? this.soldPlayers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // se limpia si no se pasa
    );
  }
}

// 4) El controlador: mantiene el MarketState y expone las acciones.
final marketControllerProvider =
    NotifierProvider<MarketController, MarketState>(MarketController.new);

class MarketController extends Notifier<MarketState> {
  static const _kSold = 'market_sold';
  static const _searchMinChars = 4; // exigencia de la API
  Timer? _debounce;

  @override
  MarketState build() {
    ref.onDispose(() => _debounce?.cancel());
    _init();
    return const MarketState(isLoading: true);
  }

  MarketRepository get _repo => ref.read(marketRepositoryProvider);

  Future<void> _init() async {
    await _restoreSold();
    await loadListings();
  }

  // Carga el listado del mercado (≤3 peticiones; 0 si hay caché vigente).
  Future<void> loadListings() async {
    state = state.copyWith(isLoading: true);
    try {
      final listings = await _repo.fetchListings();
      state = state.copyWith(listings: listings, isLoading: false);
    } on MarketException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // Búsqueda con debounce: bajo 4 letras solo se filtra lo ya cargado
  // (la API exige mínimo 4); desde 4 letras se consulta en línea.
  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < _searchMinChars) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      state = state.copyWith(isLoading: true);
      try {
        final results = await _repo.searchPlayers(q);
        // Se suman al listado (sin duplicar) para que el filtro local los vea.
        final known = {for (final p in state.listings) p.id};
        state = state.copyWith(
          listings: [
            ...state.listings,
            ...results.where((p) => !known.contains(p.id)),
          ],
          isLoading: false,
        );
      } on MarketException catch (e) {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    });
  }

  void setMode(MarketMode mode) => state = state.copyWith(mode: mode);

  void setPositionFilter(PlayerPositionGroup? group) => state = group == null
      ? state.copyWith(clearPositionFilter: true)
      : state.copyWith(positionFilter: group);

  void setSort(MarketSort sort) => state = state.copyWith(sort: sort);

  // Compra: descuenta monedas y suma el jugador a la banca del club.
  // Devuelve false si no alcanzan las monedas.
  bool buy(Player player) {
    final ok = ref.read(coinsProvider.notifier).spend(player.price);
    if (!ok) return false;
    ref.read(squadControllerProvider.notifier).addToBench(player);
    // Si era un jugador vendido antes, deja de estar "en venta".
    state = state.copyWith(
      soldPlayers:
          state.soldPlayers.where((p) => p.id != player.id).toList(),
    );
    _persistSold();
    return true;
  }

  // Venta: saca al jugador de la banca, suma monedas y lo devuelve al mercado.
  void sell(Player player) {
    ref.read(squadControllerProvider.notifier).removeFromBench(player);
    ref.read(coinsProvider.notifier).earn(player.price);
    state = state.copyWith(soldPlayers: [...state.soldPlayers, player]);
    _persistSold();
  }

  Future<void> _restoreSold() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSold);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((j) => Player.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(soldPlayers: list);
    } catch (_) {
      // Estado corrupto: se ignora.
    }
  }

  Future<void> _persistSold() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSold,
      jsonEncode(state.soldPlayers.map((p) => p.toJson()).toList()),
    );
  }
}
