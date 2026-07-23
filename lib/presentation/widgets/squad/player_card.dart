import 'package:flutter/material.dart';
import 'package:ultimate_team_manager/config/theme/app_colors.dart';
import 'package:ultimate_team_manager/domain/entities/player.dart';

/// Carta estilo FUT para un jugador: valoración, avatar, nombre y posición.
/// [width] la fija el layout de la cancha (11 cartas deben caber sin
/// superponerse en cualquier tamaño de pantalla), la altura se deriva de una
/// proporción fija (ver [heightFor]).
class PlayerCard extends StatelessWidget {
  final Player player;
  final double width;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.width,
    this.onTap,
  });

  // Proporción carta: un poco más alta que 2:3 para que el nombre en 2
  // líneas no quede apretado.
  static const double aspectRatio = 1.62;
  static double heightFor(double width) => width * aspectRatio;

  // Tono de acento según la valoración: los 85+ destacan en dorado-verde.
  Color get _accent =>
      player.rating >= 85 ? AppColors.pildora : AppColors.verde2;

  // Foto real del jugador (photoUrl); si falta o falla, icono de reserva.
  Widget _avatar(double size) {
    final fallback =
        Icon(Icons.person, color: AppColors.gris, size: size * 0.62);
    final url = player.photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = heightFor(width);
    final ratingSize = width * 0.30;
    final avatarSize = width * 0.46;
    final nameSize = (width * 0.128).clamp(9.0, 11.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.carbon,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${player.rating}',
                    style: TextStyle(
                      color: AppColors.fondo,
                      fontSize: ratingSize.clamp(11, 17),
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: avatarSize,
                height: avatarSize,
                clipBehavior: Clip.antiAlias, // recorta la foto al círculo
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.fondo,
                  border: Border.all(color: AppColors.borde),
                ),
                child: _avatar(avatarSize),
              ),
              const Spacer(),
              // Nombre y apellido en 2 líneas centradas, para que el nombre
              // completo siempre se alcance a leer.
              Text(
                player.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: nameSize,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              if (player.lastName.isNotEmpty)
                Text(
                  player.lastName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              Text(
                player.position.displayLabel,
                style: TextStyle(
                  color: AppColors.gris,
                  fontSize: (width * 0.115).clamp(8, 10),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
