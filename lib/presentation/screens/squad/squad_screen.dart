import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/domain/entities/player.dart';
import 'package:contador_app/presentation/providers/squad_provider.dart';
import 'package:contador_app/presentation/widgets/squad/average_rating_header.dart';
import 'package:contador_app/presentation/widgets/squad/formation_layout.dart';
import 'package:contador_app/presentation/widgets/squad/pitch_geometry.dart';
import 'package:contador_app/presentation/widgets/squad/player_bench_sheet.dart';
import 'package:contador_app/presentation/widgets/squad/player_card.dart';
import 'package:contador_app/presentation/widgets/squad/squad_pitch_background.dart';

/// Pantalla de plantilla: cancha vertical con el 11 titular en 4-3-3 y la
/// valoración media del equipo arriba. Al tocar una carta se abre la banca
/// disponible para esa posición y se puede hacer el cambio.
class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  void _openBenchSheet(
    BuildContext context,
    WidgetRef ref,
    Player current,
    SquadState squad,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlayerBenchSheet(
        current: current,
        bench: squad.benchFor(current),
        onSelectSubstitute: (substitute) {
          ref
              .read(squadControllerProvider.notifier)
              .swapWithBench(current, substitute);
          Navigator.of(context).pop();
        },
      ),
    );
  }

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
                  final cardWidth = pitch.width * 0.185;
                  final cardHeight = PlayerCard.heightFor(cardWidth);

                  return Stack(
                    children: [
                      for (var i = 0; i < players.length; i++)
                        Positioned(
                          left: offsets[i].dx - cardWidth / 2,
                          top: offsets[i].dy - cardHeight / 2,
                          child: PlayerCard(
                            player: players[i],
                            width: cardWidth,
                            onTap: () => _openBenchSheet(
                                context, ref, players[i], squad),
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
              top: 350,
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
