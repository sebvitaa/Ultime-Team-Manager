// Flujo de VENTA del mercado. Va en su propio archivo porque los tests que
// escriben en SharedPreferences contaminan la carga de assets del test
// siguiente dentro del mismo archivo (limitación de flutter_test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:contador_app/presentation/providers/coins_provider.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';

import 'helpers/market_test_helper.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('vender suma monedas, saca de la banca y vuelve al mercado',
      (tester) async {
    final container = await pumpMarket(tester);

    // Cambia a modo Vender: aparece la banca propia (no los titulares).
    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();
    expect(find.text('Mateo Rojas'), findsNothing); // titular: no se vende

    // El suplente puede quedar bajo el pliegue de la lista: se hace scroll.
    await tester.scrollUntilVisible(
      find.text('Cristóbal Núñez'), // suplente semilla (arquero, 79)
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Cristóbal Núñez'));
    await tester.pumpAndSettle();
    expect(find.text('Vender jugador'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Vender'));
    await tester.pumpAndSettle();

    expect(container.read(coinsProvider), 5000 + 986);
    final bench = container.read(squadControllerProvider).bench;
    expect(bench.any((p) => p.id == 'b1'), isFalse);

    // El vendido vuelve a aparecer en el modo Comprar.
    await tester.tap(find.text('Comprar').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cristóbal Núñez'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cristóbal Núñez'), findsOneWidget);
  });
}
