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
      final slot = (r['slot'] as num).toInt();
      if (slot < _benchBase) {
        final pos = _formation[slot.clamp(0, _formation.length - 1)];
        starters.add(_toPlayer(j, override: pos));
      } else {
        bench.add(_toPlayer(j));
      }
    }
    return Squad(starters: starters, bench: bench);
  }

  @override
  Future<void> saveSquad(Squad squad) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Se reescribe la plantilla completa (simple y consistente a esta escala).
      await _db.from('user_jugadores').delete().eq('user_id', uid);
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
      if (rows.isNotEmpty) await _db.from('user_jugadores').insert(rows);
    } catch (_) {
      // Best-effort: sin conexión no se rompe la UI (se reintenta al guardar).
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
      final g = PlayerPosition.values.byName(m['posicion'] as String).group;
      byGroup.putIfAbsent(g, () => []).add(m);
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
      if (j != null) starters.add(_toPlayer(j, override: pos));
    }

    // Banca: un relevo por línea.
    final bench = <Player>[];
    for (final g in PlayerPositionGroup.values) {
      final j = pick(g);
      if (j != null) bench.add(_toPlayer(j));
    }

    final squad = Squad(starters: starters, bench: bench);
    await saveSquad(squad);
    return squad;
  }

  Player _toPlayer(Map<String, dynamic> j, {PlayerPosition? override}) {
    final rating = (j['puntaje'] as num).toInt();
    return Player(
      id: j['id'] as String,
      name: j['nombre'] as String,
      rating: rating,
      position:
          override ?? PlayerPosition.values.byName(j['posicion'] as String),
      price: (j['precio'] as num?)?.toInt() ?? Player.priceForRating(rating),
      photoUrl: j['foto_url_api'] as String?,
    );
  }
}
