import 'package:flutter/material.dart';
import 'package:ultime_team_manager/config/theme/app_colors.dart';
import 'package:ultime_team_manager/domain/entities/player.dart';

/// Fila reutilizable de jugador (banca, mercado): foto a la izquierda,
/// nombre + subtítulo al centro, chip de puntaje y un `trailing` opcional
/// (ej: precio) a la derecha. Altura mínima 56 para un buen tap target.
class PlayerListRow extends StatelessWidget {
  final Player player;
  final String subtitle;
  final bool highlighted;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PlayerListRow({
    super.key,
    required this.player,
    required this.subtitle,
    this.highlighted = false,
    this.trailing,
    this.onTap,
  });

  Color get _accent =>
      player.rating >= 85 ? AppColors.pildora : AppColors.verde2;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.verde.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: highlighted
                ? Border.all(color: AppColors.verde.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              _PlayerAvatar(photoUrl: player.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: AppColors.gris, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Puntaje del jugador.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${player.rating}',
                  style: const TextStyle(
                    color: AppColors.fondo,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto circular del jugador; si no hay URL o falla la descarga, cae al
/// ícono de silueta de siempre.
class _PlayerAvatar extends StatelessWidget {
  final String? photoUrl;
  const _PlayerAvatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.fondo,
        border: Border.all(color: AppColors.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? const Icon(Icons.person, color: AppColors.gris, size: 24)
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person, color: AppColors.gris, size: 24),
            ),
    );
  }
}
