-- Finger soccer: the owner's NX pucks are the only teams (owner request 2026-11-26). Auth/core project
-- (eisstodgncimypdawisy). Client: lib/games/finger_soccer/core/bm_data.dart kBmTeamDefs, generated with this catalogue
-- from docs/fs_teams_map.py by tool/gen_fs_pucks.py.
--
-- 1. nx_catalog: one gem row per NX puck (77). Prices = gem_shop.dart defaultTeamPrice (free wolf / shark / eagle 0,
--    otherwise 150..500 by power + accuracy). team_kind: club / nation / brand / car / fantasy.
-- 2. Every other fs_team:* row (the retired v9..v14 crest teams) is copied to nx_catalog_backup_fs_pucks_v1 and deleted.
--    Shared custom teams (fs_team:cx_*) and the fs_custom_team entitlement are untouched.
-- 3. Inventories (nx_profiles.data.inv): every retired team is removed. Compensation per retired team the player owned:
--    * it has an NX puck equivalent (same club / nation / brand / car, or the same fantasy creature: e.g. club1
--      Mercedes-Benz -> mercedes, elite_realmadrid -> realmadrid, brazil_ii -> brazil, nx_dragon -> fx_dragon) that the
--      player does not own yet -> that puck is granted (no gems move);
--    * otherwise (no equivalent, or the equivalent is already owned / granted for another retired team) -> the gems the
--      player actually paid for it (nx_gem_tx purchase rows) are refunded through nx_wallet_apply
--      (reason 'refund:fs_pucks_v1', idem fs_pucks_v1:<user>:<item>, ledgered) plus an nx_gem_tx 'refund' row.
--      Teams that were never paid for (free starters, grants) are removed without a refund.
--    Every decision is logged in nx_fs_pucks_v1_migration (user, old item, action, new item, gems) for support.
-- Idempotent: re-running grants / refunds nothing twice (idem keys, inventory checks).
begin;

-- 1. the NX puck catalogue
insert into public.nx_catalog(item_id, price, currency, kind, name, team_kind, active) values
  ('fs_team:realmadrid', 500, 'gems', 'team', 'Real Madrid', 'club', true),
  ('fs_team:barcelona', 470, 'gems', 'team', 'Barcelona', 'club', true),
  ('fs_team:bayern', 470, 'gems', 'team', 'Bayern München', 'club', true),
  ('fs_team:psg', 470, 'gems', 'team', 'Paris Saint-Germain', 'club', true),
  ('fs_team:mancity', 470, 'gems', 'team', 'Manchester City', 'club', true),
  ('fs_team:liverpool', 440, 'gems', 'team', 'Liverpool', 'club', true),
  ('fs_team:acmilan', 400, 'gems', 'team', 'AC Milan', 'club', true),
  ('fs_team:juventus', 400, 'gems', 'team', 'Juventus', 'club', true),
  ('fs_team:inter', 400, 'gems', 'team', 'Inter', 'club', true),
  ('fs_team:chelsea', 400, 'gems', 'team', 'Chelsea', 'club', true),
  ('fs_team:arsenal', 400, 'gems', 'team', 'Arsenal', 'club', true),
  ('fs_team:atletico', 440, 'gems', 'team', 'Atlético Madrid', 'club', true),
  ('fs_team:dortmund', 400, 'gems', 'team', 'Borussia Dortmund', 'club', true),
  ('fs_team:persepolis', 400, 'gems', 'team', 'Persepolis', 'club', true),
  ('fs_team:esteghlal', 400, 'gems', 'team', 'Esteghlal', 'club', true),
  ('fs_team:intermiami', 440, 'gems', 'team', 'Inter Miami', 'club', true),
  ('fs_team:alhilal', 400, 'gems', 'team', 'Al Hilal', 'club', true),
  ('fs_team:astonvilla', 370, 'gems', 'team', 'Aston Villa', 'club', true),
  ('fs_team:wolves', 340, 'gems', 'team', 'Wolverhampton', 'club', true),
  ('fs_team:schalke', 340, 'gems', 'team', 'Schalke 04', 'club', true),
  ('fs_team:sevilla', 370, 'gems', 'team', 'Sevilla', 'club', true),
  ('fs_team:lazio', 370, 'gems', 'team', 'Lazio', 'club', true),
  ('fs_team:argentina', 500, 'gems', 'team', 'Argentina', 'nation', true),
  ('fs_team:brazil', 470, 'gems', 'team', 'Brazil', 'nation', true),
  ('fs_team:france', 440, 'gems', 'team', 'France', 'nation', true),
  ('fs_team:germany', 440, 'gems', 'team', 'Germany', 'nation', true),
  ('fs_team:spain', 440, 'gems', 'team', 'Spain', 'nation', true),
  ('fs_team:portugal', 400, 'gems', 'team', 'Portugal', 'nation', true),
  ('fs_team:england', 400, 'gems', 'team', 'England', 'nation', true),
  ('fs_team:netherlands', 400, 'gems', 'team', 'Netherlands', 'nation', true),
  ('fs_team:italy', 400, 'gems', 'team', 'Italy', 'nation', true),
  ('fs_team:iran', 440, 'gems', 'team', 'Iran', 'nation', true),
  ('fs_team:uruguay', 370, 'gems', 'team', 'Uruguay', 'nation', true),
  ('fs_team:japan', 340, 'gems', 'team', 'Japan', 'nation', true),
  ('fs_team:usa', 370, 'gems', 'team', 'USA', 'nation', true),
  ('fs_team:canada', 340, 'gems', 'team', 'Canada', 'nation', true),
  ('fs_team:norway', 340, 'gems', 'team', 'Norway', 'nation', true),
  ('fs_team:finland', 310, 'gems', 'team', 'Finland', 'nation', true),
  ('fs_team:greece', 340, 'gems', 'team', 'Greece', 'nation', true),
  ('fs_team:wales', 310, 'gems', 'team', 'Wales', 'nation', true),
  ('fs_team:algeria', 310, 'gems', 'team', 'Algeria', 'nation', true),
  ('fs_team:cuba', 280, 'gems', 'team', 'Cuba', 'nation', true),
  ('fs_team:qatar', 310, 'gems', 'team', 'Qatar', 'nation', true),
  ('fs_team:adidas', 440, 'gems', 'team', 'Adidas', 'brand', true),
  ('fs_team:nike', 440, 'gems', 'team', 'Nike', 'brand', true),
  ('fs_team:jordan', 440, 'gems', 'team', 'Jordan', 'brand', true),
  ('fs_team:newbalance', 400, 'gems', 'team', 'New Balance', 'brand', true),
  ('fs_team:reebok', 370, 'gems', 'team', 'Reebok', 'brand', true),
  ('fs_team:puma', 400, 'gems', 'team', 'Puma', 'brand', true),
  ('fs_team:starbucks', 370, 'gems', 'team', 'Starbucks', 'brand', true),
  ('fs_team:apple', 470, 'gems', 'team', 'Apple', 'brand', true),
  ('fs_team:louisvuitton', 500, 'gems', 'team', 'Louis Vuitton', 'brand', true),
  ('fs_team:dior', 470, 'gems', 'team', 'Dior', 'brand', true),
  ('fs_team:rolex', 500, 'gems', 'team', 'Rolex', 'brand', true),
  ('fs_team:chanel', 470, 'gems', 'team', 'Chanel', 'brand', true),
  ('fs_team:gucci', 470, 'gems', 'team', 'Gucci', 'brand', true),
  ('fs_team:bmw', 440, 'gems', 'team', 'BMW', 'car', true),
  ('fs_team:mercedes', 470, 'gems', 'team', 'Mercedes-Benz', 'car', true),
  ('fs_team:porsche', 470, 'gems', 'team', 'Porsche', 'car', true),
  ('fs_team:lamborghini', 500, 'gems', 'team', 'Lamborghini', 'car', true),
  ('fs_team:tesla', 470, 'gems', 'team', 'Tesla', 'car', true),
  ('fs_team:volkswagen', 370, 'gems', 'team', 'Volkswagen', 'car', true),
  ('fs_team:volvo', 400, 'gems', 'team', 'Volvo', 'car', true),
  ('fs_team:hyundai', 370, 'gems', 'team', 'Hyundai', 'car', true),
  ('fs_team:scania', 370, 'gems', 'team', 'Scania', 'car', true),
  ('fs_team:fx_wolf', 0, 'gems', 'team', 'Wolf', 'fantasy', true),
  ('fs_team:fx_shark', 0, 'gems', 'team', 'Shark', 'fantasy', true),
  ('fs_team:fx_eagle', 0, 'gems', 'team', 'Eagle', 'fantasy', true),
  ('fs_team:fx_dragon', 470, 'gems', 'team', 'Dragon', 'fantasy', true),
  ('fs_team:fx_samurai', 470, 'gems', 'team', 'Samurai', 'fantasy', true),
  ('fs_team:fx_crown', 500, 'gems', 'team', 'Crown', 'fantasy', true),
  ('fs_team:fx_phoenix', 470, 'gems', 'team', 'Phoenix', 'fantasy', true),
  ('fs_team:fx_shuriken', 440, 'gems', 'team', 'Shuriken', 'fantasy', true),
  ('fs_team:fx_panther', 440, 'gems', 'team', 'Panther', 'fantasy', true),
  ('fs_team:fx_lion', 470, 'gems', 'team', 'Lion', 'fantasy', true),
  ('fs_team:fx_scorpion', 400, 'gems', 'team', 'Scorpion', 'fantasy', true),
  ('fs_team:fx_spartan', 470, 'gems', 'team', 'Spartan', 'fantasy', true)
on conflict (item_id) do update
  set price = excluded.price, currency = 'gems', kind = 'team', name = excluded.name, team_kind = excluded.team_kind,
      active = true, updated_at = now();

-- 2. retire every other built-in team row (backup first)
create table if not exists public.nx_catalog_backup_fs_pucks_v1 as
  select * from public.nx_catalog where false;
alter table public.nx_catalog_backup_fs_pucks_v1 enable row level security;
revoke all on public.nx_catalog_backup_fs_pucks_v1 from anon, authenticated;
insert into public.nx_catalog_backup_fs_pucks_v1
  select c.* from public.nx_catalog c
   where c.item_id like 'fs\_team:%' and c.item_id not like 'fs\_team:cx\_%'
     and c.item_id not in ('fs_team:realmadrid', 'fs_team:barcelona', 'fs_team:bayern', 'fs_team:psg', 'fs_team:mancity', 'fs_team:liverpool', 'fs_team:acmilan', 'fs_team:juventus', 'fs_team:inter', 'fs_team:chelsea', 'fs_team:arsenal', 'fs_team:atletico', 'fs_team:dortmund', 'fs_team:persepolis', 'fs_team:esteghlal', 'fs_team:intermiami', 'fs_team:alhilal', 'fs_team:astonvilla', 'fs_team:wolves', 'fs_team:schalke', 'fs_team:sevilla', 'fs_team:lazio', 'fs_team:argentina', 'fs_team:brazil', 'fs_team:france', 'fs_team:germany', 'fs_team:spain', 'fs_team:portugal', 'fs_team:england', 'fs_team:netherlands', 'fs_team:italy', 'fs_team:iran', 'fs_team:uruguay', 'fs_team:japan', 'fs_team:usa', 'fs_team:canada', 'fs_team:norway', 'fs_team:finland', 'fs_team:greece', 'fs_team:wales', 'fs_team:algeria', 'fs_team:cuba', 'fs_team:qatar', 'fs_team:adidas', 'fs_team:nike', 'fs_team:jordan', 'fs_team:newbalance', 'fs_team:reebok', 'fs_team:puma', 'fs_team:starbucks', 'fs_team:apple', 'fs_team:louisvuitton', 'fs_team:dior', 'fs_team:rolex', 'fs_team:chanel', 'fs_team:gucci', 'fs_team:bmw', 'fs_team:mercedes', 'fs_team:porsche', 'fs_team:lamborghini', 'fs_team:tesla', 'fs_team:volkswagen', 'fs_team:volvo', 'fs_team:hyundai', 'fs_team:scania', 'fs_team:fx_wolf', 'fs_team:fx_shark', 'fs_team:fx_eagle', 'fs_team:fx_dragon', 'fs_team:fx_samurai', 'fs_team:fx_crown', 'fs_team:fx_phoenix', 'fs_team:fx_shuriken', 'fs_team:fx_panther', 'fs_team:fx_lion', 'fs_team:fx_scorpion', 'fs_team:fx_spartan')
     and not exists (select 1 from public.nx_catalog_backup_fs_pucks_v1 b where b.item_id = c.item_id);

-- 3. inventories
create table if not exists public.nx_fs_pucks_v1_migration (
  user_id uuid not null,
  old_item text not null,
  action text not null,          -- granted | refunded | removed
  new_item text,
  gems integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, old_item)
);
alter table public.nx_fs_pucks_v1_migration enable row level security;
revoke all on public.nx_fs_pucks_v1_migration from anon, authenticated;

create temp table _fs_new(item text primary key) on commit drop;
insert into _fs_new select unnest(array['fs_team:realmadrid', 'fs_team:barcelona', 'fs_team:bayern', 'fs_team:psg', 'fs_team:mancity', 'fs_team:liverpool', 'fs_team:acmilan', 'fs_team:juventus', 'fs_team:inter', 'fs_team:chelsea', 'fs_team:arsenal', 'fs_team:atletico', 'fs_team:dortmund', 'fs_team:persepolis', 'fs_team:esteghlal', 'fs_team:intermiami', 'fs_team:alhilal', 'fs_team:astonvilla', 'fs_team:wolves', 'fs_team:schalke', 'fs_team:sevilla', 'fs_team:lazio', 'fs_team:argentina', 'fs_team:brazil', 'fs_team:france', 'fs_team:germany', 'fs_team:spain', 'fs_team:portugal', 'fs_team:england', 'fs_team:netherlands', 'fs_team:italy', 'fs_team:iran', 'fs_team:uruguay', 'fs_team:japan', 'fs_team:usa', 'fs_team:canada', 'fs_team:norway', 'fs_team:finland', 'fs_team:greece', 'fs_team:wales', 'fs_team:algeria', 'fs_team:cuba', 'fs_team:qatar', 'fs_team:adidas', 'fs_team:nike', 'fs_team:jordan', 'fs_team:newbalance', 'fs_team:reebok', 'fs_team:puma', 'fs_team:starbucks', 'fs_team:apple', 'fs_team:louisvuitton', 'fs_team:dior', 'fs_team:rolex', 'fs_team:chanel', 'fs_team:gucci', 'fs_team:bmw', 'fs_team:mercedes', 'fs_team:porsche', 'fs_team:lamborghini', 'fs_team:tesla', 'fs_team:volkswagen', 'fs_team:volvo', 'fs_team:hyundai', 'fs_team:scania', 'fs_team:fx_wolf', 'fs_team:fx_shark', 'fs_team:fx_eagle', 'fs_team:fx_dragon', 'fs_team:fx_samurai', 'fs_team:fx_crown', 'fs_team:fx_phoenix', 'fs_team:fx_shuriken', 'fs_team:fx_panther', 'fs_team:fx_lion', 'fs_team:fx_scorpion', 'fs_team:fx_spartan']);
create temp table _fs_map(old_id text primary key, new_id text not null) on commit drop;
insert into _fs_map values
  ('argentina_ii', 'argentina'),
  ('barca_gold', 'barcelona'),
  ('brazil_ii', 'brazil'),
  ('car0', 'lamborghini'),
  ('car13', 'tesla'),
  ('car3', 'mercedes'),
  ('car4', 'bmw'),
  ('car5', 'porsche'),
  ('car_volvo', 'volvo'),
  ('club0', 'bmw'),
  ('club1', 'mercedes'),
  ('club12', 'bmw'),
  ('club13', 'mercedes'),
  ('club17', 'porsche'),
  ('club20', 'volkswagen'),
  ('club21', 'lamborghini'),
  ('club24', 'nike'),
  ('club25', 'adidas'),
  ('club26', 'puma'),
  ('club28', 'reebok'),
  ('club29', 'newbalance'),
  ('club30', 'nike'),
  ('club31', 'adidas'),
  ('club32', 'persepolis'),
  ('club33', 'esteghlal'),
  ('club34', 'intermiami'),
  ('club5', 'porsche'),
  ('club8', 'volkswagen'),
  ('club9', 'lamborghini'),
  ('club_lazio', 'lazio'),
  ('elite_barcelona', 'barcelona'),
  ('elite_bayern', 'bayern'),
  ('elite_chelsea', 'chelsea'),
  ('elite_dortmund', 'dortmund'),
  ('elite_psg', 'psg'),
  ('elite_realmadrid', 'realmadrid'),
  ('france_ii', 'france'),
  ('germany_ii', 'germany'),
  ('italy_ii', 'italy'),
  ('lux0', 'louisvuitton'),
  ('lux1', 'chanel'),
  ('lux2', 'gucci'),
  ('lux5', 'dior'),
  ('lux7', 'rolex'),
  ('nat0', 'argentina'),
  ('nat1', 'brazil'),
  ('nat10', 'uruguay'),
  ('nat17', 'usa'),
  ('nat18', 'japan'),
  ('nat2', 'france'),
  ('nat20', 'puma'),
  ('nat22', 'newbalance'),
  ('nat23', 'reebok'),
  ('nat26', 'iran'),
  ('nat27', 'qatar'),
  ('nat3', 'germany'),
  ('nat4', 'portugal'),
  ('nat5', 'spain'),
  ('nat6', 'italy'),
  ('nat7', 'england'),
  ('nat8', 'netherlands'),
  ('nat_algeria', 'algeria'),
  ('nx_dragon', 'fx_dragon'),
  ('nx_dragon2', 'fx_dragon'),
  ('nx_eagle', 'fx_eagle'),
  ('nx_eagle2', 'fx_eagle'),
  ('nx_lion', 'fx_lion'),
  ('nx_lion2', 'fx_lion'),
  ('nx_phoenix', 'fx_phoenix'),
  ('nx_phoenix2', 'fx_phoenix'),
  ('nxcar_bmw', 'bmw'),
  ('nxcar_lamborghini', 'lamborghini'),
  ('nxcar_mercedes', 'mercedes'),
  ('nxcar_porsche', 'porsche'),
  ('nxcar_tesla', 'tesla'),
  ('spain_ii', 'spain'),
  ('spt0', 'nike'),
  ('spt1', 'adidas'),
  ('spt2', 'puma'),
  ('spt4', 'newbalance'),
  ('spt5', 'reebok'),
  ('spt6', 'jordan');

do $$
declare
  u record; it text; oid text; nid text; inv jsonb; keep jsonb; paid int; res jsonb; bal int;
begin
  for u in select id, coalesce(data -> 'inv', '[]'::jsonb) as inv from public.nx_profiles
            where exists (select 1 from jsonb_array_elements_text(coalesce(data -> 'inv', '[]'::jsonb)) e(v)
                           where e.v like 'fs\_team:%' and e.v not like 'fs\_team:cx\_%'
                             and not exists (select 1 from _fs_new n where n.item = e.v))
            for update
  loop
    inv := u.inv;
    keep := '[]'::jsonb;
    -- keep everything that is not a retired team
    for it in select v from jsonb_array_elements_text(inv) e(v) loop
      if it like 'fs\_team:%' and it not like 'fs\_team:cx\_%'
         and not exists (select 1 from _fs_new n where n.item = it) then
        continue;
      end if;
      if not keep ? it then keep := keep || to_jsonb(it); end if;
    end loop;
    -- compensate every retired team (in inventory order)
    for it in select v from jsonb_array_elements_text(inv) e(v) loop
      continue when not (it like 'fs\_team:%' and it not like 'fs\_team:cx\_%');
      continue when exists (select 1 from _fs_new n where n.item = it);
      continue when exists (select 1 from public.nx_fs_pucks_v1_migration m where m.user_id = u.id and m.old_item = it);
      oid := substr(it, 9);
      select 'fs_team:' || new_id into nid from _fs_map where old_id = oid;
      if nid is not null and not keep ? nid then
        keep := keep || to_jsonb(nid);
        insert into public.nx_fs_pucks_v1_migration(user_id, old_item, action, new_item) values (u.id, it, 'granted', nid);
        continue;
      end if;
      select coalesce(sum(-delta), 0) into paid from public.nx_gem_tx
       where user_id = u.id and item = it and reason = 'purchase' and delta < 0;
      if paid > 0 then
        res := public.nx_wallet_apply(u.id, 0, paid, 'refund:fs_pucks_v1', it, 'fs_pucks_v1:' || u.id || ':' || it, 'strict');
        bal := (res ->> 'gems')::int;
        if coalesce((res ->> 'dup')::boolean, false) is false then
          insert into public.nx_gem_tx(user_id, delta, balance, reason, item) values (u.id, paid, bal, 'refund', it);
        end if;
        insert into public.nx_fs_pucks_v1_migration(user_id, old_item, action, new_item, gems)
          values (u.id, it, 'refunded', nid, paid);
      else
        insert into public.nx_fs_pucks_v1_migration(user_id, old_item, action) values (u.id, it, 'removed');
      end if;
    end loop;
    update public.nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', keep), updated_at = now()
     where id = u.id;
  end loop;
end $$;

delete from public.nx_catalog c
 where c.item_id like 'fs\_team:%' and c.item_id not like 'fs\_team:cx\_%'
   and c.item_id not in ('fs_team:realmadrid', 'fs_team:barcelona', 'fs_team:bayern', 'fs_team:psg', 'fs_team:mancity', 'fs_team:liverpool', 'fs_team:acmilan', 'fs_team:juventus', 'fs_team:inter', 'fs_team:chelsea', 'fs_team:arsenal', 'fs_team:atletico', 'fs_team:dortmund', 'fs_team:persepolis', 'fs_team:esteghlal', 'fs_team:intermiami', 'fs_team:alhilal', 'fs_team:astonvilla', 'fs_team:wolves', 'fs_team:schalke', 'fs_team:sevilla', 'fs_team:lazio', 'fs_team:argentina', 'fs_team:brazil', 'fs_team:france', 'fs_team:germany', 'fs_team:spain', 'fs_team:portugal', 'fs_team:england', 'fs_team:netherlands', 'fs_team:italy', 'fs_team:iran', 'fs_team:uruguay', 'fs_team:japan', 'fs_team:usa', 'fs_team:canada', 'fs_team:norway', 'fs_team:finland', 'fs_team:greece', 'fs_team:wales', 'fs_team:algeria', 'fs_team:cuba', 'fs_team:qatar', 'fs_team:adidas', 'fs_team:nike', 'fs_team:jordan', 'fs_team:newbalance', 'fs_team:reebok', 'fs_team:puma', 'fs_team:starbucks', 'fs_team:apple', 'fs_team:louisvuitton', 'fs_team:dior', 'fs_team:rolex', 'fs_team:chanel', 'fs_team:gucci', 'fs_team:bmw', 'fs_team:mercedes', 'fs_team:porsche', 'fs_team:lamborghini', 'fs_team:tesla', 'fs_team:volkswagen', 'fs_team:volvo', 'fs_team:hyundai', 'fs_team:scania', 'fs_team:fx_wolf', 'fs_team:fx_shark', 'fs_team:fx_eagle', 'fs_team:fx_dragon', 'fs_team:fx_samurai', 'fs_team:fx_crown', 'fs_team:fx_phoenix', 'fs_team:fx_shuriken', 'fs_team:fx_panther', 'fs_team:fx_lion', 'fs_team:fx_scorpion', 'fs_team:fx_spartan');

commit;
