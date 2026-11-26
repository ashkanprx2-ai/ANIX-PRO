-- NEXORA GAMES project · cosmetics shop v1 (2026-11-25, owner request): Carrom boards and piece sets sold for COINS.
--
-- Wallet: coins are NOT a new balance. The real balance is the auth project's public.profiles.coins; this project's
-- public.profiles is its mirror (20261117100000_g_mirror_bridge.sql). Spending here updates the mirror row atomically;
-- the nx_profiles_delta trigger records the delta in nx_wallet_tx (reason 'cosmetic:<item>') and nx_wallet_push
-- (pg_cron, every minute) applies it on the auth project, exactly like tournament entry fees (_nx_t_charge).
--
-- * nx_cosmetics           catalog (item id, game, kind, coin price, active). Seeded below; admins may edit prices
--                          (UPDATE needs the 'shop' permission claim). The seed never overwrites an existing price.
-- * nx_cosmetic_owned      what each player owns (RLS: read own rows; writes only through the RPCs).
-- * nx_cosmetic_equipped   what each player has equipped per game + slot (RLS: read own rows).
-- * buy_cosmetic(item)     SECURITY DEFINER: price from the catalog only, never from the client; checks + deducts the
--                          coin balance and grants ownership in one transaction; idempotent (owned -> no charge).
-- * equip_cosmetic(item)   SECURITY DEFINER: equips an owned (or free) item in its game/slot.
-- * my_cosmetics()         owned ids + equipped map + coin balance (client cache refresh).
-- Coins only: the catalog has no gem column and the check constraint keeps prices in 0..100000 coins.
-- Idempotent; never drops data. NOT auto-applied: run with the games project's migration flow.

create table if not exists public.nx_cosmetics (
  item_id text primary key check (item_id ~ '^[a-z0-9_]+:[a-z0-9_]{1,48}$'),
  game text not null,
  kind text not null,               -- 'board' | 'pieces'
  name text not null,
  name_fa text,
  price_coins integer not null default 0 check (price_coins between 0 and 100000),
  active boolean not null default true,
  sort integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.nx_cosmetics enable row level security;
drop policy if exists nx_cosmetics_read on public.nx_cosmetics;
create policy nx_cosmetics_read on public.nx_cosmetics for select to anon, authenticated using (true);
drop policy if exists nx_cosmetics_admin on public.nx_cosmetics;
create policy nx_cosmetics_admin on public.nx_cosmetics for update to authenticated
  using (public.nx_perm('shop')) with check (public.nx_perm('shop'));

create table if not exists public.nx_cosmetic_owned (
  user_id uuid not null,
  item_id text not null references public.nx_cosmetics(item_id) on update cascade,
  price_paid integer not null default 0,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);
alter table public.nx_cosmetic_owned enable row level security;
drop policy if exists nx_cosmetic_owned_own on public.nx_cosmetic_owned;
create policy nx_cosmetic_owned_own on public.nx_cosmetic_owned for select to authenticated using (user_id = auth.uid());

create table if not exists public.nx_cosmetic_equipped (
  user_id uuid not null,
  game text not null,
  kind text not null,
  item_id text not null references public.nx_cosmetics(item_id) on update cascade,
  updated_at timestamptz not null default now(),
  primary key (user_id, game, kind)
);
alter table public.nx_cosmetic_equipped enable row level security;
drop policy if exists nx_cosmetic_equipped_own on public.nx_cosmetic_equipped;
create policy nx_cosmetic_equipped_own on public.nx_cosmetic_equipped for select to authenticated using (user_id = auth.uid());
-- other players' equipped boards / pieces are public (an online opponent may show them)
drop policy if exists nx_cosmetic_equipped_read on public.nx_cosmetic_equipped;
create policy nx_cosmetic_equipped_read on public.nx_cosmetic_equipped for select to authenticated using (true);

revoke insert, update, delete on public.nx_cosmetic_owned, public.nx_cosmetic_equipped from anon, authenticated;
revoke insert, delete on public.nx_cosmetics from anon, authenticated;

-- Seed: the same ids and prices as lib/core/economy/carrom_cosmetics.dart (kCarromCosmetics). Free items are priced 0.
insert into public.nx_cosmetics(item_id, game, kind, name, name_fa, price_coins, sort) values
  ('carrom_board:classic_black', 'carrom', 'board', 'Classic Black & Gold', 'کلاسیک مشکی طلایی', 0, 0),
  ('carrom_board:wood', 'carrom', 'board', 'Wood', 'چوبی', 0, 1),
  ('carrom_board:green', 'carrom', 'board', 'Black & green', 'مشکی سبز', 0, 2),
  ('carrom_board:silver', 'carrom', 'board', 'Silver', 'نقره‌ای', 0, 3),
  ('carrom_board:black_gold', 'carrom', 'board', 'Black & gold', 'مشکی طلایی', 0, 4),
  ('carrom_board:classic_navy', 'carrom', 'board', 'Classic Navy & Gold', 'کلاسیک سرمه‌ای طلایی', 800, 10),
  ('carrom_board:neon_blue', 'carrom', 'board', 'Neon Blue', 'نئون آبی', 1500, 11),
  ('carrom_board:neon_magenta', 'carrom', 'board', 'Neon Magenta', 'نئون سرخابی', 2500, 12),
  ('carrom_board:neon_emerald', 'carrom', 'board', 'Neon Emerald', 'نئون زمردی', 3000, 13),
  ('carrom_board:neon_gold', 'carrom', 'board', 'Neon Gold', 'نئون طلایی', 5000, 14),
  ('carrom_pieces:ring', 'carrom', 'pieces', 'Green ring', 'حلقه‌ی سبز', 0, 0),
  ('carrom_pieces:star', 'carrom', 'pieces', 'Star', 'ستاره', 0, 1),
  ('carrom_pieces:carved', 'carrom', 'pieces', 'Carved', 'کنده‌کاری', 0, 2),
  ('carrom_pieces:hex', 'carrom', 'pieces', 'Hex', 'شش‌ضلعی', 0, 3),
  ('carrom_pieces:carbon', 'carrom', 'pieces', 'Carbon', 'کربن', 0, 4),
  ('carrom_pieces:minimal', 'carrom', 'pieces', 'Minimal', 'مینیمال', 0, 5),
  ('carrom_pieces:neon_star', 'carrom', 'pieces', 'Neon Star', 'ستاره‌ی نئون', 500, 10),
  ('carrom_pieces:frost_night', 'carrom', 'pieces', 'Frost & Night', 'یخ و شب', 800, 11),
  ('carrom_pieces:gem_duel', 'carrom', 'pieces', 'Gem Duel', 'دوئل جواهر', 1200, 12),
  ('carrom_pieces:classic_chips', 'carrom', 'pieces', 'Classic Chips', 'ژتون کلاسیک', 1500, 13),
  ('carrom_pieces:casino_suits', 'carrom', 'pieces', 'Card Suits', 'خال‌های ورق', 2000, 14),
  ('carrom_pieces:crown_royale', 'carrom', 'pieces', 'Crown Royale', 'تاج سلطنتی', 2500, 15),
  ('carrom_pieces:elements', 'carrom', 'pieces', 'Elements', 'عناصر', 3500, 16),
  ('carrom_pieces:beasts', 'carrom', 'pieces', 'Beasts', 'جانوران', 4000, 17),
  ('carrom_pieces:car_club', 'carrom', 'pieces', 'Car Club', 'باشگاه خودرو', 5000, 18)
on conflict (item_id) do nothing;

-- ------------------------------------------------------------------------------------------------------------ RPCs
create or replace function public.buy_cosmetic(p_item text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); it nx_cosmetics; bal integer;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into it from nx_cosmetics where item_id = p_item;
  if it.item_id is null or not it.active then
    select coins into bal from profiles where id = me;
    return jsonb_build_object('ok', false, 'error', 'not_for_sale', 'coins', bal);
  end if;
  if not exists (select 1 from profiles where id = me) then
    return jsonb_build_object('ok', false, 'error', 'no_profile');  -- client calls nx_g_hello first
  end if;
  -- serialise purchases of this player
  perform 1 from profiles where id = me for update;
  if exists (select 1 from nx_cosmetic_owned where user_id = me and item_id = p_item) then
    select coins into bal from profiles where id = me;
    return jsonb_build_object('ok', true, 'owned', true, 'coins', bal, 'item', p_item);
  end if;
  if it.price_coins > 0 then
    perform set_config('nx.reason', left('cosmetic:' || p_item, 80), true);
    update profiles set coins = coins - it.price_coins
     where id = me and coins >= it.price_coins returning coins into bal;
    if bal is null then
      select coins into bal from profiles where id = me;
      return jsonb_build_object('ok', false, 'error', 'insufficient_coins', 'coins', bal, 'price', it.price_coins);
    end if;
  else
    select coins into bal from profiles where id = me;
  end if;
  insert into nx_cosmetic_owned(user_id, item_id, price_paid) values (me, p_item, it.price_coins)
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'coins', bal, 'price', it.price_coins, 'item', p_item);
end $$;

create or replace function public.equip_cosmetic(p_item text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); it nx_cosmetics;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into it from nx_cosmetics where item_id = p_item;
  if it.item_id is null then return jsonb_build_object('ok', false, 'error', 'unknown_item'); end if;
  if it.price_coins > 0 and not exists (select 1 from nx_cosmetic_owned where user_id = me and item_id = p_item) then
    return jsonb_build_object('ok', false, 'error', 'not_owned');
  end if;
  insert into nx_cosmetic_equipped(user_id, game, kind, item_id) values (me, it.game, it.kind, p_item)
  on conflict (user_id, game, kind) do update set item_id = excluded.item_id, updated_at = now();
  return jsonb_build_object('ok', true, 'item', p_item, 'game', it.game, 'kind', it.kind);
end $$;

create or replace function public.my_cosmetics() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ok', auth.uid() is not null,
    'owned', coalesce((select jsonb_agg(item_id order by acquired_at) from nx_cosmetic_owned where user_id = auth.uid()), '[]'::jsonb),
    'equipped', coalesce((select jsonb_object_agg(game || '.' || kind, item_id) from nx_cosmetic_equipped where user_id = auth.uid()), '{}'::jsonb),
    'coins', (select coins from profiles where id = auth.uid()))
$$;

revoke all on function public.buy_cosmetic(text), public.equip_cosmetic(text), public.my_cosmetics() from public, anon;
grant execute on function public.buy_cosmetic(text), public.equip_cosmetic(text), public.my_cosmetics() to authenticated;
