-- ============================================================================
-- Ultime Team Manager — esquema inicial (Supabase: Postgres + Storage)
--
-- Correcciones aplicadas sobre el schema del TODO.md:
--   1. Sin columna de password: la autenticación la maneja Supabase Auth
--      (auth.users); el perfil del juego vive en `profiles` (1 a 1).
--   2. `jugadores` es un CATÁLOGO global compartido (se rellena
--      progresivamente con los créditos gratuitos de API-Football) y la
--      propiedad va en la tabla puente `user_jugadores` (así dos usuarios
--      pueden tener al mismo jugador). Desaparece la columna JSON de Users.
--   3. `jugadores` gana `nombre` y `posicion` (las cartas los necesitan).
--   4. `equipos` pierde su lista de jugadores (la cubre el FK
--      jugadores.equipo_id) y su liga se normaliza en la tabla `ligas`.
--   5. `profiles` gana `monedas` (RF4, faltaba en el TODO).
--   6. El puesto en el 11 titular es `slot` (0-10, índice en kFormation433
--      de la app) porque el 4-3-3 repite posiciones (2 DFC, 3 MC) y una
--      posición por usuario no alcanzaría. `slot null` = banca.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tipos
-- ----------------------------------------------------------------------------

-- Posiciones concretas del 4-3-3 (mismos valores que el enum de la app).
create type posicion_jugador as enum ('gk','lb','cb','rb','cm','lw','st','rw');

-- ----------------------------------------------------------------------------
-- Tablas de catálogo (compartidas entre todos los usuarios)
-- ----------------------------------------------------------------------------

-- Ligas reales (ids de API-Football, ej. 140 = La Liga).
create table ligas (
  id        int primary key,          -- id de API-Football
  nombre    text not null,
  pais      text,
  temporada int not null              -- ej. 2023 (última del plan gratuito)
);

-- Equipos reales (ids de API-Football, ej. 541 = Real Madrid).
create table equipos (
  id           int primary key,       -- id de API-Football
  nombre       text not null,
  liga_id      int references ligas (id),
  puntaje      int check (puntaje between 1 and 100), -- caché del promedio
  logo_path    text,                  -- ruta en el bucket `media`
  logo_url_api text                   -- respaldo: URL original de la API
);

-- Catálogo global de jugadores. PK de texto para calzar con los ids que ya
-- usa la app ('api_83' para la API, 'p1'/'b3' para la semilla).
create table jugadores (
  id           text primary key,
  api_id       int unique,            -- null para los jugadores semilla
  nombre       text not null,
  posicion     posicion_jugador not null,
  puntaje      int not null check (puntaje between 1 and 100),
  precio       int not null check (precio > 0),
  equipo_id    int references equipos (id),
  foto_path    text,                  -- ruta en el bucket `media`
  foto_url_api text,                  -- respaldo: URL original de la API
  creado_en    timestamptz not null default now()
);

create index jugadores_puntaje_idx on jugadores (puntaje desc); -- orden mercado
create index jugadores_equipo_idx on jugadores (equipo_id);

-- ----------------------------------------------------------------------------
-- Perfil del juego (1 a 1 con auth.users; sin passwords aquí)
-- ----------------------------------------------------------------------------

create table profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  apodo         text not null,
  nombre_equipo text not null default 'Mi Club',
  monedas       int not null default 5000 check (monedas >= 0),
  creado_en     timestamptz not null default now()
);

-- Propiedad + estado de plantilla. `slot` es el índice (0-10) del puesto en
-- kFormation433 de la app: 0 EI, 1 DC, 2 ED, 3-5 MC, 6 LI, 7-8 DFC, 9 LD,
-- 10 POR. `slot null` = está en la banca.
create table user_jugadores (
  user_id      uuid not null references profiles (id) on delete cascade,
  jugador_id   text not null references jugadores (id),
  slot         smallint check (slot between 0 and 10),
  adquirido_en timestamptz not null default now(),
  primary key (user_id, jugador_id)
);

-- Un solo jugador por puesto del 11 titular.
create unique index user_jugadores_slot_unico
  on user_jugadores (user_id, slot)
  where slot is not null;

-- ----------------------------------------------------------------------------
-- Trigger: crear el profile al registrarse un usuario
-- ----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, apodo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'apodo', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- RPCs atómicos de compra/venta (evitan carreras y trampas con las monedas)
-- ----------------------------------------------------------------------------

-- Compra: descuenta monedas y agrega el jugador a la banca del usuario.
-- Devuelve el nuevo saldo. Errores: MONEDAS_INSUFICIENTES, YA_ES_TUYO,
-- JUGADOR_INEXISTENTE.
create or replace function public.comprar_jugador(p_jugador_id text)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_precio  int;
  v_monedas int;
begin
  select precio into v_precio from jugadores where id = p_jugador_id;
  if v_precio is null then
    raise exception 'JUGADOR_INEXISTENTE';
  end if;

  -- Bloquea el perfil para que dos compras simultáneas no dupliquen saldo.
  select monedas into v_monedas from profiles where id = v_user for update;
  if v_monedas < v_precio then
    raise exception 'MONEDAS_INSUFICIENTES';
  end if;

  begin
    insert into user_jugadores (user_id, jugador_id) values (v_user, p_jugador_id);
  exception when unique_violation then
    raise exception 'YA_ES_TUYO';
  end;

  update profiles set monedas = monedas - v_precio where id = v_user
    returning monedas into v_monedas;
  return v_monedas;
end;
$$;

-- Venta: quita el jugador (solo si está en la banca: los titulares no se
-- venden) y suma su precio al saldo. Devuelve el nuevo saldo.
-- Error: NO_VENDIBLE (no es tuyo o es titular).
create or replace function public.vender_jugador(p_jugador_id text)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_precio  int;
  v_monedas int;
begin
  delete from user_jugadores
    where user_id = v_user and jugador_id = p_jugador_id and slot is null;
  if not found then
    raise exception 'NO_VENDIBLE';
  end if;

  select precio into v_precio from jugadores where id = p_jugador_id;
  update profiles set monedas = monedas + v_precio where id = v_user
    returning monedas into v_monedas;
  return v_monedas;
end;
$$;

grant execute on function public.comprar_jugador(text) to authenticated;
grant execute on function public.vender_jugador(text) to authenticated;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

alter table ligas          enable row level security;
alter table equipos        enable row level security;
alter table jugadores      enable row level security;
alter table profiles       enable row level security;
alter table user_jugadores enable row level security;

-- Perfil: cada usuario ve y edita solo el suyo (el insert lo hace el trigger).
create policy profiles_select_propio on profiles
  for select using (id = auth.uid());
create policy profiles_update_propio on profiles
  for update using (id = auth.uid());

-- Plantilla propia: CRUD completo solo de las filas del usuario.
create policy user_jugadores_propio on user_jugadores
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Catálogos: lectura pública. Escritura para usuarios autenticados: el
-- rellenado progresivo del catálogo lo hacen los propios clientes con sus
-- créditos gratuitos de la API (tradeoff aceptado para el proyecto de curso;
-- en producción esto pasaría por un backend con service_role). Sin DELETE.
create policy ligas_lectura on ligas for select using (true);
create policy ligas_insert on ligas
  for insert to authenticated with check (true);
create policy ligas_update on ligas
  for update to authenticated using (true);

create policy equipos_lectura on equipos for select using (true);
create policy equipos_insert on equipos
  for insert to authenticated with check (true);
create policy equipos_update on equipos
  for update to authenticated using (true);

create policy jugadores_lectura on jugadores for select using (true);
create policy jugadores_insert on jugadores
  for insert to authenticated with check (true);
create policy jugadores_update on jugadores
  for update to authenticated using (true);

-- ----------------------------------------------------------------------------
-- Storage: bucket `media` (fotos de jugadores y logos de equipos)
-- Rutas: jugadores/{id}.png · equipos/{id}.png
-- ----------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

-- Lectura pública del bucket; subida/actualización solo autenticados.
create policy media_lectura_publica on storage.objects
  for select using (bucket_id = 'media');
create policy media_insert_autenticado on storage.objects
  for insert to authenticated with check (bucket_id = 'media');
create policy media_update_autenticado on storage.objects
  for update to authenticated using (bucket_id = 'media');
