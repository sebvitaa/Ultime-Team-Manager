import 'package:contador_app/domain/entities/squad.dart';

abstract class SquadRepository {
  Future<Squad> getSquad();
  Future<void> saveSquad(Squad squad);
}
