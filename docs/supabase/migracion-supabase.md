# Migración a Supabase

Plan y esquema para migrar **Ultimate Team Manager** de almacenamiento local
(SharedPreferences + assets) a **Supabase** (Postgres + Auth), con la clave de que
**las llamadas a API-Football inyectan sus datos en Supabase** (no se consulta la API
directo desde la UI; se persiste en la base y la app lee de ahí).

El esquema completo está en **`docs/supabase/schema.sql`** (aplícalo en Supabase →
SQL Editor).

---

## 1. Tablas

| Tabla | Qué guarda | Dueño (RLS) |
|-------|------------|-------------|
| `profiles` | Perfil del usuario: nombre del club y **monedas**. 1:1 con `auth.users`. | El propio usuario |
| `players` | **Catálogo global** de jugadores. Lo pueblan las llamadas a API-Football (UPSERT). | Lectura y UPSERT para autenticados |
| `squad_players` | La **plantilla** del usuario (11 titulares + banca) con puesto y slot. | El propio usuario |
| `leagues` | Una **liga** del usuario: fase, fecha, campeón. | El propio usuario |
| `league_teams` | Los 16 equipos de una liga + estadísticas de grupo. | Dueño de la liga |
| `league_ties` | Los cruces de eliminatoria (cuartos/semis/final) con marcador y penales. | Dueño de la liga |
| `match_history` | Historial de partidos jugados (amistosos y de liga) + monedas. | El propio usuario |

**Enums:** `player_position` (gk, lb, cb, rb, cm, lw, st, rw), `league_phase`
(groups, quarters, semis, final, done), `player_source` (api, seed, market).

**Triggers:**
- `set_updated_at` mantiene `updated_at` en `profiles` y `players`.
- `handle_new_user` crea automáticamente el `profiles` al registrarse (con las monedas
  iniciales, hoy 1000 — ajustable en el `default` de la columna).

**RLS:** activada en todas. Cada usuario solo ve/escribe lo suyo; `players` es un
catálogo compartido (lectura + UPSERT para autenticados, para que el cliente inyecte
lo de la API). En producción ese UPSERT se movería a una **Edge Function** con
`service_role`, pero para el proyecto va directo desde el cliente.

---

## 2. Cómo aplicar el esquema

1. En Supabase → **SQL Editor** → pega el contenido de `docs/supabase/schema.sql` →
   **Run**.
2. Comprueba en **Table Editor** que están las 7 tablas.
3. (Auth) En **Authentication → Providers**, deja habilitado **Email**.

---

## 3. Conexión del proyecto (cuando me pases las claves)

Necesito de tu proyecto Supabase (Settings → API):
- **Project URL** (`https://xxxx.supabase.co`)
- **anon public key**

Los pondré en `.env` (ya está gitignoreado):

```env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
API_KEY=...            # la de API-Football que ya tienes
```

Y el arranque quedaría así:

```dart
// pubspec.yaml → dependencies: supabase_flutter: ^2.x
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;
```

---

## 4. Inyección de la API en Supabase (lo clave)

Hoy `ApiFootballDatasource` pega a la API y el mercado cachea en SharedPreferences.
La nueva idea: **la API alimenta la tabla `players`** y la app lee de Supabase.

Flujo:

1. Un servicio (p. ej. `PlayersSyncService`) pide a **API-Football** los planteles de
   los equipos configurados (`marketTeams`).
2. Cada jugador se mapea a una fila de `players` y se hace **UPSERT** (por `id`):

   ```dart
   Future<void> syncTeam(int teamId) async {
     final players = await _api.fetchTeamPlayers(teamId); // llamada a API-Football
     final rows = players.map((p) => {
       'id': p.id,                 // 'api_756'
       'name': p.name,
       'rating': p.rating,
       'position': p.position.name,
       'price': p.price,
       'photo_url': p.photoUrl,
       'team_id': teamId,
       'source': 'api',
     }).toList();
     await supabase.from('players').upsert(rows); // <-- inyecta en Supabase
   }
   ```

3. El **mercado** ya no llama a la API: lee de `players` en Supabase, restando los que
   ya tiene el usuario (`squad_players`):

   ```dart
   final data = await supabase
       .from('players')
       .select()
       .order('rating', ascending: false);
   ```

4. La sincronización se dispara cuando conviene (primer arranque del día, o un botón
   "actualizar mercado"), respetando el límite de 100 req/día — pero como los datos ya
   viven en Supabase, las siguientes cargas son **0 llamadas a la API**.

> Búsqueda: `searchPlayers(query)` hace la llamada a la API y también **upsertea** los
> resultados en `players`, así lo buscado queda persistido para todos.

---

## 5. Qué repositorios cambian (local → Supabase)

Gracias a la arquitectura por contratos, la UI y los providers **no cambian**; solo se
sustituye la implementación del repositorio (una línea en cada provider):

| Contrato (domain) | Hoy | Con Supabase |
|-------------------|-----|--------------|
| `AuthRepository` | `AuthRepositoryLocal` (demo + prefs) | `AuthRepositorySupabase` (`supabase.auth.signInWithPassword`, `signUp`, `currentSession`) |
| `MarketRepository` | `MarketRepositoryApi` (API + prefs) | `MarketRepositorySupabase` (lee `players`; el sync inyecta la API) |
| `SquadRepository` | `SquadRepositoryLocal` (json + prefs) | `SquadRepositorySupabase` (`squad_players`) |
| Monedas (`coins_provider`) | prefs | columna `profiles.coins` |
| Liga (`league_provider`) | en memoria | `leagues` / `league_teams` / `league_ties` (opcional) |

Ejemplo del cambio en un provider:

```dart
// lib/presentation/providers/auth_provider.dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositorySupabase(); // <- antes: AuthRepositoryLocal()
});
```

---

## 6. Qué necesito de ti

- **Project URL** y **anon key** de Supabase (para el `.env`).
- Confirmar que aplicaste `schema.sql` (o dime y te guío).

Con eso hago, en este orden:
1. Añadir `supabase_flutter` e inicializar en `main.dart`.
2. `AuthRepositorySupabase` (login/registro reales) — reemplaza el demo.
3. `PlayersSyncService` + `MarketRepositorySupabase` (la **API inyecta en `players`**,
   el mercado lee de Supabase).
4. `SquadRepositorySupabase` y monedas en `profiles`.
5. (Opcional) persistir la liga.

Cada paso lo dejo con su cambio documentado, como hasta ahora.
