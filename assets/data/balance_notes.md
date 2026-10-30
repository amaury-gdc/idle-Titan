# Balance notes (story 003)

Measured with `tools/simulate_progress.gd`, on the real `Combat`, `FloorManager`
and `CompanionManager`. All values are provisional. Bosses do not exist yet (story
004), so "first boss" means reaching stage 10, and boss timers will slow these
numbers down.

Re-run:

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=24

## Player model

- 3 clicks per second, without any pause, for the whole run (generous for hours).
- After every 0.1 s step, buys the cheapest affordable next level, repeatedly,
  until nothing is affordable. Not an optimal policy: it never saves up for a
  better companion, and a real player may do better or worse.

## Measured against the brief's hypotheses

| Target (brief) | Measured (3 clicks/s) | Gap |
|---|---|---|
| First boss (stage 10) in 2 to 3 min | 2.5 min (147.8 s) | Within target |
| Stage 50 in about 1 h | 56.1 min | 4 min early (-6.5%) |
| Clear wall between stages 100 and 150 | Stage 100 at 10.3 h, stage 117 at 24 h, stage 150 not reached | Wall is in range but soft: progress slows down steadily, there is no sharp stop |

Stage reached at 3 h: 71.

Sensitivity to the click rate:

| Clicks/s | Stage 10 | Stage 50 | Stage at 3 h |
|---|---|---|---|
| 1 | 4.6 min | 68.3 min | 68 |
| 3 | 2.5 min | 56.1 min | 71 |
| 6 | 1.6 min | 45.0 min | 73 |

The stage 10 target only holds around 3 clicks/s: at 1 click/s it is missed by
1.6 min, at 6 clicks/s by 0.4 min. A real click rate should be measured in playtest.

## What was tuned (data only)

- `core_curves.json`: `cost_growth` 1.1 to 1.08, `enemy_hp_base` 15 to 22,
  `enemy_hp_growth` 1.3 to 1.33, `gold_per_kill_growth` 1.25 to 1.28.
- `companions_roster.json`: costs about x30 per companion, damage about x39, so each
  new companion is a better deal at level 1 than the previous one and renews growth.
  Same `cost_growth` and same tiers for all 8 (levels 10, 25, 50: x2; 100, 150, 200: x3).

## Known limits

- In the variants tried, reaching stage 50 in about 1 h and stage 100 within a few
  hours pulled against each other; stage 50 was given priority. None of them gave
  a sharp wall. A sharper wall may need a design decision (for example level caps).
- Stage 100 at 10 h is long compared with the "short sessions" of the brief, so
  testers may stop before the wall. To be reviewed once bosses, talents and items
  (stories 004, 006, 007) change the curve.
- With this buy policy the last companions come very late: the alchemist and the
  dragon are still not bought at 3 h, and at 24 h the dragon is only level 5.
