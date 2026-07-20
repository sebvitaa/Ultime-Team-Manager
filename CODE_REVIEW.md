# Code Review — Ultime Team Manager

Review of the current codebase (branch `debugging`). Focus areas: security &
validation, performance & complexity, code quality (SOLID/DRY), error handling.


## Findings

Severity legend: **Critical** (exploitable / data loss now) · **High** (crash
or corruption under normal use) · **Medium** (correctness/maintainability) ·
**Low** (hardening / polish).

---

### 1. [CRITICAL] Supabase **service-role secret** and DB password shipped to every client
**Location:** `pubspec.yaml:30` (`- .env`) together with `.env`
(`SUPABASE_SECRET_KEY`, `SUPABASE_PASSWORD`).

**Rationale:** Every path listed under `flutter/assets` is bundled into the
distributable app. On the **web** build (the current run target) the file is
served verbatim at `/assets/.env` and can be downloaded in plaintext by anyone;
on mobile it is trivially extracted from the package. `SUPABASE_SECRET_KEY`
(the `service_role` key) **bypasses Row-Level Security**, granting full
read/write over the entire database to any visitor — plus the raw DB password is
exposed. This is a complete backend compromise. The file's own comment even
warns *"NO pongas aquí la secret key"*, yet it is present.

**Recommended fix:**
1. **Rotate now** in the Supabase dashboard: regenerate the service_role/secret
   key and change the database password (assume both are compromised).
2. Ship only the public/anon key to the client. Remove the secrets from the
   client `.env`:
   ```dotenv
   # .env  (client) — ONLY public values
   SUPABASE_URL=https://<project>.supabase.co
   SUPABASE_ANON_KEY=<publishable/anon key>
   API_KEY=<api-football key>
   ```
3. Any operation that genuinely needs the secret key must run server-side
   (Supabase Edge Function / RPC), never in the Flutter app.

---

### 2. [HIGH] `getSquad` crashes on a single malformed catalog row (unvalidated casts + `byName`)
**Location:** `lib/data/repositories/squad_repository_supabase.dart` —
`_toPlayer` (`lib/.../squad_repository_supabase.dart`, the `as`/`byName` block)
and `getSquad` (`(r['slot'] as num).toInt()`).

**Rationale:** `PlayerPosition.values.byName(j['posicion'] as String)` throws
`ArgumentError` if `posicion` is not an exact enum name, and the `as num` /
`as String` casts throw on `NULL`. These run inside a loop with **no per-row
guard**, so one bad/NULL row in `jugadores` throws out of `getSquad`; the
generic `catch` in `SquadController._loadSquad` then reports *"No se pudo cargar
la plantilla"* and the **whole squad fails to load** because of one row.

**Recommended fix:** parse each row defensively and skip the bad ones:
```dart
Player? _tryToPlayer(Map<String, dynamic> j, {PlayerPosition? override}) {
  try {
    final rating = (j['puntaje'] as num?)?.toInt();
    final id = j['id'] as String?;
    final name = j['nombre'] as String?;
    if (rating == null || id == null || name == null) return null;
    final pos = override ??
        PlayerPosition.values.asNameMap()[j['posicion']] ??
        PlayerPosition.cm; // fallback en vez de lanzar
    return Player(
      id: id, name: name, rating: rating, position: pos,
      price: (j['precio'] as num?)?.toInt() ?? Player.priceForRating(rating),
      photoUrl: j['foto_url_api'] as String?,
    );
  } catch (_) {
    return null; // fila corrupta: se ignora, no rompe la plantilla
  }
}
```
and skip `null` results when building `starters`/`bench`.

---

### 3. [HIGH] Coins load race silently discards earned/spent coins (and can crash)
**Location:** `lib/presentation/providers/coins_provider.dart` — `_load`
(`state = row['monedas'] as int;`) vs `build`/`earn`/`spend`.

**Rationale:** `build()` returns `kStartingCoins` and fires `_load()`
asynchronously. If the user **earns** a match reward or **spends** in the market
before `_load` resolves, `_load` overwrites `state` with the stale server value,
silently discarding the mutation (money vanishes or a purchase is undone).
Separately, `row['monedas'] as int` throws if Postgres returns the column as a
non-`int` (e.g. `numeric`/`bigint` decoded as something else).

**Recommended fix:** don't clobber a locally-mutated state, and cast safely:
```dart
bool _touched = false; // se marca en earn/spend

Future<void> _load() async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final row = await _db.from('profiles')
        .select('monedas').eq('id', uid).maybeSingle();
    final coins = (row?['monedas'] as num?)?.toInt();
    if (coins != null && !_touched) state = coins; // no pisar cambios locales
  } catch (e) {
    debugPrint('coins _load failed: $e');
  }
}
```
Set `_touched = true` at the start of `earn`/`spend`.

---

### 4. [HIGH] `saveSquad` delete-then-insert is not atomic → squad can be wiped
**Location:** `lib/data/repositories/squad_repository_supabase.dart` —
`saveSquad` (`delete().eq('user_id', uid)` then `insert(rows)`), wrapped in
`catch (_) {}`.

**Rationale:** The delete and insert are two independent network calls. If the
connection drops (or the insert throws) **after** the delete succeeds, the
user's squad is left **empty in the database**, and the empty `catch (_) {}`
hides the failure entirely — the user only discovers it on next load when their
team is gone. Delete+insert is not a transaction.

**Recommended fix:** make it a single atomic operation. Prefer `upsert` on a
unique `(user_id, slot)` constraint (delete only the slots no longer used), or a
Postgres function invoked via `rpc` that does delete+insert in one transaction.
At minimum, do not delete until the new rows are known-good, and **log** the
error instead of swallowing it.

---

### 5. [MEDIUM] Silent empty `catch` blocks hide failures with no logging
**Location:** `squad_repository_supabase.dart` `saveSquad` (`catch (_) {}`);
`coins_provider.dart` `_persist` (`catch (_) {}`) and `_load` (`catch (_) {}`);
`lib/main.dart` `Supabase.initialize` (only `debugPrint`).

**Rationale:** Persistence failures (squad save, coin persist) are swallowed
with **no logging and no user feedback**, making field issues undebuggable and
letting local/server state diverge unnoticed. If `Supabase.initialize` fails,
the app continues in a fully broken state with a single debug line.

**Recommended fix:** log every caught error with context (a real logger, or at
least `debugPrint('saveSquad failed: $e')`); surface a non-blocking indicator
for user-affecting persistence failures; consider a retry/backoff for
`_persist`. Never write `catch (_) {}` with an empty body.

---

### 6. [MEDIUM] DRY: team-rating computation duplicated
**Location:** `lib/presentation/providers/league_provider.dart:63-64` and
`lib/presentation/providers/match_provider.dart:99-100` — both compute
`(avg >= 1 ? avg.round() : 75).clamp(1, 99)`.

**Rationale:** The same "squad average → clamped team rating" rule is copied in
two providers; a future change to the default (75) or clamp bounds must be made
in both, and will drift.

**Recommended fix:** expose it once, e.g. on `SquadState`:
```dart
// squad_provider.dart
int get teamRating => (averageRating >= 1 ? averageRating.round() : 75).clamp(1, 99);
```
and call `ref.read(squadControllerProvider).teamRating` in both providers.

---

### 7. [MEDIUM] League team name read once at build; falls back to default if auth not yet restored
**Location:** `lib/presentation/providers/league_provider.dart:62`
(`_ultimeName = ref.read(teamNameProvider);`).

**Rationale:** The name is `read` (not `watch`ed) at build time. If the league
provider is ever built before the async session restore finishes,
`teamNameProvider` returns `kDefaultTeamName` ('Ultime FC') and the user's team
keeps that name for the whole league session. Today the router guards the
league behind an authenticated session, so it's usually safe — but the
invariant is implicit and fragile.

**Recommended fix:** guarantee/assert the league is only initialized while
`AuthStatus.authenticated`, or watch `teamNameProvider` and `regenerate()` when
it first resolves to a non-default value. At minimum document the ordering
dependency.

---

### 8. [LOW] Unbounded SharedPreferences cache keys for search
**Location:** `lib/data/repositories/market_repository_api.dart` —
`searchPlayers` key `market_cache_search_${query.trim().toLowerCase()}`.

**Rationale:** Every distinct search term writes a permanent cache entry that is
never evicted, so local storage grows without bound over time (minor, but real).

**Recommended fix:** cap the number of cached searches (LRU), or periodically
purge expired `market_cache_search_*` keys on startup.

---

### 9. [LOW] Malformed / duplicate `.env` entries
**Location:** `.env` — duplicate `API_KEY` (two definitions) and trailing spaces
in key names (`SUPABASE_PASSWORD `, `SUPABASE_SECRET_KEY `, `SUPABASE_PUBLIC_KEY `).

**Rationale:** Duplicate keys make it ambiguous which value wins; key names with
a trailing space do not reliably match `dotenv.env['SUPABASE_...']` lookups.
(Also see #1 — the secret keys should be removed outright.)

**Recommended fix:** collapse to a single, trimmed set of keys with no trailing
whitespace and no duplicates.

---

### 10. [LOW] Club name accepted with no length/character bounds
**Location:** `lib/presentation/screens/auth/login_screen.dart` (club
`validator`) and `auth_repository_supabase.dart` `signUp`.

**Rationale:** Only emptiness is checked. An extremely long or control-character
club name is stored as the team name and rendered across the league/match UI.
Overflow is mostly clipped by `ellipsis`, but there is no upper bound or
sanitization.

**Recommended fix:** enforce a sensible cap and trim in the validator, e.g.
`if (v.trim().length > 30) return 'Máximo 30 caracteres';`.

---

## Notes / non-findings

- **No SQL or command injection surface.** All Supabase access uses the
  parameterized query builder (`.eq('user_id', uid)`, `.select(...)`), and
  API-Football requests encode params via `Uri.replace(queryParameters:)` — user
  input (search query) is never string-concatenated into a query.
- **No N+1 query problem.** `getSquad` fetches the squad + joined `jugadores`
  in a single `select('slot, jugadores(...)')`; the market fetches 16 teams via
  a bounded `Future.wait`, each cached.
- **`playback` is O(minutes × events)** (`.where` rescans the ~40-event list for
  each of 91 minutes) — negligible in practice; could pre-bucket events by
  minute if ever hot. Not worth changing now.
