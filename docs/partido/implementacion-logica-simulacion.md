# Implementación de la lógica de simulación (puntos 1-5)

Preview de la **lógica** de partido (RF5), **sin UI**. Cubre entradas, goles
esperados, reparto minuto a minuto, relato de eventos y el reloj de reproducción.
Todo es lógica pura y **testeada** (`test/match_simulator_test.dart`, 4 tests OK).

## Archivos creados

| Archivo | Rol |
|---------|-----|
| `lib/domain/entities/league_team.dart` | Entidad `LeagueTeam` (nombre, país, media estimada). |
| `lib/data/league_teams.dart` | **Liga artificial**: los 15 mejores clubes reales + `randomRival`. |
| `lib/domain/entities/match_event.dart` | Entidad `MatchEvent` + enums `MatchEventType` / `MatchTeam`. |
| `lib/domain/entities/match_result.dart` | Entidad `MatchResult` (marcador + timeline completo). |
| `lib/core/services/match_simulator.dart` | El **motor**: λ, goles minuto a minuto, relato y `playback`. |
| `test/match_simulator_test.dart` | Tests con semilla fija que verifican las invariantes. |

*(No se modificó ningún archivo existente; es todo nuevo y aislado.)*

---

## 1. Rivales: 15 equipos reales con valoración estimada

`lib/data/league_teams.dart` — datos artificiales (no vienen de la API), los mejores
15 clubes del mundo (principalmente Europa), con media estimada 79-85:

```dart
const List<LeagueTeam> kLeagueTeams = [
  LeagueTeam(name: 'Manchester City', country: 'Inglaterra', rating: 85),
  LeagueTeam(name: 'Real Madrid', country: 'España', rating: 85),
  LeagueTeam(name: 'Bayern München', country: 'Alemania', rating: 84),
  LeagueTeam(name: 'Arsenal', country: 'Inglaterra', rating: 83),
  LeagueTeam(name: 'Liverpool', country: 'Inglaterra', rating: 83),
  LeagueTeam(name: 'Inter de Milán', country: 'Italia', rating: 82),
  LeagueTeam(name: 'Paris Saint-Germain', country: 'Francia', rating: 82),
  LeagueTeam(name: 'Barcelona', country: 'España', rating: 82),
  LeagueTeam(name: 'Atlético de Madrid', country: 'España', rating: 81),
  LeagueTeam(name: 'Bayer Leverkusen', country: 'Alemania', rating: 81),
  LeagueTeam(name: 'Borussia Dortmund', country: 'Alemania', rating: 80),
  LeagueTeam(name: 'Juventus', country: 'Italia', rating: 80),
  LeagueTeam(name: 'AC Milan', country: 'Italia', rating: 80),
  LeagueTeam(name: 'Napoli', country: 'Italia', rating: 79),
  LeagueTeam(name: 'Tottenham', country: 'Inglaterra', rating: 79),
];

LeagueTeam randomRival(Random rng, {String? exclude}) { ... }
```

`randomRival` elige un rival al azar (con opción de excluir un nombre, p. ej. el club
del usuario). El local usa `squad.averageRating`; el rival, su `rating` estimado.

---

## 2. Entidades

`match_event.dart` — un evento con su minuto:

```dart
enum MatchEventType { kickoff, goal, commentary, fullTime }
enum MatchTeam { local, visita }

class MatchEvent {
  final int minute;            // 0..90
  final MatchEventType type;
  final MatchTeam? team;       // null en relato/inicio/fin
  final String text;
  bool get isGoal => type == MatchEventType.goal;
}
```

`match_result.dart` — el partido entero:

```dart
class MatchResult {
  final String localName, visitaName;
  final int ratingLocal, ratingVisita;
  final int golLocal, golVisita;
  final List<MatchEvent> events;   // cronológico: inicio -> ... -> final
  bool get localWon => golLocal > golVisita;
  bool get isDraw   => golLocal == golVisita;
  String get scoreline => '$golLocal - $golVisita';
}
```

---

## 3. El motor: `MatchSimulator`

`lib/core/services/match_simulator.dart`. Función pura `simulate(...)` que recibe
nombres + medias (+ `Random` opcional para reproducibilidad) y devuelve el
`MatchResult` con **todo** el timeline.

### Punto 2 — goles esperados (λ)

```dart
static const double base = 1.35, k = 1.8, homeAdvantage = 1.15;

final lamLocal  = base * pow(ratingLocal  / ratingVisita, k) * homeAdvantage;
final lamVisita = base * pow(ratingVisita / ratingLocal , k);
final pLocal  = lamLocal  / 90;   // prob. de gol por minuto
final pVisita = lamVisita / 90;
```

### Puntos 3 y 4 — bucle minuto a minuto (goles + relato)

```dart
for (var m = 1; m <= 90; m++) {
  var goalThisMinute = false;

  if (r.nextDouble() < pLocal)  { golLocal++;  goalThisMinute = true; /* evento GOL local  */ }
  if (r.nextDouble() < pVisita) { golVisita++; goalThisMinute = true; /* evento GOL visita */ }

  // Relato: minuto aleatorio (Poisson ~1/6), SOLO si no hubo gol en este
  // minuto ni en el anterior (para no pisar la narración del gol).
  if (!goalThisMinute && !goalLastMinute && r.nextDouble() < commentaryRate) {
    var idx = r.nextInt(_phrases.length);
    while (idx == lastPhrase && _phrases.length > 1) idx = r.nextInt(_phrases.length);
    lastPhrase = idx;
    // evento COMENTARIO con _phrases[idx] (reemplaza {local}/{visita})
  }
  goalLastMinute = goalThisMinute;
}
```

Detalles clave que pediste:
- **`commentaryRate = 1/6`** → un relato aparece con probabilidad 1/6 por minuto
  (equivale a un Poisson de tasa ~1/6, ~1 cada 6 minutos).
- **Condición del relato**: `!goalThisMinute && !goalLastMinute` → nunca hay relato en
  un minuto con gol **ni en el minuto siguiente** a un gol.
- **Minutos aleatorios**: el relato no es cada N fijo, sale por azar en cada minuto
  elegible.
- **~30 frases** (`_phrases`) + 8 frases de gol (`_goalPhrases`), con placeholders
  `{local}`/`{visita}`, y se **evita repetir** la frase inmediatamente anterior.

### Punto 5 — reloj de reproducción (`playback`)

Lógica pura (un `Stream`, sin UI). El resultado ya está calculado; `playback` lo
**revela minuto a minuto** al ritmo de `perMinute` (partido = ~20 s → ~220 ms/minuto):

```dart
static const Duration matchDuration = Duration(seconds: 20);
static Duration get perMinute =>
    Duration(milliseconds: matchDuration.inMilliseconds ~/ 90);

static Stream<MatchSnapshot> playback(MatchResult result, {Duration? perMinute}) async* {
  final step = perMinute ?? MatchSimulator.perMinute;
  var gl = 0, gv = 0;
  for (var m = 0; m <= 90; m++) {
    final atMinute = result.events.where((e) => e.minute == m).toList();
    for (final e in atMinute) { if (e.isGoal) e.team == MatchTeam.local ? gl++ : gv++; }
    yield MatchSnapshot(minute: m, golLocal: gl, golVisita: gv, newEvents: atMinute);
    if (m < 90) await Future.delayed(step);
  }
}
```

`MatchSnapshot(minute, golLocal, golVisita, newEvents)` es lo que la futura pantalla
consumirá para pintar reloj, marcador y relato — pero **eso ya es UI y no se hizo**.

---

## 4. Tests (verificación)

`test/match_simulator_test.dart` — 4 tests con semilla fija (`flutter test`, todos OK):

1. El **marcador coincide** con la cantidad de eventos de gol (50 semillas).
2. **No hay relato** en un minuto con gol ni justo después.
3. Empieza en `kickoff` (min 0) y termina en `fullTime` (min 90), y los eventos van
   **en orden** de minuto.
4. El **favorito marca más** goles en promedio (200 semillas).

```
$ flutter test test/match_simulator_test.dart
00:00 +4: All tests passed!
```

---

## Cómo usarlo (ejemplo)

```dart
final rng = Random();
final rival = randomRival(rng, exclude: 'Real Madrid');
final result = MatchSimulator.simulate(
  localName: 'Ultime FC',
  ratingLocal: ref.read(squadControllerProvider).averageRating,
  visitaName: rival.name,
  ratingVisita: rival.rating,
  rng: rng,
);
// Para el "en vivo":
MatchSimulator.playback(result).listen((snap) { /* actualizar estado */ });
```

---

## Interfaz y conexión (nuevo)

Se programó la **pantalla de partido** siguiendo el mockup elegido
(`match-final-vs-comentarios.html`) y se **conectó** con la lógica y con el resto de
la app (Home → Partido). También se incluyó el **punto 6** (recompensa en monedas),
que vive en el controlador.

### Archivos creados

| Archivo | Rol |
|---------|-----|
| `lib/presentation/providers/match_provider.dart` | `MatchController` (Riverpod `autoDispose`) + `MatchState` + `MatchPhase`. Elige rival, simula, **reproduce** el timeline minuto a minuto (`playback`) y al final **reparte monedas**. |
| `lib/presentation/screens/match/match_screen.dart` | La pantalla: fondo diagonal (`CustomPaint`), cronómetro con punto LIVE, cara a cara (nombre + media + marcador con "pop"), línea de tiempo con marcas de gol y relato en vivo. Al terminar, muestra las monedas y un botón "Jugar de nuevo". |

### Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/config/router/app_router.dart` | Import de `MatchScreen` + nueva ruta `GoRoute(path: '/match')`. |
| `lib/presentation/screens/home/home_screen.dart` | La tarjeta **"Partido"** pasó de deshabilitada ("Próximamente") a activa: `onTap: () => context.push('/match')`. |

### Cómo se conecta el estado con la lógica

```dart
final matchControllerProvider =
    NotifierProvider.autoDispose<MatchController, MatchState>(MatchController.new);

// build(): un partido nuevo cada vez que entras (autoDispose lo limpia al salir).
MatchState _newMatch() {
  final rng = Random();
  final rival = randomRival(rng, exclude: 'Real Madrid');           // rival real
  final ratingLocal = ref.read(squadControllerProvider).averageRating.round();
  final result = MatchSimulator.simulate(localName: 'Ultime FC', ...);
  _sub = MatchSimulator.playback(result).listen((snap) {            // reloj en vivo
    state = state.copyWith(minute: snap.minute, golLocal: ..., events: [...]);
    if (snap.minute >= 90) _finish(result);
  });
  return MatchState(phase: MatchPhase.playing, ...);
}

// Punto 6: monedas según resultado del local.
void _finish(MatchResult r) {
  final coins = _reward(r.golLocal, r.golVisita); // victoria 500+50·gf · empate 200 · derrota 75
  ref.read(coinsProvider.notifier).earn(coins);
  state = state.copyWith(phase: MatchPhase.finished, coinsAwarded: coins);
}
```

La pantalla solo **observa** `matchControllerProvider` y pinta; el `AnimatedSwitcher`
del marcador da el "pop" al marcar, y `_LiveDot` parpadea mientras se juega.

### Flujo completo

`Home → "Partido"` → `/match` → se juega un partido (rival real aleatorio, media del
plantel del usuario) → reloj y relato en vivo → al minuto 90 reparte monedas y
aparece **"Jugar de nuevo"**. `dart analyze` limpio y los 4 tests del simulador siguen
pasando.

---

## Qué queda

- **Liga / jornadas** (RF6 completo): guardar resultados, tabla de posiciones y
  encadenar partidos contra los 15 equipos.
- Ajustes finos de balance (constantes `BASE`/`K`) y, si se quiere, que el usuario
  también pueda jugar de visitante.
