import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ultime_team_manager/domain/entities/player.dart';
import 'package:ultime_team_manager/domain/entities/squad.dart';
import 'package:ultime_team_manager/domain/repositories/squad_repository.dart';

/// Plantilla del club persistida en Supabase (`user_jugadores`).
///
/// El puesto en la cancha se codifica en `slot`: los slots 0..10 son el 11
/// titular y su orden define la formación 4-3-3 (el slot manda sobre la
/// posición del catálogo, así un central que cubre de lateral se dibuja de
/// lateral). Los slots >= 100 son la banca y usan la posición del catálogo.
class SquadRepositorySupabase implements SquadRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // Orden fijo del 4-3-3: slot -> puesto jugado.
  static const List<PlayerPosition> _formation = [
    PlayerPosition.gk,
    PlayerPosition.lb,
    PlayerPosition.cb,
    PlayerPosition.cb,
    PlayerPosition.rb,
    PlayerPosition.cm,
    PlayerPosition.cm,
    PlayerPosition.cm,
    PlayerPosition.lw,
    PlayerPosition.st,
    PlayerPosition.rw,
  ];
  static const int _benchBase = 100; // slots >= 100 => banca

  static const String _cols = 'id,nombre,puntaje,posicion,precio,foto_url_api';

  @override
  Future<Squad> getSquad() async {
    final uid = _uid;
    if (uid == null) return const Squad(starters: [], bench: []);

    final rows = await _db
        .from('user_jugadores')
        .select('slot, jugadores($_cols)')
        .eq('user_id', uid)
        .order('slot') as List<dynamic>;

    // Primera vez: el usuario no tiene plantilla -> se le arma un 11 inicial.
    if (rows.isEmpty) return _seedSquad(uid);

    final starters = <Player>[];
    final bench = <Player>[];
    for (final row in rows) {
      final r = row as Map<String, dynamic>;
      final j = r['jugadores'] as Map<String, dynamic>?;
      if (j == null) continue; // jugador borrado del catálogo
      final slot = (r['slot'] as num?)?.toInt();
      if (slot == null) continue; // fila con slot corrupto/nulo
      if (slot < _benchBase) {
        final pos = _formation[slot.clamp(0, _formation.length - 1)];
        final player = _tryToPlayer(j, override: pos);
        if (player != null) starters.add(player);
      } else {
        final player = _tryToPlayer(j);
        if (player != null) bench.add(player);
      }
    }
    return Squad(starters: starters, bench: bench);
  }

  @override
  Future<void> saveSquad(Squad squad) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Upsert de la plantilla nueva y luego borrado de lo que quedó obsoleto,
      // así nunca queda la tabla vacía si la conexión se cae a mitad de camino.
      final rows = <Map<String, dynamic>>[
        for (var i = 0; i < squad.starters.length; i++)
          {'user_id': uid, 'jugador_id': squad.starters[i].id, 'slot': i},
        for (var i = 0; i < squad.bench.length; i++)
          {
            'user_id': uid,
            'jugador_id': squad.bench[i].id,
            'slot': _benchBase + i,
          },
      ];
      if (rows.isNotEmpty) {
        await _db
            .from('user_jugadores')
            .upsert(rows, onConflict: 'user_id,jugador_id');
        final ids = rows.map((r) => r['jugador_id'] as String).join(',');
        await _db
            .from('user_jugadores')
            .delete()
            .eq('user_id', uid)
            .not('jugador_id', 'in', '($ids)');
      } else {
        await _db.from('user_jugadores').delete().eq('user_id', uid);
      }
    } catch (e) {
      // Best-effort: sin conexión no se rompe la UI (se reintenta al guardar).
      debugPrint('saveSquad failed: $e');
    }
  }

  // Arma un 11 inicial eligiendo por LÍNEA (el catálogo real solo trae
  // gk/cb/cm/st), y le asigna a cada titular el puesto exacto de la formación.
  Future<Squad> _seedSquad(String uid) async {
    final catalog = await _db
        .from('jugadores')
        .select(_cols)
        .order('puntaje', ascending: false)
        .limit(300) as List<dynamic>;
    if (catalog.isEmpty) return const Squad(starters: [], bench: []);

    final byGroup = <PlayerPositionGroup, List<Map<String, dynamic>>>{};
    for (final j in catalog) {
      final m = j as Map<String, dynamic>;
      final pos = PlayerPosition.values.asNameMap()[m['posicion']];
      if (pos == null) continue; // fila de catálogo con posición corrupta
      byGroup.putIfAbsent(pos.group, () => []).add(m);
    }

    final used = <String>{};
    Map<String, dynamic>? pick(PlayerPositionGroup g) {
      for (final j in byGroup[g] ?? const []) {
        if (used.add(j['id'] as String)) return j;
      }
      return null;
    }

    final starters = <Player>[];
    for (final pos in _formation) {
      final j = pick(pos.group);
      if (j == null) continue;
      final player = _tryToPlayer(j, override: pos);
      if (player != null) starters.add(player);
    }

    // Banca: un relevo por línea.
    final bench = <Player>[];
    for (final g in PlayerPositionGroup.values) {
      final j = pick(g);
      if (j == null) continue;
      final player = _tryToPlayer(j);
      if (player != null) bench.add(player);
    }

    final squad = Squad(starters: starters, bench: bench);
    await saveSquad(squad);
    return squad;
  }

  // Parseo defensivo: una fila corrupta del catálogo (posición desconocida,
  // puntaje/id/nombre nulos, etc.) no debe tumbar toda la carga de la
  // plantilla — se descarta esa fila y se sigue con el resto.
  Player? _tryToPlayer(Map<String, dynamic> j, {PlayerPosition? override}) {
    try {
      final rating = (j['puntaje'] as num?)?.toInt();
      final id = j['id'] as String?;
      final name = j['nombre'] as String?;
      if (rating == null || id == null || name == null) return null;
      final position = override ??
          PlayerPosition.values.asNameMap()[j['posicion']] ??
          PlayerPosition.cm;
      return Player(
        id: id,
        name: name,
        rating: rating,
        position: position,
        price: (j['precio'] as num?)?.toInt() ?? Player.priceForRating(rating),
        photoUrl: j['foto_url_api'] as String?,
      );
    } catch (e) {
      debugPrint('_tryToPlayer failed: $e');
      return null;
    }
  }
}
