import 'package:flutter/material.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/player.dart';

/// Menú que se despliega desde abajo al tocar una carta: el titular arriba
/// y, debajo, la banca disponible para esa misma posición. Tocar un
/// suplente lo sube al 11 y manda al titular a la banca.
class PlayerBenchSheet extends StatelessWidget {
  final Player current;
  final List<Player> bench;
  final ValueChanged<Player> onSelectSubstitute;

  const PlayerBenchSheet({
    super.key,
    required this.current,
    required this.bench,
    required this.onSelectSubstitute,
  });

  static const _labelStyle = TextStyle(
    color: AppColors.gris,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.carbon,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('TITULAR', style: _labelStyle),
            const SizedBox(height: 6),
            _PlayerRow(player: current, highlighted: true),
            const SizedBox(height: 20),
            Text(
              'BANCA · ${current.position.displayLabel}',
              style: _labelStyle,
            ),
            const SizedBox(height: 6),
            if (bench.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No hay suplentes disponibles para esta posición.',
                  style: TextStyle(color: AppColors.gris, fontSize: 13),
                ),
              )
            else
              ...bench.map(
                (p) => _PlayerRow(
                  player: p,
                  onTap: () => onSelectSubstitute(p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player player;
  final bool highlighted;
  final VoidCallback? onTap;

  const _PlayerRow({required this.player, this.highlighted = false, this.onTap});

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
              // Foto (placeholder) del jugador, a la izquierda.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.fondo,
                  border: Border.all(color: AppColors.borde),
                ),
                child: Icon(Icons.person, color: AppColors.gris, size: 24),
              ),
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
                      highlighted ? 'Titular' : 'Suplente',
                      style: const TextStyle(color: AppColors.gris, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Puntaje del jugador, a la derecha.
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
            ],
          ),
        ),
      ),
    );
  }
}
