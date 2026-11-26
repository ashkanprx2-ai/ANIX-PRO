-- Finger soccer physics contract v14 (2026-11-25, owner request): the BALL is 2% bigger and rolls ~20% shorter.
--
-- nx_physics_contracts is an audit record only (clients simulate locally, nothing reads it at runtime), but it must
-- match the engine that ships. Values are transcribed from lib/games/finger_soccer/core/bm_engine.dart:
--   * BR (ball radius, world units) 25 -> 25.5 (x1.02). Disc radius PR 53 unchanged.
--   * ball rolling friction law  f = F0 * K * min(1, v / (ramp * K)) + drag * v :
--       F0 (kBmBallF0) 150 -> 187.5, drag (kBmBallDrag) 1.4 -> 1.75 (both x1.25 = an exact time-scaling: from the same
--       launch the ball comes to rest in 80% of the time, ~2.4 s -> ~1.9 s from a hard strike). ramp 40 unchanged.
--     The previous row still carried the 2026-11-20 values (ball_friction 23, ball_drag 1.08); v12 (150 / 1.4 / ramp 40)
--     was never recorded here, so both are corrected now.
--   * ball_mass 2.95 / player_mass 8.6 (v13) were not recorded either; written for completeness.
-- Disc physics, launch scale and every other key are untouched. Idempotent.
update public.nx_physics_contracts
set version = 'physics-2026-11-25-fs-v14-ball',
    contract = contract || '{
      "BR": 25.5,
      "ball_friction": 187.5,
      "ball_drag": 1.75,
      "ball_friction_ramp": 40,
      "ball_mass": 2.95,
      "player_mass": 8.6,
      "ball_history": "BR 25 -> 25.5 (v14 x1.02); ball_friction/drag 23/1.08 (v3) -> 150/1.4 ramp 40 (v12, half roll) -> 187.5/1.75 (v14, roll time x0.8)"
    }'::jsonb,
    updated_at = now()
where game = 'finger_soccer';
