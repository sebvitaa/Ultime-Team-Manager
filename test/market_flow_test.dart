// Flujo de COMPRA del mercado con un repositorio falso (sin red).
// La venta vive en market_sell_flow_test.dart: los tests que escriben en
// SharedPreferences contaminan la carga de assets del test siguiente dentro
// del mismo archivo (limitación de flutter_test), así que van separados.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ultimate_team_manager/domain/entities/player.dart';
import 'package:ultimate_team_manager/presentation/providers/coins_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/market_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/squad_provider.dart';

import 'helpers/market_test_helper.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no se puede comprar sin monedas suficientes', (tester) async {
    final container = await pumpMarket(tester);

    await tester.tap(find.text('Jugador Carisimo'));
    await tester.pumpAndSettle();

    expect(find.text('Monedas insuficientes.'), findsOneWidget);
    final buyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Comprar'),
    );
    expect(buyButton.onPressed, isNull); // botón deshabilitado

    // No cambió nada.
    expect(container.read(coinsProvider), 5000);
  });

  testWidgets('comprar descuenta monedas y suma el jugador a la banca',
      (tester) async {
    final container = await pumpMarket(tester);

    expect(find.text('Jugador Barato'), findsOneWidget);
    expect(container.read(coinsProvider), 5000);

    await tester.tap(find.text('Jugador Barato'));
    await tester.pumpAndSettle();
    expect(find.text('Comprar jugador'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Comprar'));
    await tester.pumpAndSettle();

    expect(container.read(coinsProvider), 5000 - 432);
    final bench = container.read(squadControllerProvider).bench;
    expect(bench.any((p) => p.id == 'api_1'), isTrue);
    // Ya es del club: desaparece del listado de compra.
    expect(find.text('Jugador Barato'), findsNothing);
  });

  test('visiblePlayers filtra, ordena y excluye a los que ya son del club',
      () {
    const owned = Player(
      id: 'api_9',
      name: 'Ya Comprado',
      rating: 80,
      position: PlayerPosition.cm,
      price: 1024,
    );
    const squad = SquadState(players: [owned], bench: []);
    const base =
        MarketState(listings: [kCheapPlayer, kExpensivePlayer, owned]);

    // Excluye a los del club.
    expect(
      base.visiblePlayers(squad).map((p) => p.id),
      isNot(contains('api_9')),
    );

    // Filtro por posición (defensa → solo el central).
    final defense = base
        .copyWith(positionFilter: PlayerPositionGroup.defense)
        .visiblePlayers(squad);
    expect(defense.map((p) => p.id), ['api_1']);

    // Búsqueda por texto (filtro local).
    final byName = base.copyWith(query: 'barato').visiblePlayers(squad);
    expect(byName.map((p) => p.id), ['api_1']);

    // Órdenes.
    List<String> idsFor(MarketSort sort) => base
        .copyWith(sort: sort)
        .visiblePlayers(squad)
        .map((p) => p.id)
        .toList();

    expect(idsFor(MarketSort.ratingDesc).first, 'api_2');
    expect(idsFor(MarketSort.ratingAsc).first, 'api_1');
    expect(idsFor(MarketSort.priceDesc).first, 'api_2');
    expect(idsFor(MarketSort.priceAsc).first, 'api_1');
    expect(idsFor(MarketSort.alphabetical).first, 'api_1'); // B antes que C
  });
}
