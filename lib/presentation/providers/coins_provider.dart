import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Monedas del club (RF4): arrancan en 5000 y se persisten en el dispositivo.
const int kStartingCoins = 5000;

final coinsProvider =
    NotifierProvider<CoinsController, int>(CoinsController.new);

class CoinsController extends Notifier<int> {
  static const _kCoins = 'club_coins';

  @override
  int build() {
    _restore();
    return kStartingCoins;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_kCoins) ?? kStartingCoins;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoins, state);
  }

  // Devuelve false si no alcanzan las monedas (no se descuenta nada).
  bool spend(int amount) {
    if (amount > state) return false;
    state -= amount;
    _persist();
    return true;
  }

  void earn(int amount) {
    state += amount;
    _persist();
  }
}
