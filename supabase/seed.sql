-- ============================================================================
-- Ultimate Team Manager — datos semilla
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

-- Jugadores semilla (sin api_id, sin equipo real, sin foto).
insert into jugadores (id, nombre, posicion, puntaje, precio) values
  -- 11 titular
  ('p1',  'Mateo Rojas',       'gk', 84, 1185),
  ('p2',  'Iker Fuentes',      'lb', 81, 1063),
  ('p3',  'Diego Salas',       'cb', 86, 1272),
  ('p4',  'Bruno Castillo',    'cb', 83, 1144),
  ('p5',  'Nicolás Vidal',     'rb', 80, 1024),
  ('p6',  'Simón Aránguiz',    'cm', 87, 1317),
  ('p7',  'Tomás Herrera',     'cm', 85, 1228),
  ('p8',  'Franco Bravo',      'cm', 82, 1103),
  ('p9',  'Emiliano Torres',   'lw', 88, 1363),
  ('p10', 'Agustín Morales',   'st', 91, 1507),
  ('p11', 'Lucas Peñailillo',  'rw', 89, 1410),
  -- Banca
  ('b1',  'Cristóbal Núñez',   'gk', 79, 986),
  ('b2',  'Matías Cárdenas',   'lb', 76, 878),
  ('b3',  'Joaquín Silva',     'cb', 78, 949),
  ('b4',  'Vicente Molina',    'cb', 77, 913),
  ('b5',  'Ignacio Paredes',   'rb', 75, 844),
  ('b6',  'Benjamín Soto',     'cm', 80, 1024),
  ('b7',  'Maximiliano Reyes', 'cm', 78, 949),
  ('b8',  'Cristóbal Vera',    'lw', 79, 986),
  ('b9',  'Martín Contreras',  'st', 81, 1063),
  ('b10', 'Sebastián Flores',  'rw', 78, 949)
on conflict (id) do nothing;
