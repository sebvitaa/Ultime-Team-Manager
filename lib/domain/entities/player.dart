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

extension PlayerPositionGroupX on PlayerPositionGroup {
  // Etiqueta corta para filtros/menús (dropdown del mercado).
  String get displayLabel => switch (this) {
        PlayerPositionGroup.goalkeeper => 'POR',
        PlayerPositionGroup.defense => 'DEF',
        PlayerPositionGroup.midfield => 'MED',
        PlayerPositionGroup.attack => 'DEL',
      };
}

class Player {
  final String id;
  final String name;
  final int rating; // escala 1-100
  final PlayerPosition position;
  final int price; // monedas para comprar/vender en el mercado
  final String? photoUrl; // foto real (API); null => avatar de ícono

  const Player({
    required this.id,
    required this.name,
    required this.rating,
    required this.position,
    this.price = 0,
    this.photoUrl,
  });

  // Precio de mercado derivado de la valoración: curva convexa para que los
  // cracks cuesten desproporcionadamente más (70→686, 80→1024, 91→1507).
  static int priceForRating(int rating) =>
      (rating * rating * rating / 500).round();

  // Para mostrar el nombre en 2 líneas en la carta (nombre / apellido).
  String get firstName {
    final idx = name.indexOf(' ');
    return idx == -1 ? name : name.substring(0, idx);
  }

  String get lastName {
    final idx = name.indexOf(' ');
    return idx == -1 ? '' : name.substring(idx + 1);
  }

  Player copyWith({PlayerPosition? position}) {
    return Player(
      id: id,
      name: name,
      rating: rating,
      position: position ?? this.position,
      price: price,
      photoUrl: photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rating': rating,
        'position': position.name,
        'price': price,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] as int;
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      rating: rating,
      position: PlayerPosition.values.byName(json['position'] as String),
      // La semilla antigua no traía precio: se deriva de la valoración.
      price: (json['price'] as int?) ?? priceForRating(rating),
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
