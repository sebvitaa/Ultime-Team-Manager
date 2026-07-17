# Lógica de la simulación de partido (RF5 + RF6)

Diseño de cómo funcionaría la pantalla de partido — mockup
`mockups/match-final-vs-comentarios.html` (cara a cara + relato en vivo). Aquí se
explica **la lógica**, todavía sin implementar en Dart; es la guía para armarla.

> Idea: dos equipos con su **valoración media** se enfrentan; el resultado sale de un
> modelo probabilístico basado en esa media, los goles se reparten a lo largo de 90'
> simulados, y se emite un **relato** en vivo. Al final se reparten **monedas** según
> el resultado.

---

## 1. Entradas

| Dato | De dónde sale |
|------|----------------|
| `ratingLocal` | `squad.averageRating` (ya calculado en `squad_provider.dart`). |
| `ratingVisita` | Media del rival: de una tabla de liga fija, o generada en un rango (p. ej. 74–86). |
| `nombreLocal` / `nombreVisita` | El club del usuario y el rival de la jornada. |
| `seed` (opcional) | Semilla del `Random` → simulación **reproducible** y testeable. |

---

## 2. Modelo de resultado: goles esperados (λ)

Cada equipo tiene una tasa de **goles esperados** `λ` derivada de la fuerza relativa
(cociente de medias) más una pequeña **ventaja de local**:

```
lambdaLocal  = BASE * (ratingLocal  / ratingVisita) ^ K * VENTAJA_LOCAL
lambdaVisita = BASE * (ratingVisita / ratingLocal ) ^ K
```

Constantes sugeridas (ajustables):

| Constante | Valor | Qué controla |
|-----------|-------|--------------|
| `BASE` | `1.35` | Goles medios por equipo y partido (~1.4 real). |
| `K` | `1.8` | Cuánto pesa la diferencia de nivel (más alto = el favorito golea más). |
| `VENTAJA_LOCAL` | `1.15` | Empujón del equipo local. |

**Ejemplo (78 vs 81, local 78):**
`lambdaLocal = 1.35·(78/81)^1.8·1.15 ≈ 1.45` · `lambdaVisita = 1.35·(81/78)^1.8 ≈ 1.44`
→ partido parejo (la ventaja de local casi compensa los 3 puntos de media).

---

## 3. Reparto de goles en el tiempo (minuto a minuto)

En vez de calcular el marcador de golpe, se **simula minuto a minuto** (1…90). Esto da
naturalmente el marcador final **y** alimenta el reloj, la línea de tiempo y el relato.

En cada minuto, cada equipo mete gol con probabilidad `λ/90`:

```
prob_gol_por_minuto = lambda / 90
```

```pseudo
para m = 1..90:
    si random() < lambdaLocal/90:  golLocal++;  emitir evento GOL (local, m)
    si random() < lambdaVisita/90: golVisita++; emitir evento GOL (visita, m)
    si no hubo gol y m % 6 == 0:   emitir evento RELATO (frase random, m)
```

Esto equivale a un **proceso de Poisson**: el total de goles de cada equipo tiende a
`Poisson(λ)`, pero repartido en el tiempo. (Si algún día se quiere el marcador
instantáneo sin animación, basta muestrear `goles ~ Poisson(λ)` y asignar minutos al
azar — mismo resultado estadístico.)

> Opcional: ponderar un poco los goles hacia el final (más goles en los últimos 15').
> Se logra multiplicando `prob_gol_por_minuto` por un factor `1 + 0.4·(m/90)`.

---

## 4. Relato / eventos

Dos tipos de evento, en una lista que la UI muestra de más nuevo a más viejo:

- **GOL:** `"¡GOOOL de <equipo>! <descripción>"` (dispara el `pop` del marcador y una
  marca en la línea de tiempo).
- **RELATO:** frase de relleno de un pool (`"Presión alta de …"`, `"Contragolpe…"`),
  cada ~6 minutos si no hubo gol, para que el partido "respire".

```dart
const relleno = [
  'Circula el balón por el mediocampo.',
  'Presión alta de {local}.',
  'Recupera {visita} y sale rápido.',
  'Centro al área, despeja la defensa.',
  'Tiro desviado, sigue el partido.',
];
```

> Se puede enriquecer usando **nombres reales** del plantel (ya los tienes): elegir un
> delantero al azar del equipo que marca para el texto del gol.

---

## 5. Reloj (tiempo simulado)

El "minuto" avanza con un `Timer.periodic`. Un partido de 90' dura pocos segundos:

```
DURACION_REAL ≈ 20 s   →   intervalo = 20000 / 90 ≈ 220 ms por minuto
```

(Es justo lo que hace el mockup: `setInterval(..., 220)`.) Configurable: partido más
rápido/lento cambiando la duración total.

---

## 6. Recompensa en monedas (RF6)

Al terminar, se suman monedas según el resultado (vía `coins_provider.earn(...)`):

| Resultado | Monedas sugeridas |
|-----------|-------------------|
| Victoria | `500 + 50 · golesFavor` |
| Empate | `200` |
| Derrota | `75` |

```dart
int recompensa(int gf, int gc) {
  if (gf > gc) return 500 + 50 * gf; // victoria
  if (gf == gc) return 200;          // empate
  return 75;                          // derrota (algo, para no frustrar)
}
```

---

## 7. Cómo encaja en Flutter (arquitectura actual)

Mismo patrón que Mercado/Plantilla (domain / data / presentation + Riverpod):

| Archivo (nuevo) | Rol |
|-----------------|-----|
| `domain/entities/match_event.dart` | `MatchEvent(minute, type, team, text)`; `type ∈ {gol, relato, inicio, fin}`. |
| `domain/entities/match_result.dart` | Marcador final, lista de eventos, monedas ganadas. |
| `core/services/match_simulator.dart` | **Función pura**: dados 2 ratings + `Random`, devuelve todo el timeline. Sin UI → testeable. |
| `presentation/providers/match_provider.dart` | `MatchController extends Notifier<MatchState>`: reloj, marcador, eventos visibles, estado (jugando/terminado); reparte monedas al final. |
| `presentation/screens/match/match_screen.dart` | La pantalla VS + comentarios (el mockup). |
| `config/router/app_router.dart` | Ruta `/match` (entrada desde Home → "Partido"). |

### Estado que observa la UI

```dart
enum MatchPhase { idle, playing, finished }

class MatchState {
  final String localName, visitaName;
  final int ratingLocal, ratingVisita;
  final int minute;             // 0..90
  final int golLocal, golVisita;
  final List<MatchEvent> events; // más nuevo primero
  final MatchPhase phase;
  final int coinsAwarded;
}
```

### El simulador (función pura)

```dart
class MatchSimulator {
  static const base = 1.35, k = 1.8, ventajaLocal = 1.15;

  // Devuelve TODOS los eventos ya con su minuto (la UI solo los va revelando).
  static List<MatchEvent> simulate({
    required int ratingLocal, required int ratingVisita,
    required String local, required String visita, Random? rng,
  }) {
    final r = rng ?? Random();
    final lamL = base * pow(ratingLocal/ratingVisita, k) * ventajaLocal;
    final lamV = base * pow(ratingVisita/ratingLocal, k);
    final ev = <MatchEvent>[MatchEvent(0, EventType.inicio, null, 'Rueda el balón.')];
    for (var m = 1; m <= 90; m++) {
      final gol = <bool>[];
      if (r.nextDouble() < lamL/90) { ev.add(MatchEvent(m, EventType.gol, Team.local,  '¡GOL de $local!'));  gol.add(true); }
      if (r.nextDouble() < lamV/90) { ev.add(MatchEvent(m, EventType.gol, Team.visita, '¡GOL de $visita!')); gol.add(true); }
      if (gol.isEmpty && m % 6 == 0) ev.add(MatchEvent(m, EventType.relato, null, _fraseRandom(r)));
    }
    ev.add(MatchEvent(90, EventType.fin, null, 'Final del partido.'));
    return ev;
  }
}
```

### El controlador (reloj + revelado + monedas)

```dart
class MatchController extends Notifier<MatchState> {
  Timer? _timer;
  late List<MatchEvent> _timeline;

  void start() {
    final squad = ref.read(squadControllerProvider);
    final rLocal = squad.averageRating;
    final rVisita = _rivalRating(); // tabla o random
    _timeline = MatchSimulator.simulate(ratingLocal: rLocal, ratingVisita: rVisita, ...);
    state = MatchState(minute: 0, phase: MatchPhase.playing, ...);
    _timer = Timer.periodic(const Duration(milliseconds: 220), (_) => _advance());
  }

  void _advance() {
    final m = state.minute + 1;
    final nuevos = _timeline.where((e) => e.minute == m);
    // aplica goles + agrega eventos + actualiza minuto
    state = state.copyWith(minute: m, events: [...nuevos.reversed, ...state.events], ...);
    if (m >= 90) _finish();
  }

  void _finish() {
    _timer?.cancel();
    final coins = recompensa(state.golLocal, state.golVisita);
    ref.read(coinsProvider.notifier).earn(coins);
    state = state.copyWith(phase: MatchPhase.finished, coinsAwarded: coins);
  }
}
```

> Clave: el simulador genera **todo el timeline de una vez** (rápido y testeable) y el
> controlador solo lo **revela minuto a minuto** con el `Timer`. Así la pantalla se ve
> "en vivo" pero el resultado ya está decidido de forma consistente.

---

## 8. Parámetros a ajustar (todo en un sitio)

- `BASE`, `K`, `VENTAJA_LOCAL` → cuántos goles y cuánto pesa el favorito.
- Duración total del partido (ms por minuto).
- Frecuencia del relato de relleno (`m % 6`).
- Tabla de recompensas de monedas.
- Cómo se elige el rival y su media.

## 9. Qué queda para "la lógica de verdad"

1. Crear las entidades `MatchEvent` / `MatchResult`.
2. Escribir `MatchSimulator.simulate(...)` (función pura) + un **test** con semilla fija.
3. Crear `MatchController` + `MatchState` (Riverpod), con el `Timer`.
4. Construir `match_screen.dart` copiando el layout del mockup elegido.
5. Añadir la ruta `/match` y enlazar el botón **"Partido"** del Home.
6. (Liga) Guardar el resultado y las monedas; encadenar jornadas.
