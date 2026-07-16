import 'package:flutter/material.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/presentation/widgets/player_list_row.dart';

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
            PlayerListRow(
              player: current,
              subtitle: 'Titular · ${current.position.displayLabel}',
              highlighted: true,
            ),
            const SizedBox(height: 20),
            Text(
              'BANCA · ${current.position.group.displayLabel}',
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
                (p) => PlayerListRow(
                  player: p,
                  subtitle: 'Suplente · ${p.position.group.displayLabel}',
                  onTap: () => onSelectSubstitute(p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
