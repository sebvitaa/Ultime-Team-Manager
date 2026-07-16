import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/market_repository.dart';

/// Cliente de API-Football v3 (api-sports.io). Plan gratuito: 100 peticiones
/// al día y temporadas 2021-2023, por eso el repositorio cachea las
/// respuestas y este cliente se usa lo menos posible.
class ApiFootballDatasource {
  static const _baseUrl = 'https://v3.football.api-sports.io';
  static const league = 140; // La Liga
  static const season = 2023; // última temporada del plan gratuito

  // Planteles que pueblan el mercado: en las páginas "generales" de la liga
  // casi todos vienen sin valoración (sin minutos jugados), en cambio los
  // planteles de los equipos grandes traen notas reales.
  static const marketTeams = [541, 529, 530]; // Real Madrid, Barça, Atleti

  final http.Client _client;

  ApiFootballDatasource({http.Client? client})
      : _client = client ?? http.Client();

  String get _apiKey => dotenv.env['API_KEY'] ?? '';

  Future<List<Player>> fetchTeamPlayers(int teamId) =>
      _getPlayers({'team': '$teamId', 'season': '$season'});

  Future<List<Player>> searchPlayers(String query) => _getPlayers(
      {'league': '$league', 'season': '$season', 'search': query});

  Future<List<Player>> _getPlayers(Map<String, String> params) async {
    late final http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_baseUrl/players').replace(queryParameters: params),
        headers: {'x-apisports-key': _apiKey},
      ).timeout(const Duration(seconds: 12));
    } on SocketException {
      throw const MarketException('Sin conexión', MarketErrorKind.network);
    } catch (_) {
      throw const MarketException(
          'No se pudo contactar la API', MarketErrorKind.network);
    }

    if (res.statusCode == 429) {
      throw const MarketException(
          'Límite diario de la API alcanzado', MarketErrorKind.quota);
    }
    if (res.statusCode != 200) {
      throw MarketException(
          'Error de la API (${res.statusCode})', MarketErrorKind.network);
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    // La API reporta cuota excedida u otros problemas en `errors`
    // aunque el status HTTP sea 200.
    final errors = body['errors'];
    final hasErrors = (errors is Map && errors.isNotEmpty) ||
        (errors is List && errors.isNotEmpty);
    if (hasErrors) {
      final text = errors.toString().toLowerCase();
      final isQuota = text.contains('request') || text.contains('limit');
      throw MarketException(
        isQuota ? 'Límite diario de la API alcanzado' : 'Error de la API',
        isQuota ? MarketErrorKind.quota : MarketErrorKind.network,
      );
    }

    final items = (body['response'] as List<dynamic>? ?? []);
    return items
        .map((item) => mapApiPlayer(item as Map<String, dynamic>))
        .whereType<Player>()
        .toList();
  }

  /// Convierte un ítem de la API en un [Player], o null si no sirve
  /// (sin valoración = jugador sin minutos, no se lista en el mercado).
  static Player? mapApiPlayer(Map<String, dynamic> item) {
    final player = item['player'] as Map<String, dynamic>?;
    final stats = (item['statistics'] as List<dynamic>?)?.firstOrNull
        as Map<String, dynamic>?;
    if (player == null || stats == null) return null;

    final games = stats['games'] as Map<String, dynamic>?;
    final rawRating = games?['rating'];
    if (rawRating == null) return null;

    // La valoración llega ~4-10 (nota de partido): se lleva a escala 1-100.
    final apiRating = double.tryParse(rawRating.toString());
    if (apiRating == null) return null;
    final rating = (apiRating * 10).round().clamp(1, 100);

    return Player(
      id: 'api_${player['id']}',
      name: player['name'] as String? ?? 'Desconocido',
      rating: rating,
      position: _positionFor(games?['position'] as String?),
      price: Player.priceForRating(rating),
      photoUrl: player['photo'] as String?,
    );
  }

  // La API solo da la línea (Goalkeeper/Defender/...): se asigna la posición
  // central de cada línea; al entrar al 11 el jugador adopta el puesto
  // exacto del titular que reemplaza.
  static PlayerPosition _positionFor(String? apiPosition) =>
      switch (apiPosition) {
        'Goalkeeper' => PlayerPosition.gk,
        'Defender' => PlayerPosition.cb,
        'Midfielder' => PlayerPosition.cm,
        _ => PlayerPosition.st,
      };
}
