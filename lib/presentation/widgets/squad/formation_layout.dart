import 'package:flutter/material.dart';
import 'package:contador_app/domain/entities/player.dart';

// Un puesto fijo del 4-3-3 dentro de la cancha, en coordenadas fraccionales
// (-1..1, con (0,0) al centro) para poder ubicarlo sobre cualquier tamaño de
// cancha con [Alignment.withinRect].
class FormationSlot {
  final PlayerPosition position;
  final Alignment align;
  const FormationSlot(this.position, this.align);
}

// 4-3-3: delanteros arriba (área rival) y arquero abajo (área propia), como
// se lee habitualmente un armador de plantilla en vertical.
const List<FormationSlot> kFormation433 = [
  // Delanteros (algo hacia dentro para que la carta no se recorte arriba)
  FormationSlot(PlayerPosition.lw, Alignment(-0.72, -0.81)),
  FormationSlot(PlayerPosition.st, Alignment(0.0, -0.85)),
  FormationSlot(PlayerPosition.rw, Alignment(0.72, -0.81)),
  // Mediocampistas
  FormationSlot(PlayerPosition.cm, Alignment(-0.55, -0.30)),
  FormationSlot(PlayerPosition.cm, Alignment(0.0, -0.42)),
  FormationSlot(PlayerPosition.cm, Alignment(0.55, -0.30)),
  // Defensas
  FormationSlot(PlayerPosition.lb, Alignment(-0.75, 0.30)),
  FormationSlot(PlayerPosition.cb, Alignment(-0.26, 0.34)),
  FormationSlot(PlayerPosition.cb, Alignment(0.26, 0.34)),
  FormationSlot(PlayerPosition.rb, Alignment(0.75, 0.30)),
  // Arquero (algo hacia dentro para que la carta no se recorte abajo)
  FormationSlot(PlayerPosition.gk, Alignment(0.0, 0.81)),
];

// Empareja cada jugador con el puesto de su misma posición (en el mismo
// orden en que aparecen), y devuelve el punto absoluto dentro de [pitch]
// para cada uno, alineado índice a índice con [players].
List<Offset> mapPlayersToPitch(List<Player> players, Rect pitch) {
  final slotsByPosition = <PlayerPosition, List<Alignment>>{};
  for (final slot in kFormation433) {
    (slotsByPosition[slot.position] ??= []).add(slot.align);
  }

  return players.map((player) {
    final slots = slotsByPosition[player.position];
    final align = (slots != null && slots.isNotEmpty)
        ? slots.removeAt(0)
        : Alignment.center;
    return align.withinRect(pitch);
  }).toList();
}
