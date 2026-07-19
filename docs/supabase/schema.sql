-- ============================================================================
--  Ultime Team Manager · Esquema de base de datos (Supabase / PostgreSQL)
--  Aplícalo en Supabase → SQL Editor (una sola vez). Idempotente en lo posible.
-- ============================================================================

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ----------------------------------------------------------------------------
--  ENUMS
-- ----------------------------------------------------------------------------
do $$ begin
  create type player_position as enum ('gk','lb','cb','rb','cm','lw','st','rw');
exception when duplicate_object then null; end $$;

do $$ begin
  create type league_phase as enum ('groups','quarters','semis','final','done');
exception when duplicate_object then null; end $$;

do $$ begin
  create type player_source as enum ('api','seed','market');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
--  profiles · perfil del usuario (1:1 con auth.users). Guarda club y monedas.
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  club_name   text        not null default 'Ultime FC',
  coins       integer     not null default 1000 check (coins >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
--  players · CATÁLOGO GLOBAL de jugadores. Lo pueblan las llamadas a
--  API-Football (UPSERT por id). El mercado lee de aquí, no de la API directa.
-- ----------------------------------------------------------------------------
create table if not exists public.players (
  id          text        primary key,               -- 'api_756', 'seed_p1'...
  name        text        not null,
  rating      integer     not null check (rating between 1 and 100),
  position    player_position not null,
  price       integer     not null default 0 check (price >= 0),
  photo_url   text,
  team_id     integer,                                -- equipo en API-Football
  team_name   text,
  season      integer,
  source      player_source not null default 'api',
  updated_at  timestamptz not null default now()
);
create index if not exists players_position_idx on public.players (position);
create index if not exists players_team_idx     on public.players (team_id);
create index if not exists players_rating_idx   on public.players (rating desc);

-- ----------------------------------------------------------------------------
--  squad_players · la plantilla del usuario (11 titulares + banca).
--  Vender = borrar la fila (el jugador vuelve a estar disponible en players).
-- ----------------------------------------------------------------------------
create table if not exists public.squad_players (
  user_id     uuid    not null references auth.users(id)   on delete cascade,
  player_id   text    not null references public.players(id) on delete cascade,
  is_starter  boolean not null default false,
  position    player_position not null,       -- puesto en el 11 o línea en banca
  slot        integer,                         -- 0..10 en el 11 (orden en cancha)
  created_at  timestamptz not null default now(),
  primary key (user_id, player_id)
);
create index if not exists squad_user_idx on public.squad_players (user_id);

-- ----------------------------------------------------------------------------
--  LIGA · persistencia del torneo (grupos + eliminatorias). Opcional pero
--  incluida para que la liga sobreviva al cerrar la app.
-- ----------------------------------------------------------------------------
create table if not exists public.leagues (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  phase             league_phase not null default 'groups',
  matchday          integer not null default 0,
  champion_team_id  uuid,                       -- se setea al terminar (FK abajo)
  created_at        timestamptz not null default now()
);
create index if not exists leagues_user_idx on public.leagues (user_id);

create table if not exists public.league_teams (
  id             uuid primary key default gen_random_uuid(),
  league_id      uuid not null references public.leagues(id) on delete cascade,
  name           text not null,
  rating         integer not null,
  group_name     text,                          -- 'A'..'D'
  is_ultime      boolean not null default false,
  played         integer not null default 0,
  won            integer not null default 0,
  drawn          integer not null default 0,
  lost           integer not null default 0,
  goals_for      integer not null default 0,
  goals_against  integer not null default 0
);
create index if not exists league_teams_league_idx on public.league_teams (league_id);

do $$ begin
  alter table public.leagues
    add constraint leagues_champion_fk
    foreign key (champion_team_id) references public.league_teams(id) on delete set null;
exception when duplicate_object then null; end $$;

create table if not exists public.league_ties (
  id            uuid primary key default gen_random_uuid(),
  league_id     uuid not null references public.leagues(id) on delete cascade,
  round         text not null,                  -- 'Cuartos','Semis','Final'
  home_team_id  uuid references public.league_teams(id) on delete cascade,
  away_team_id  uuid references public.league_teams(id) on delete cascade,
  home_goals    integer,
  away_goals    integer,
  on_pens       boolean not null default false,
  home_pens     integer not null default 0,
  away_pens     integer not null default 0
);
create index if not exists league_ties_league_idx on public.league_ties (league_id);

-- ----------------------------------------------------------------------------
--  match_history · historial de partidos (amistosos y de liga).
-- ----------------------------------------------------------------------------
create table if not exists public.match_history (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  rival_name    text not null,
  rival_rating  integer,
  user_goals    integer not null,
  rival_goals   integer not null,
  is_league     boolean not null default false,
  coins_awarded integer not null default 0,
  played_at     timestamptz not null default now()
);
create index if not exists match_history_user_idx on public.match_history (user_id);

-- ============================================================================
--  TRIGGERS
-- ============================================================================

-- updated_at automático
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_players_updated on public.players;
create trigger trg_players_updated before update on public.players
  for each row execute function public.set_updated_at();

-- Crear el perfil automáticamente al registrarse un usuario
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
--  ROW LEVEL SECURITY (RLS)
-- ============================================================================
alter table public.profiles      enable row level security;
alter table public.players        enable row level security;
alter table public.squad_players  enable row level security;
alter table public.leagues        enable row level security;
alter table public.league_teams   enable row level security;
alter table public.league_ties    enable row level security;
alter table public.match_history  enable row level security;

-- profiles: cada quien ve/edita el suyo
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- players (catálogo compartido): cualquier autenticado lee; y puede hacer UPSERT
-- (así el cliente inyecta los datos de la API). Para producción esto se movería
-- a una Edge Function con service_role, pero para el proyecto va directo.
create policy "players_select_auth" on public.players
  for select to authenticated using (true);
create policy "players_insert_auth" on public.players
  for insert to authenticated with check (true);
create policy "players_update_auth" on public.players
  for update to authenticated using (true);

-- squad_players: solo lo del dueño
create policy "squad_own" on public.squad_players
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- leagues: solo lo del dueño
create policy "leagues_own" on public.leagues
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- league_teams / league_ties: se controlan por el dueño de la liga padre
create policy "league_teams_own" on public.league_teams
  for all
  using (exists (select 1 from public.leagues l where l.id = league_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.leagues l where l.id = league_id and l.user_id = auth.uid()));

create policy "league_ties_own" on public.league_ties
  for all
  using (exists (select 1 from public.leagues l where l.id = league_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.leagues l where l.id = league_id and l.user_id = auth.uid()));

-- match_history: solo lo del dueño
create policy "match_history_own" on public.match_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  FIN
-- ============================================================================
