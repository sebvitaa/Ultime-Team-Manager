// Inicializa una instancia de Supabase apta para tests: sin red y sin sesión.
// Con `currentUser == null`, los proveedores que tocan Supabase (coins, squad,
// auth) degradan de forma segura (retornos tempranos por uid nulo) en vez de
// lanzar "You must initialize the supabase instance".
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _initialized = false;

/// Idempotente: se puede llamar en cada `setUpAll` sin re-inicializar.
Future<void> initTestSupabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_initialized) return;
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'http://localhost:54321',
    publishableKey: 'test-publishable-key',
  );
  _initialized = true;
}
