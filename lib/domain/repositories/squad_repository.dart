import 'package:contador_app/domain/entities/player.dart';

abstract class SquadRepository {
  Future<List<Player>> getSquad();
}
