-- NEXORA Station UI · daily lucky wheel on the economy ledger (2026-11-26). Social/auth project (eisstodgncimypdawisy).
-- Requires 20261126000000_economy_ledger.sql (nx_wallet_apply) and 20261126215000_nx_luna_persona_and_daily_wheel.sql
-- (nx_wheel_spins, _nx_wheel_next_at, nx_wheel_status). Idempotent.
--
-- Replaces nx_spin_wheel(): one free spin per user per Tehran calendar day (nx_wheel_spins PK user_id + day), the
-- prize is picked server-side and credited ONLY through nx_wallet_apply (append-only ledger row, reason 'wheel_daily',
-- idempotent on 'wheel:<user>:<day>'), so no balance change can bypass the ledger. Returns the result + next_at.
create or replace function public.nx_spin_wheel() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  today date := (now() at time zone 'Asia/Tehran')::date;
  prizes int[] := array[50, 100, 150, 200, 250, 300, 100, 50];   -- must match StationWheelScreen.kPrizes
  weights int[] := array[22, 18, 12, 8, 5, 3, 18, 14];           -- sum 100
  roll int; acc int := 0; i int; pick int := 1; res jsonb; total int;
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

  insert into nx_wheel_spins(user_id, day, idx, prize) values (me, today, pick - 1, prizes[pick])
  on conflict (user_id, day) do nothing;
  if not found then
    select coins into total from profiles where id = me;
    return jsonb_build_object('ok', false, 'error', 'already_spun', 'coins_total', total, 'next_at', _nx_wheel_next_at());
  end if;

  res := nx_wallet_apply(me, prizes[pick], 0, 'wheel_daily', today::text, 'wheel:' || me || ':' || today, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then raise exception 'wallet: %', res ->> 'error'; end if;

  return jsonb_build_object(
    'ok', true,
    'index', pick - 1,
    'prize', prizes[pick],
    'coins_total', (res ->> 'coins')::int,
    'gems_total', (res ->> 'gems')::int,
    'next_at', _nx_wheel_next_at()
  );
end $$;
revoke all on function public.nx_spin_wheel() from public, anon;
grant execute on function public.nx_spin_wheel() to authenticated;
