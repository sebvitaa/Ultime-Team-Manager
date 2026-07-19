import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/market_repository.dart';

/// Mercado leyendo de Supabase (tabla `jugadores`, poblada desde API-Football).
/// La tabla tiene lectura pública (RLS), así que funciona con la clave pública
/// sin necesidad de sesión.
class MarketRepositorySupabase implements MarketRepository {
  final SupabaseClient _db;

  MarketRepositorySupabase({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  @override
  Future<List<Player>> fetchListings() async {
    try {
      final rows = await _db
          .from('jugadores')
          .select('id, nombre, puntaje, posicion, precio, foto_url_api')
          .order('puntaje', ascending: false)
          .limit(400);
      return rows.map(_toPlayer).toList();
    } on PostgrestException catch (e) {
      throw MarketException(
          'Error de Supabase (${e.code ?? ''})', MarketErrorKind.network);
    } catch (_) {
      throw const MarketException(
          'No se pudo cargar el mercado', MarketErrorKind.network);
    }
  }

  @override
  Future<List<Player>> searchPlayers(String query) async {
    try {
      final rows = await _db
          .from('jugadores')
          .select('id, nombre, puntaje, posicion, precio, foto_url_api')
          .ilike('nombre', '%${query.trim()}%')
          .order('puntaje', ascending: false)
          .limit(60);
      return rows.map(_toPlayer).toList();
    } on PostgrestException catch (e) {
      throw MarketException(
          'Error de Supabase (${e.code ?? ''})', MarketErrorKind.network);
    } catch (_) {
      throw const MarketException(
          'No se pudo buscar', MarketErrorKind.network);
    }
  }

  Player _toPlayer(Map<String, dynamic> j) {
    return Player(
      id: j['id'] as String,
      name: j['nombre'] as String,
      rating: j['puntaje'] as int,
      position: PlayerPosition.values.byName(j['posicion'] as String),
      price: j['precio'] as int,
      photoUrl: j['foto_url_api'] as String?,
    );
  }
}
