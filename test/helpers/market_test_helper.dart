// Utilidades compartidas por los tests del mercado: repositorio falso
// (sin red) y montaje de la pantalla con overrides de Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/domain/repositories/market_repository.dart';
import 'package:contador_app/presentation/providers/market_provider.dart';
import 'package:contador_app/presentation/screens/market/market_screen.dart';

const kCheapPlayer = Player(
  id: 'api_1',
  name: 'Jugador Barato',
  rating: 60,
  position: PlayerPosition.cb,
  price: 432,
);

const kExpensivePlayer = Player(
  id: 'api_2',
  name: 'Jugador Carisimo',
  rating: 99,
  position: PlayerPosition.st,
  price: 99999, // más que las 5000 monedas iniciales
);

class FakeMarketRepository implements MarketRepository {
  @override
  Future<List<Player>> fetchListings() async =>
      [kCheapPlayer, kExpensivePlayer];

  @override
  Future<List<Player>> searchPlayers(String query) async => [];
}

Future<ProviderContainer> pumpMarket(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      ],
      child: const MaterialApp(home: MarketScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MarketScreen)),
  );
}
