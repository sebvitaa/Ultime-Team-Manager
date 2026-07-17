# Liga jugable (RF6)

La liga es **jugable**: tú juegas tu partido en la **pantalla de juego** (en vivo), el
resto de partidos de esa fecha/ronda se **simulan**, todos los resultados se
**guardan**, y la liga **avanza por fases**. Formato: 16 equipos → **4 grupos de 4**
(clasifican 2) → **cuartos → semis → final** → campeón. Sigue los mockups
`mockups/liga-1-grupos.html` y `mockups/liga-2-eliminatorias.html`. UI pensada para
**móvil**. Lógica **testeada** (5 tests OK).

## Cómo funciona (flujo)

1. **Home → Liga** abre `/league`.
2. Abajo hay una barra con **"Siguiente: Ultime FC vs {rival}"** y el botón **Jugar**.
3. **Jugar** deja el rival en `matchRequestProvider` y navega a `/match`: el partido se
   juega **en vivo** con ese rival concreto (no aleatorio).
4. Al minuto 90, el partido **guarda su resultado en la liga**
   (`leagueProvider.reportUltimeMatch(golLocal, golVisita)`), reparte monedas y muestra
   **"Continuar"** para volver.
5. La liga **simula el resto** de esa fecha (los otros 7 partidos de la fecha, o los
   otros cruces de la ronda), **actualiza tablas/bracket** y deja listo el siguiente
   partido. Se repite hasta el **campeón**.

Si Ultime FC **queda eliminado** (no clasifica de grupos o pierde un cruce), el resto
del cuadro se **simula automáticamente** hasta el campeón y la barra muestra el
resultado con **"Nueva liga"**.

---

## Archivos creados

| Archivo | Rol |
|---------|-----|
| `lib/domain/entities/league.dart` | Snapshot inmutable para la UI: `TeamStanding`, `GroupView`, `TieView`, `UltimeFixture`, `LeagueState`, `LeaguePhase`. |
| `lib/data/services/league_engine.dart` | `LeagueSim`: helpers puros (marcador de un partido y penales) sobre `MatchSimulator`. |
| `lib/presentation/providers/league_provider.dart` | `LeagueController` progresivo: calendario, jugar/guardar, simular el resto, avanzar de fase. |
| `lib/presentation/screens/league/league_screen.dart` | Pantalla jugable (pestañas Grupos/Eliminatorias + barra inferior "Jugar"). |
| `test/league_engine_test.dart` | 5 tests (helpers + flujo del controlador). |

## Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/presentation/providers/match_provider.dart` | `MatchRequest` + `matchRequestProvider`; el partido usa el rival de la liga si existe, marca `fromLeague`, y al terminar **reporta el resultado a la liga**. |
| `lib/presentation/screens/match/match_screen.dart` | En modo liga, al terminar muestra **"Continuar"** (vuelve a la liga) en vez de "Jugar de nuevo". |
| `lib/presentation/screens/home/home_screen.dart` | "Partido" ahora es **amistoso** (limpia `matchRequest`); "Liga" abre `/league`. |
| `lib/config/router/app_router.dart` | Ruta `GoRoute('/league')`. |
| `lib/config/theme/app_colors.dart` | Color `oro` para el campeón. |
| `mockups/index.html` | Mockups de liga en la galería. |

---

## La lógica (controlador progresivo)

### Estado interno (mutable) → snapshot (inmutable)
El controlador mantiene estructuras mutables (`_WGroup`, `_WFx`, `_WTie`) que se van
llenando, y en cada cambio publica un `LeagueState` nuevo (`_snapshot()`) que observa
la UI.

### Calendario de grupos
Round-robin de 4 = **3 fechas**, 2 partidos por grupo cada fecha:
`[[0,1],[2,3]] · [[0,2],[1,3]] · [[0,3],[1,2]]`. Ultime FC siempre queda de **local**
en su partido (para la pantalla de juego).

### Jugar una fecha de grupos
`reportUltimeMatch(ug, rg)`:
- Aplica tu resultado a **tu** partido (Ultime local).
- **Simula** los otros 7 partidos de la fecha (`LeagueSim.score`).
- Acumula estadísticas y **ordena** cada tabla (puntos → dif. de gol → goles a favor).
- Avanza la fecha. Tras la 3ª, `_finishGroups()` arma los **cuartos** (1A-2B, 1B-2A,
  1C-2D, 1D-2C). Si Ultime **no** quedó top 2 → `_autoCompleteBracket()`.

### Jugar una eliminatoria
`_playKnockout(ug, rg)`:
- Aplica tu resultado; si tu partido **empata**, se define por **penales**
  (`LeagueSim.pens`, favorece a la media más alta).
- Simula los **otros cruces** de la ronda (`_ensurePlayed`).
- Si **ganaste**, arma la siguiente ronda (semis → final → campeón). Si **perdiste**,
  `_autoCompleteBracket()` completa todo el cuadro hasta el campeón.

### Próximo partido
`next` (en el snapshot) es el rival y la etiqueta del partido pendiente de Ultime
("Fase de grupos · Fecha 2", "Cuartos de final", …), o `null` si Ultime ya no juega.

---

## Conexión partido ↔ liga

- `matchRequestProvider` (StateProvider): la liga deja ahí el rival antes de ir a jugar;
  Home lo pone en `null` para el amistoso.
- `MatchController._newMatch()`: usa el rival del request si existe (marca
  `fromLeague = true`); si no, rival aleatorio.
- `MatchController._finish()`: reparte monedas y, si `fromLeague`, llama a
  `leagueProvider.reportUltimeMatch(golLocal, golVisita)`.
- El `leagueProvider` **no** es autoDispose → la liga **persiste durante la sesión**,
  así que al volver del partido ves la tabla y el bracket actualizados.

---

## Interfaz (móvil)

- **Grupos:** `ListView` de 4 tarjetas; columnas de ancho fijo + nombre con
  `Expanded`/`ellipsis` (no desborda). Top 2 en verde, Ultime FC resaltado. Cabecera
  con la fecha jugada.
- **Eliminatorias:** bracket con **scroll horizontal y vertical**; cuartos → semis →
  final → campeón. Los cruces aún no definidos muestran **"Por definir"**; el ganador
  va en verde; el campeón en tarjeta dorada (`Icons.emoji_events`).
- **Barra inferior "Jugar"**: `bottomNavigationBar` con el próximo rival + botón; al
  terminar la liga muestra el campeón + **"Nueva liga"**.

---

## Tests

`test/league_engine_test.dart` — `flutter test`, 5/5 OK:

1. `LeagueSim.pens` **nunca empata**.
2. El **favorito marca más** goles en promedio.
3. La liga **arranca en grupos** (4×4) con un partido pendiente.
4. Jugar **3 fechas** cierra los grupos (todos `played == 3`) y **arma el bracket**.
5. **Ganando siempre**, Ultime FC termina **campeón** (`phase == done`).

```
$ flutter test test/league_engine_test.dart
00:00 +5: All tests passed!
```
`dart analyze lib/ test/` → **No issues found!**

---

## Qué queda (opcional)

- **Persistir** la liga entre sesiones (SharedPreferences) para no re-sortear al reabrir.
- Mostrar en el bracket el **camino de Ultime** más destacado, o un resumen de la fecha
  simulada ("Resultados de la jornada").
