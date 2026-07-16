import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';
import 'package:contador_app/presentation/widgets/squad/average_rating_header.dart';
import 'package:contador_app/presentation/widgets/squad/formation_layout.dart';
import 'package:contador_app/presentation/widgets/squad/pitch_geometry.dart';
import 'package:contador_app/presentation/widgets/squad/player_card.dart';
import 'package:contador_app/presentation/widgets/squad/squad_pitch_background.dart';

/// Pantalla de plantilla: cancha vertical con el 11 titular en 4-3-3 y la
/// valoración media del equipo arriba. Solo lectura por ahora (la edición
/// de posiciones queda para el mercado).
class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: SquadPitchBackground()),
            if (squad.isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.verde),
              )
            else if (squad.errorMessage != null)
              Center(
                child: Text(
                  squad.errorMessage!,
                  style: const TextStyle(color: AppColors.texto),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final pitch = computePitchRect(constraints.biggest);
                  final players = squad.players;
                  final offsets = mapPlayersToPitch(players, pitch);
                  final cardWidth = pitch.width * 0.20;
                  final cardHeight = cardWidth * 1.42;

                  return Stack(
                    children: [
                      for (var i = 0; i < players.length; i++)
                        Positioned(
                          left: offsets[i].dx - cardWidth / 2,
                          top: offsets[i].dy - cardHeight / 2,
                          child: PlayerCard(
                            player: players[i],
                            width: cardWidth,
                          ),
                        ),
                    ],
                  );
                },
              ),
            Positioned(
              top: 8,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
                onPressed: () => context.pop(),
              ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: AverageRatingHeader(average: squad.averageRating),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
