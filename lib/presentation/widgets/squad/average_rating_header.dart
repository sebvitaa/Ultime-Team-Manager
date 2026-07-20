import 'package:flutter/material.dart';
import 'package:ultime_team_manager/config/theme/app_colors.dart';

/// Píldora con la valoración media del 11, tipo "chemistry/rating" de FUT.
class AverageRatingHeader extends StatelessWidget {
  final double average;

  const AverageRatingHeader({super.key, required this.average});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pildora,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.pildora.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            average.round().toString(),
            style: TextStyle(
              color: AppColors.fondo,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'MEDIA DEL EQUIPO',
            style: TextStyle(
              color: AppColors.fondo.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
