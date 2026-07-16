import 'package:contador_app/domain/entities/player.dart';

abstract class MarketRepository {
  // Listado del mercado (jugadores comprables).
  Future<List<Player>> fetchListings();

  // Búsqueda por nombre (la API exige mínimo 4 caracteres).
  Future<List<Player>> searchPlayers(String query);
}

enum MarketErrorKind { network, quota }

class MarketException implements Exception {
  final String message;
  final MarketErrorKind kind;
  const MarketException(this.message, this.kind);
  @override
  String toString() => 'MarketException: $message';
}
