import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Monedas del club (RF4): viven en profiles.monedas de Supabase. El estado local
// es la fuente durante la sesión y se persiste en segundo plano.
const int kStartingCoins = 5000;

final coinsProvider =
    NotifierProvider<CoinsController, int>(CoinsController.new);

class CoinsController extends Notifier<int> {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  int build() {
    _load();
    return kStartingCoins;
  }

  Future<void> _load() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _db
          .from('profiles')
          .select('monedas')
          .eq('id', uid)
          .maybeSingle();
      if (row != null && row['monedas'] != null) {
        state = row['monedas'] as int;
      }
    } catch (_) {
      // Sin conexión / perfil aún no listo: se queda con el valor por defecto.
    }
  }

  Future<void> _persist() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('profiles').update({'monedas': state}).eq('id', uid);
    } catch (_) {}
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
