import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contador_app/domain/entities/app_user.dart';
import 'package:contador_app/domain/repositories/auth_repository.dart';
import 'package:contador_app/data/repositories/auth_repository_supabase.dart';

// 1) Provider del repositorio: Supabase Auth (login/registro reales).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositorySupabase();
});

// 2) Estados posibles de la sesión.
enum AuthStatus { unknown, authenticated, unauthenticated }

// 3) El estado inmutable que observa la UI.
class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting; // true mientras se procesa el login
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage, // se limpia si no se pasa
    );
  }
}

// 4) El controlador: mantiene el AuthState y expone las acciones.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession(); // restaura la sesión al arrancar
    return const AuthState(); // estado inicial: unknown
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    final user = await _repo.currentUser();
    state = state.copyWith(
      status: user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: user,
    );
  }

  // Devuelve true si el login fue correcto.
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isSubmitting: true); // enciende el spinner
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  // Registro. Devuelve true si quedó logueado; si hace falta confirmar el
  // correo (o hay error), deja el mensaje en errorMessage y devuelve false.
  Future<bool> signUp(String email, String password, String clubName) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final user = await _repo.signUp(
          email: email, password: password, clubName: clubName);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
