-- NEXORA Station UI + LUNA (2026-11-26). Social/auth project (eisstodgncimypdawisy). Idempotent.
--
-- 1. LUNA persona: nx_oracle_persona accepts row 2 (1 = ORACLE, 2 = LUNA), seeded empty (the app ships LUNA's
--    defaults and the nx-oracle Edge Function falls back to ORACLE's verified player list for her).
-- 2. nx_oracle_persona_save(p_data, p_persona) overload ('oracle' | 'luna'); the one-argument version stays (ORACLE).
-- 3. Daily lucky wheel, enforced server-side: one free spin per user per Tehran calendar day, recorded in
--    nx_wheel_spins (PK user_id + day), prize picked and credited to profiles.coins by the server, audited in
--    nx_xp_events. nx_spin_wheel() returns the result + the next available time; nx_wheel_status() reports it.

-- ------------------------------------------------------------------------------------------------ 1. LUNA row
alter table public.nx_oracle_persona drop constraint if exists nx_oracle_persona_id_check;
alter table public.nx_oracle_persona add constraint nx_oracle_persona_id_check check (id in (1, 2));
insert into public.nx_oracle_persona(id) values (2) on conflict do nothing;

-- ------------------------------------------------------------------------------------------------ 2. save overload
create or replace function public.nx_oracle_persona_save(p_data jsonb, p_persona text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v int; rid int;
begin
  if not nx_has_perm('oracle') then raise exception 'forbidden'; end if;
  rid := case lower(coalesce(p_persona, 'oracle')) when 'oracle' then 1 when 'luna' then 2 else null end;
  if rid is null then raise exception 'bad persona'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' then raise exception 'bad config'; end if;
  if pg_column_size(p_data) > 512 * 1024 then raise exception 'config too large'; end if;
  insert into nx_oracle_persona(id) values (rid) on conflict do nothing;
  update nx_oracle_persona set data = p_data, version = version + 1, updated_by = auth.uid(), updated_at = now()
   where id = rid returning version into v;
  perform _nx_owner_log('oracle.persona.save', null, jsonb_build_object('version', v, 'persona', lower(p_persona)));
  return jsonb_build_object('ok', true, 'version', v, 'persona', lower(p_persona));
end $$;
revoke all on function public.nx_oracle_persona_save(jsonb, text) from public, anon;
grant execute on function public.nx_oracle_persona_save(jsonb, text) to authenticated;

-- ------------------------------------------------------------------------------------------------ 3. daily wheel
create table if not exists public.nx_wheel_spins (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  idx int not null check (idx between 0 and 7),
  prize int not null check (prize between 0 and 1000),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.nx_wheel_spins enable row level security;
drop policy if exists nx_wheel_spins_self on public.nx_wheel_spins;
create policy nx_wheel_spins_self on public.nx_wheel_spins for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.nx_wheel_spins from anon, authenticated;

-- Start of the next Tehran calendar day (when the next free spin opens).
create or replace function public._nx_wheel_next_at() returns timestamptz
language sql stable set search_path = public as $$
  select (((now() at time zone 'Asia/Tehran')::date + 1)::timestamp at time zone 'Asia/Tehran')
$$;

create or replace function public.nx_wheel_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); today date := (now() at time zone 'Asia/Tehran')::date; s nx_wheel_spins;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into s from nx_wheel_spins where user_id = me and day = today;
  return jsonb_build_object(
    'ok', true,
    'spun_today', s.user_id is not null,
    'index', s.idx,
    'prize', s.prize,
    'next_at', case when s.user_id is null then now() else _nx_wheel_next_at() end
  );
end $$;
revoke all on function public.nx_wheel_status() from public, anon;
grant execute on function public.nx_wheel_status() to authenticated;

-- Segments of the wheel (index → coins). Must match StationWheelScreen.kPrizes in the app.
create or replace function public.nx_spin_wheel() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  today date := (now() at time zone 'Asia/Tehran')::date;
  prizes int[] := array[50, 100, 150, 200, 250, 300, 100, 50];
  -- weights (sum 100): small prizes are common, 300 is rare
  weights int[] := array[22, 18, 12, 8, 5, 3, 18, 14];
  roll int; acc int := 0; i int; pick int := 1; total int;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'guest');
  end if;
  if nx_is_banned(me) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if not exists (select 1 from profiles where id = me) then
    return jsonb_build_object('ok', false, 'error', 'no_profile');
  end if;

  roll := floor(random() * 100)::int;
  for i in 1 .. array_length(weights, 1) loop
    acc := acc + weights[i];
    if roll < acc then pick := i; exit; end if;
  end loop;

  -- One spin per user per day: the primary key makes a second (or concurrent) spin a no-op.
  insert into nx_wheel_spins(user_id, day, idx, prize) values (me, today, pick - 1, prizes[pick])
  on conflict (user_id, day) do nothing;
  if not found then
    select coins into total from profiles where id = me;
    return jsonb_build_object('ok', false, 'error', 'already_spun', 'coins_total', total, 'next_at', _nx_wheel_next_at());
  end if;

  update profiles set coins = coins + prizes[pick] where id = me returning coins into total;
  insert into nx_xp_events(user_id, idem_key, event, xp, coins, rule)
  values (me, 'wheel.daily.' || today::text, 'wheel.daily', 0, prizes[pick], 'wheel.daily')
  on conflict (user_id, idem_key) do nothing;

  return jsonb_build_object(
    'ok', true,
    'index', pick - 1,
    'prize', prizes[pick],
    'coins_total', total,
    'next_at', _nx_wheel_next_at()
  );
end $$;
revoke all on function public.nx_spin_wheel() from public, anon;
grant execute on function public.nx_spin_wheel() to authenticated;
