-- Crash Racing («کرش ریسینگ») best-race / best-lap leaderboards per track (games project).
-- RLS: every signed-in player inserts only their own runs; everyone reads. No update / delete from clients.
create table if not exists public.crash_racing_times (
  id          bigint generated always as identity primary key,
  player_id   uuid        not null default auth.uid(),
  track       text        not null check (track in ('jungle', 'temple', 'beach')),
  character   text        not null check (character in ('fox', 'raccoon', 'numbat', 'glider', 'wombat', 'quokka')),
  race_ms     integer     not null check (race_ms between 30000 and 1800000),
  best_lap_ms integer     not null check (best_lap_ms between 8000 and 600000),
  place       smallint    not null check (place between 1 and 6),
  created_at  timestamptz not null default now(),
  -- sanity: the best of three laps can never be slower than the average lap
  constraint crash_racing_times_lap_sane check (best_lap_ms * 3 <= race_ms + 1500)
);

create index if not exists crash_racing_times_race_idx on public.crash_racing_times (track, race_ms);
create index if not exists crash_racing_times_lap_idx on public.crash_racing_times (track, best_lap_ms);
create index if not exists crash_racing_times_player_idx on public.crash_racing_times (player_id, created_at desc);

alter table public.crash_racing_times enable row level security;

drop policy if exists crash_racing_times_read on public.crash_racing_times;
create policy crash_racing_times_read on public.crash_racing_times
  for select to anon, authenticated using (true);

drop policy if exists crash_racing_times_insert_own on public.crash_racing_times;
create policy crash_racing_times_insert_own on public.crash_racing_times
  for insert to authenticated with check (player_id = auth.uid());

revoke all on public.crash_racing_times from anon, authenticated;
grant select on public.crash_racing_times to anon, authenticated;
grant insert (player_id, track, character, race_ms, best_lap_ms, place) on public.crash_racing_times to authenticated;

-- Anti-spam: one run per player every 20 s (a real 3-lap race takes over a minute).
create or replace function public.crash_racing_times_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.crash_racing_times
    where player_id = new.player_id and created_at > now() - interval '20 seconds'
  ) then
    raise exception 'crash_racing: too many runs' using errcode = 'P0001';
  end if;
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists crash_racing_times_rate on public.crash_racing_times;
create trigger crash_racing_times_rate before insert on public.crash_racing_times
  for each row execute function public.crash_racing_times_rate();

-- Board: each player's best time on a track (race or lap), ranked, with the mirrored username.
create or replace function public.crash_racing_board(p_track text, p_kind text default 'race', p_limit integer default 20)
returns table (rank integer, player_id uuid, username text, ms integer, "character" text, created_at timestamptz)
language sql
stable
set search_path = public
as $$
  with best as (
    select distinct on (t.player_id)
      t.player_id,
      case when p_kind = 'lap' then t.best_lap_ms else t.race_ms end as ms,
      t.character,
      t.created_at
    from public.crash_racing_times t
    where t.track = p_track
    order by t.player_id, (case when p_kind = 'lap' then t.best_lap_ms else t.race_ms end), t.created_at
  )
  select (row_number() over (order by b.ms, b.created_at))::integer,
         b.player_id,
         coalesce(p.username, '—'),
         b.ms,
         b.character,
         b.created_at
  from best b
  left join public.profiles p on p.id = b.player_id
  order by b.ms, b.created_at
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

grant execute on function public.crash_racing_board(text, text, integer) to anon, authenticated;
