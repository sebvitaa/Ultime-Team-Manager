-- ============================================================================
-- Ultime Team Manager — datos semilla
-- Idempotente: se puede ejecutar más de una vez sin duplicar filas.
--
-- Los 21 jugadores son los mismos de assets/data/squad.json (la plantilla
-- offline inicial). El resto del catálogo se rellena progresivamente desde
-- API-Football con los créditos gratuitos.
-- ============================================================================

-- Liga base del mercado (última temporada disponible en el plan gratuito).
insert into ligas (id, nombre, pais, temporada) values
  (140, 'La Liga', 'España', 2023)
on conflict (id) do nothing;

-- Equipos cuyos planteles pueblan el mercado.
insert into equipos (id, nombre, liga_id, logo_url_api) values
  (541, 'Real Madrid', 140, 'https://media.api-sports.io/football/teams/541.png'),
  (529, 'Barcelona', 140, 'https://media.api-sports.io/football/teams/529.png'),
  (530, 'Atlético de Madrid', 140, 'https://media.api-sports.io/football/teams/530.png')
on conflict (id) do nothing;
