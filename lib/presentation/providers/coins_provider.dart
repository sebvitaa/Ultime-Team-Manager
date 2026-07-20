import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Monedas del club (RF4): viven en profiles.monedas de Supabase. El estado local
// es la fuente durante la sesión y se persiste en segundo plano.
const int kStartingCoins = 5000;

final coinsProvider =
    NotifierProvider<CoinsController, int>(CoinsController.new);

class CoinsController extends Notifier<int> {
  SupabaseClient get _db => Supabase.instance.client;

  // Se pone en true en cuanto earn()/spend() muta el estado localmente, para
  // que un _load() en vuelo no pise la mutación con el valor viejo del server.
  bool _touched = false;

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
      final coins = (row?['monedas'] as num?)?.toInt();
      if (coins != null && !_touched) state = coins;
    } catch (e) {
      // Sin conexión / perfil aún no listo: se queda con el valor por defecto.
      debugPrint('coins _load failed: $e');
    }
  }

  Future<void> _persist() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('profiles').update({'monedas': state}).eq('id', uid);
    } catch (e) {
      debugPrint('coins _persist failed: $e');
    }
  }

  // Devuelve false si no alcanzan las monedas (no se descuenta nada).
  bool spend(int amount) {
    if (amount > state) return false;
    _touched = true;
    state -= amount;
    _persist();
    return true;
  }

  void earn(int amount) {
    _touched = true;
    state += amount;
    _persist();
  }
}
