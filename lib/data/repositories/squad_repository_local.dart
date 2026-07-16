import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/entities/squad.dart';
import 'package:contador_app/domain/repositories/squad_repository.dart';

// Implementación OFFLINE del contrato de plantilla: el estado guardado en el
// dispositivo manda; si no existe (primera ejecución), se usa la semilla JSON.
class SquadRepositoryLocal implements SquadRepository {
  static const _seedPath = 'assets/data/squad.json';
  static const _kSquad = 'club_squad';

  List<Player> _parseList(dynamic list) => (list as List<dynamic>)
      .map((json) => Player.fromJson(json as Map<String, dynamic>))
      .toList();

  Squad _parseSquad(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return Squad(
      starters: _parseList(data['starters']),
      bench: _parseList(data['bench']),
    );
  }

  @override
  Future<Squad> getSquad() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSquad);
    if (saved != null) {
      try {
        return _parseSquad(saved);
      } catch (_) {
        // Estado guardado corrupto: se vuelve a la semilla.
      }
    }
    return _parseSquad(await rootBundle.loadString(_seedPath));
  }

  @override
  Future<void> saveSquad(Squad squad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSquad,
      jsonEncode({
        'starters': squad.starters.map((p) => p.toJson()).toList(),
        'bench': squad.bench.map((p) => p.toJson()).toList(),
      }),
    );
  }
}
