import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/entities/squad.dart';
import 'package:contador_app/domain/repositories/squad_repository.dart';

// Implementación OFFLINE del contrato de plantilla: lee la semilla JSON local.
class SquadRepositoryLocal implements SquadRepository {
  static const _seedPath = 'assets/data/squad.json';

  Player _fromJson(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        name: map['name'] as String,
        rating: map['rating'] as int,
        position: PlayerPosition.values.byName(map['position'] as String),
      );

  @override
  Future<Squad> getSquad() async {
    final raw = await rootBundle.loadString(_seedPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final starters = (data['starters'] as List<dynamic>)
        .map((json) => _fromJson(json as Map<String, dynamic>))
        .toList();
    final bench = (data['bench'] as List<dynamic>)
        .map((json) => _fromJson(json as Map<String, dynamic>))
        .toList();
    return Squad(starters: starters, bench: bench);
  }
}
