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
  Future<List<Player>> searchPlayers(String query) => _cached(
        'market_cache_search_${query.trim().toLowerCase()}',
        () => _api.searchPlayers(query),
      );

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
