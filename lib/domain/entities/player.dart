// Posiciones concretas dentro del 4-3-3 (no solo la línea GK/DEF/MED/DEL),
// porque la alineación necesita ubicar a cada jugador en un punto distinto
// de la cancha (ej: lateral izquierdo vs. central).
enum PlayerPosition { gk, lb, cb, rb, cm, lw, st, rw }

extension PlayerPositionX on PlayerPosition {
  // Etiqueta corta para la insignia de la carta.
  String get displayLabel => switch (this) {
        PlayerPosition.gk => 'POR',
        PlayerPosition.lb => 'LI',
        PlayerPosition.cb => 'DFC',
        PlayerPosition.rb => 'LD',
        PlayerPosition.cm => 'MC',
        PlayerPosition.lw => 'EI',
        PlayerPosition.st => 'DC',
        PlayerPosition.rw => 'ED',
      };

  // Línea a la que pertenece, útil para colorear/agrupar en la UI.
  PlayerPositionGroup get group => switch (this) {
        PlayerPosition.gk => PlayerPositionGroup.goalkeeper,
        PlayerPosition.lb ||
        PlayerPosition.cb ||
        PlayerPosition.rb =>
          PlayerPositionGroup.defense,
        PlayerPosition.cm => PlayerPositionGroup.midfield,
        PlayerPosition.lw ||
        PlayerPosition.st ||
        PlayerPosition.rw =>
          PlayerPositionGroup.attack,
      };
}

enum PlayerPositionGroup { goalkeeper, defense, midfield, attack }

class Player {
  final String id;
  final String name;
  final int rating; // escala 1-100
  final PlayerPosition position;

  const Player({
    required this.id,
    required this.name,
    required this.rating,
    required this.position,
  });

  // Para mostrar el nombre en 2 líneas en la carta (nombre / apellido).
  String get firstName {
    final idx = name.indexOf(' ');
    return idx == -1 ? name : name.substring(0, idx);
  }

  String get lastName {
    final idx = name.indexOf(' ');
    return idx == -1 ? '' : name.substring(idx + 1);
  }
}
