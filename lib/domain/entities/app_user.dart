class AppUser {
  final String id;
  final String email;

  /// Nombre del equipo del usuario (`nombre_equipo` en Supabase). Puede ser
  /// null si la cuenta se creó sin club o si aún no se ha cargado el perfil.
  final String? teamName;

  const AppUser({
    required this.id,
    required this.email,
    this.teamName,
  });
}