import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/squad_repository.dart';

// Implementación OFFLINE del contrato de plantilla: lee la semilla JSON local.
class SquadRepositoryLocal implements SquadRepository {
  static const _seedPath = 'assets/data/squad.json';

  @override
  Future<List<Player>> getSquad() async {
    final raw = await rootBundle.loadString(_seedPath);
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((json) {
      final map = json as Map<String, dynamic>;
      return Player(
        id: map['id'] as String,
        name: map['name'] as String,
        rating: map['rating'] as int,
        position: PlayerPosition.values.byName(map['position'] as String),
      );
    }).toList();
  }
}
