import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ultime_team_manager/config/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga las claves desde .env (empaquetado como asset). Si falta o falla, la
  // app arranca igual y las funciones que dependen de red se degradan.
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('dotenv.load failed: $e');
  }
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint('Supabase.initialize failed: $e');
  }
  runApp(const ProviderScope(child: MyApp()));
}

// Ahora es ConsumerWidget para poder leer el routerProvider.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      routerConfig: router,
    );
  }
}
