import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultime_team_manager/data/datasources/api_football_datasource.dart';
import 'package:ultime_team_manager/domain/entities/player.dart';
import 'package:ultime_team_manager/domain/repositories/market_repository.dart';

/// Implementación del mercado contra API-Football, con caché local para
/// respetar el límite de 100 peticiones/día: cada respuesta se guarda en
/// SharedPreferences y se reutiliza durante [_ttl]; si la red o la cuota
/// fallan, se sirve la copia vencida antes que nada.
class MarketRepositoryApi implements MarketRepository {
  static const _ttl = Duration(hours: 24);

  // Tope de entradas de caché de búsqueda que se conservan; al superarlo se
  // desaloja la más antigua (por orden de uso) para no crecer sin límite.
  static const _maxSearchCacheEntries = 20;
  static const _searchIndexKey = 'market_cache_search_index';

  final ApiFootballDatasource _api;

  MarketRepositoryApi({ApiFootballDatasource? api})
      : _api = api ?? ApiFootballDatasource();

  // Junta los planteles de los equipos del mercado; si alguno falla pero
  // otro respondió, se muestra lo que haya en vez de fallar todo.
  @override
  Future<List<Player>> fetchListings() async {
    MarketException? firstError;
    // En paralelo: 16 equipos en serie serían lentos. Cada uno pasa por su
    // caché, así que en la práctica son 0 peticiones si el caché está vigente.
    final lists = await Future.wait(
      ApiFootballDatasource.marketTeams.map((teamId) async {
        try {
          return await _cached(
            'market_cache_t${teamId}_s${ApiFootballDatasource.season}',
            () => _api.fetchTeamPlayers(teamId),
          );
        } on MarketException catch (e) {
          firstError ??= e;
          return <Player>[];
        }
      }),
    );
    // Se juntan sin duplicar por id (un jugador puede figurar en dos planteles).
    final seen = <String>{};
    final players = <Player>[];
    for (final list in lists) {
      for (final p in list) {
        if (seen.add(p.id)) players.add(p);
      }
    }
    final err = firstError;
    if (players.isEmpty && err != null) throw err;
    return players;
  }

  @override
  Future<List<Player>> searchPlayers(String query) async {
    final key = 'market_cache_search_${query.trim().toLowerCase()}';
    final players = await _cached(key, () => _api.searchPlayers(query));
    await _touchSearchIndex(key);
    return players;
  }

  // Registra `key` como usada recién ahora y, si el índice supera el tope,
  // desaloja las entradas más antiguas (índice + su caché) para acotar el
  // crecimiento de SharedPreferences.
  Future<void> _touchSearchIndex(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _readSearchIndex(prefs);
    index.remove(key);
    index.add(key);
    while (index.length > _maxSearchCacheEntries) {
      final oldest = index.removeAt(0);
      await prefs.remove(oldest);
    }
    await prefs.setString(_searchIndexKey, jsonEncode(index));
  }

  List<String> _readSearchIndex(SharedPreferences prefs) {
    final raw = prefs.getString(_searchIndexKey);
    if (raw == null) return <String>[];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<Player>> _cached(
    String key,
    Future<List<Player>> Function() fetch,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = _readEntry(prefs, key);

    // Caché vigente: ni siquiera tocamos la red.
    if (entry != null && !entry.isExpired) return entry.players;

    try {
      final players = await fetch();
      await prefs.setString(
        key,
        jsonEncode({
          'ts': DateTime.now().millisecondsSinceEpoch,
          'players': players.map((p) => p.toJson()).toList(),
        }),
      );
      return players;
    } on MarketException {
      // Falla la red o la cuota: mejor datos viejos que ninguno.
      if (entry != null) return entry.players;
      rethrow;
    }
  }

  _CacheEntry? _readEntry(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _CacheEntry(
        DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
        (map['players'] as List<dynamic>)
            .map((j) => Player.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null; // caché corrupta: se ignora y se vuelve a pedir
    }
  }
}

class _CacheEntry {
  final DateTime ts;
  final List<Player> players;
  _CacheEntry(this.ts, this.players);

  bool get isExpired =>
      DateTime.now().difference(ts) > MarketRepositoryApi._ttl;
}
