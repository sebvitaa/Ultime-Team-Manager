import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultimate_team_manager/domain/entities/app_user.dart';
import 'package:ultimate_team_manager/domain/repositories/auth_repository.dart';

// Implementación OFFLINE del contrato de autenticación.
class AuthRepositoryLocal implements AuthRepository {
  // Claves con las que guardamos la sesión en el dispositivo.
  static const _kUserId = 'auth_user_id';
  static const _kUserEmail = 'auth_user_email';

  // Usuario de demo para el modo offline. Cámbialo si quieres.
  static const _demoEmail = 'demo@ultime.com';
  static const _demoPassword = '123456';

  @override
  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kUserId);
    final email = prefs.getString(_kUserEmail);
    if (id == null || email == null) return null;
    return AppUser(id: id, email: email);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    // Simula la latencia de una petición de red real.
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = email.trim().toLowerCase();
    if (normalized != _demoEmail || password != _demoPassword) {
      throw const AuthException('Correo o contraseña incorrectos');
    }

    final user = AppUser(id: 'u1', email: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, user.id);
    await prefs.setString(_kUserEmail, user.email);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? clubName,
  }) async {
    throw const AuthException('El registro requiere conexión (Supabase)');
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserEmail);
  }
}
