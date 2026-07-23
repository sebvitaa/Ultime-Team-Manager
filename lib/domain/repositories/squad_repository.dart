import 'package:ultimate_team_manager/domain/entities/squad.dart';

abstract class SquadRepository {
  Future<Squad> getSquad();
  Future<void> saveSquad(Squad squad);
}
