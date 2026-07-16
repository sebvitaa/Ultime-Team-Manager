import 'package:flutter/material.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/player.dart';

/// Carta estilo FUT para un jugador: valoración, avatar, nombre y posición.
/// [width] la fija el layout de la cancha (11 cartas deben caber sin
/// superponerse en cualquier tamaño de pantalla), la altura se deriva de una
/// proporción ~2:3 típica de carta.
class PlayerCard extends StatelessWidget {
  final Player player;
  final double width;

  const PlayerCard({super.key, required this.player, required this.width});

  // Tono de acento según la valoración: los 85+ destacan en dorado-verde.
  Color get _accent =>
      player.rating >= 85 ? AppColors.pildora : AppColors.verde2;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final ratingSize = width * 0.30;
    final avatarSize = width * 0.46;

    return Container(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fondo,
              border: Border.all(color: AppColors.borde),
            ),
            child: Icon(
              Icons.person,
              color: AppColors.gris,
              size: avatarSize * 0.62,
            ),
          ),
          const Spacer(),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.texto,
              fontSize: (width * 0.135).clamp(9, 12),
              fontWeight: FontWeight.w700,
              height: 1.1,
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
    );
  }
}
