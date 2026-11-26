-- Finger soccer v14 (owner upload 2026-11-25): 16 new car-brand crest teams (lib/games/finger_soccer/core/bm_data.dart,
-- ids nxcar_*). Gem prices follow the client's defaultTeamPrice (150..500 by power + accuracy) so nx_buy_with_gems
-- sells them; without a catalog row the purchase answers not_for_sale. Auth project. Idempotent: an existing row keeps
-- its (admin-edited) price and is only re-activated.
begin;

insert into public.nx_catalog(item_id, price, currency, kind, name, team_kind, active) values
  ('fs_team:nxcar_mercedes', 440, 'gems', 'team', 'Mercedes-Benz Crest', 'car', true),
  ('fs_team:nxcar_bmw', 440, 'gems', 'team', 'BMW Crest', 'car', true),
  ('fs_team:nxcar_audi', 400, 'gems', 'team', 'Audi Crest', 'car', true),
  ('fs_team:nxcar_porsche', 470, 'gems', 'team', 'Porsche Crest', 'car', true),
  ('fs_team:nxcar_ferrari', 470, 'gems', 'team', 'Ferrari Crest', 'car', true),
  ('fs_team:nxcar_lamborghini', 440, 'gems', 'team', 'Lamborghini Crest', 'car', true),
  ('fs_team:nxcar_bentley_purple', 440, 'gems', 'team', 'Bentley Royal Purple', 'car', true),
  ('fs_team:nxcar_bentley_green', 440, 'gems', 'team', 'Bentley Racing Green', 'car', true),
  ('fs_team:nxcar_bugatti', 470, 'gems', 'team', 'Bugatti Crest', 'car', true),
  ('fs_team:nxcar_mclaren', 440, 'gems', 'team', 'McLaren Crest', 'car', true),
  ('fs_team:nxcar_astonmartin', 400, 'gems', 'team', 'Aston Martin Crest', 'car', true),
  ('fs_team:nxcar_tesla', 400, 'gems', 'team', 'Tesla Crest', 'car', true),
  ('fs_team:nxcar_toyota', 370, 'gems', 'team', 'Toyota Crest', 'car', true),
  ('fs_team:nxcar_nissan', 340, 'gems', 'team', 'Nissan Crest', 'car', true),
  ('fs_team:nxcar_ford', 340, 'gems', 'team', 'Ford Crest', 'car', true),
  ('fs_team:nxcar_chevrolet', 340, 'gems', 'team', 'Chevrolet Crest', 'car', true)
on conflict (item_id) do update set active = true, currency = 'gems', kind = 'team', team_kind = excluded.team_kind,
  name = excluded.name, updated_at = now();

commit;
