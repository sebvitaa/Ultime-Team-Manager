// Pruebas puras del mapeo API → entidad y del modelo Player.
// No tocan la red: usan un Map con la forma real de la respuesta de
// API-Football v3 (/players).

import 'package:flutter_test/flutter_test.dart';

import 'package:contador_app/data/datasources/api_football_datasource.dart';
import 'package:contador_app/domain/entities/player.dart';

Map<String, dynamic> apiItem({
  int id = 83,
  String name = 'A. Danjuma',
  String? position = 'Attacker',
  Object? rating = '7.386486',
}) {
  return {
    'player': {
      'id': id,
      'name': name,
      'firstname': 'Arnaut',
      'lastname': 'Danjuma Adam Groeneveld',
      'photo': 'https://media.api-sports.io/football/players/$id.png',
    },
    'statistics': [
      {
        'games': {'position': position, 'rating': rating},
      },
    ],
  };
}

void main() {
  group('Player.priceForRating', () {
    test('curva convexa esperada', () {
      expect(Player.priceForRating(70), 686);
      expect(Player.priceForRating(80), 1024);
      expect(Player.priceForRating(85), 1228);
      expect(Player.priceForRating(91), 1507);
    });
  });

  group('ApiFootballDatasource.mapApiPlayer', () {
    test('mapea un jugador válido', () {
      final player = ApiFootballDatasource.mapApiPlayer(apiItem());

      expect(player, isNotNull);
      expect(player!.id, 'api_83');
      expect(player.name, 'A. Danjuma');
      expect(player.rating, 74); // 7.386486 * 10 redondeado
      expect(player.position, PlayerPosition.st);
      expect(player.price, Player.priceForRating(74));
      expect(player.photoUrl, contains('/players/83.png'));
    });

    test('excluye jugadores sin valoración', () {
      expect(ApiFootballDatasource.mapApiPlayer(apiItem(rating: null)), isNull);
    });

    test('acota la valoración a 1-100', () {
      final player = ApiFootballDatasource.mapApiPlayer(
        apiItem(rating: '11.5'), // imposible en la práctica, por si acaso
      );
      expect(player!.rating, 100);
    });

    test('mapea cada línea a su posición por defecto', () {
      PlayerPosition posFor(String apiPos) =>
          ApiFootballDatasource.mapApiPlayer(apiItem(position: apiPos))!
              .position;

      expect(posFor('Goalkeeper'), PlayerPosition.gk);
      expect(posFor('Defender'), PlayerPosition.cb);
      expect(posFor('Midfielder'), PlayerPosition.cm);
      expect(posFor('Attacker'), PlayerPosition.st);
    });
  });

  group('Player toJson/fromJson', () {
    test('ida y vuelta sin pérdidas', () {
      const original = Player(
        id: 'api_83',
        name: 'A. Danjuma',
        rating: 74,
        position: PlayerPosition.st,
        price: 810,
        photoUrl: 'https://media.api-sports.io/football/players/83.png',
      );

      final copy = Player.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.rating, original.rating);
      expect(copy.position, original.position);
      expect(copy.price, original.price);
      expect(copy.photoUrl, original.photoUrl);
    });

    test('semilla sin precio: se deriva de la valoración', () {
      final player = Player.fromJson({
        'id': 'p1',
        'name': 'Mateo Rojas',
        'rating': 84,
        'position': 'gk',
      });
      expect(player.price, Player.priceForRating(84));
      expect(player.photoUrl, isNull);
    });
  });
}
