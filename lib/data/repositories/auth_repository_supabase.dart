import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:ultime_team_manager/domain/entities/app_user.dart';
import 'package:ultime_team_manager/domain/repositories/auth_repository.dart';

/// Autenticación real con Supabase Auth. El perfil (`profiles`) se crea solo por
/// un trigger en la base al registrarse (usa el `nombre_equipo`/`apodo` que se
/// mandan como metadata).
class AuthRepositorySupabase implements AuthRepository {
  final GoTrueClient _auth;

  AuthRepositorySupabase({GoTrueClient? auth})
      : _auth = auth ?? Supabase.instance.client.auth;

  @override
  Future<AppUser?> currentUser() async {
    final u = _auth.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  // Construye el AppUser leyendo el nombre del equipo desde la metadata que se
  // guardó al registrarse (`nombre_equipo`).
  AppUser _toAppUser(User u) {
    final name = u.userMetadata?['nombre_equipo'];
    return AppUser(
      id: u.id,
      email: u.email ?? '',
      teamName: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(
          email: email.trim(), password: password);
      final u = res.user;
      if (u == null) throw const AuthException('No se pudo iniciar sesión');
      return _toAppUser(u);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? clubName,
  }) async {
    try {
      final trimmedClubName = clubName?.trim();
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'apodo': email.split('@').first,
          if (trimmedClubName != null && trimmedClubName.isNotEmpty)
            'nombre_equipo': trimmedClubName.length > 30
                ? trimmedClubName.substring(0, 30)
                : trimmedClubName,
        },
      );
      final u = res.user;
      if (u == null) throw const AuthException('No se pudo crear la cuenta');
      // Sin sesión = falta confirmar el correo (si está activada esa opción).
      if (res.session == null) {
        throw const AuthException(
            'Cuenta creada. Revisa tu correo para confirmarla antes de entrar.');
      }
      return _toAppUser(u);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  // Traduce errores de Supabase a mensajes claros.
  String _friendly(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Ese correo ya tiene una cuenta';
    }
    if (m.contains('password') && m.contains('6')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirma tu correo antes de entrar';
    }
    if (m.contains('socket') || m.contains('network') || m.contains('failed host')) {
      return 'Sin conexión';
    }
    return 'No se pudo completar. Intenta de nuevo.';
  }
}
