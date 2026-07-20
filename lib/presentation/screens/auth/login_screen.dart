import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultime_team_manager/config/theme/app_colors.dart';
import 'package:ultime_team_manager/presentation/providers/auth_provider.dart';
import 'package:ultime_team_manager/presentation/widgets/crest_logo.dart';
import 'package:ultime_team_manager/presentation/widgets/intro_music.dart';
import 'package:ultime_team_manager/presentation/widgets/pitch_background.dart';

/// Pantalla de intro / login: tarjeta estilo EA FC sobre la cancha animada.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _clubCtrl = TextEditingController();
  bool _obscure = true;
  bool _isRegister = false; // false = iniciar sesión, true = registrarse

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _clubCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Introduce tu correo';
    final regex = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w.\-]+$');
    if (!regex.hasMatch(text)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Introduce tu contraseña';
    if (text.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authControllerProvider.notifier);
    final ok = _isRegister
        ? await notifier.signUp(
            _emailCtrl.text, _passCtrl.text, _clubCtrl.text)
        : await notifier.signIn(_emailCtrl.text, _passCtrl.text);

    if (!ok && mounted) {
      final msg = ref.read(authControllerProvider).errorMessage ?? 'Error';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
    // Si ok == true, el router (guardia de sesión) redirige a /home.
  }

  // Decoración común de los campos, estilo EA (input oscuro, borde redondeado).
  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder borde(Color color, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: w),
        );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.gris),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.035),
      labelStyle: const TextStyle(color: AppColors.gris, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: AppColors.verde),
      enabledBorder: borde(AppColors.borde),
      focusedBorder: borde(AppColors.verde, 1.6),
      errorBorder: borde(const Color(0xFFE0574E)),
      focusedErrorBorder: borde(const Color(0xFFE0574E), 1.6),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting =
        ref.watch(authControllerProvider.select((s) => s.isSubmitting));

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: PitchBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _card(isSubmitting),
                ),
              ),
            ),
          ),
          const IntroMusic(), // música de intro (loop) + botón de silencio
        ],
      ),
    );
  }

  Widget _card(bool isSubmitting) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 44,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrestLogo(size: 66),
            const SizedBox(height: 14),
            const Text(
              'Ultime Team\nManager',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 23,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRegister
                  ? 'Crea tu cuenta y funda tu club'
                  : 'Inicia sesión para gestionar tu club',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gris, fontSize: 12.5),
            ),
            const SizedBox(height: 24),
            if (_isRegister) ...[
              TextFormField(
                controller: _clubCtrl,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.texto),
                decoration: _dec('Nombre del club', Icons.shield_outlined),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ponle nombre a tu club'
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailCtrl,
              enabled: !isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.texto),
              decoration: _dec('Correo electrónico', Icons.mail_outline),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              enabled: !isSubmitting,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(color: AppColors.texto),
              decoration: _dec(
                'Contraseña',
                Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.gris,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pildora,
                  foregroundColor: const Color(0xFF05210F),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF05210F),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isRegister ? 'Crear cuenta' : 'Entrar'),
                          const SizedBox(width: 8),
                          Icon(
                            _isRegister
                                ? Icons.person_add_alt_1
                                : Icons.arrow_forward,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate',
                style: const TextStyle(
                  color: AppColors.verde,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
