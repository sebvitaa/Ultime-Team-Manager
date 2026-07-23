import 'package:ultimate_team_manager/domain/entities/player.dart';

// El 11 titular más la banca disponible (suplentes) por posición.
class Squad {
  final List<Player> starters;
  final List<Player> bench;

  const Squad({required this.starters, required this.bench});
}
