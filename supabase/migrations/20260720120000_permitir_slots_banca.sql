-- ----------------------------------------------------------------------------
-- Permitir slots de banca (>= 100) en user_jugadores.
--
-- El esquema inicial definía `slot smallint check (slot between 0 and 10)`
-- (pensado para banca = null). Pero la app codifica la banca con slots >= 100
-- (`_benchBase = 100` en SquadRepositorySupabase), por lo que guardar cualquier
-- suplente violaba user_jugadores_slot_check (code 23514).
--
-- Se relaja el check a `slot >= 0`: admite el 11 titular (0..10) y la banca
-- (>= 100). El índice único parcial user_jugadores_slot_unico
-- (user_id, slot) where slot is not null sigue garantizando un jugador por slot.
-- ----------------------------------------------------------------------------

alter table user_jugadores
  drop constraint if exists user_jugadores_slot_check;

alter table user_jugadores
  add constraint user_jugadores_slot_check check (slot >= 0);
