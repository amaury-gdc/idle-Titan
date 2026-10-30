# Balance notes (stories 003, 004)

Measured with `tools/simulate_progress.gd`, on the real `Combat`, `FloorManager`
and `CompanionManager` (and `BossFight` since story 004). All values are provisional.
The sections below the "Bosses" one are the story 003 measurements, taken WITHOUT
bosses and with `enemy_hp_growth` 1.33, where "first boss" meant reaching stage 10.
The numbers that apply to the game today are in "Bosses".

Re-run:

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=24

## Bosses (story 004)

Formula: boss HP at stage S = floor(enemy HP of stage S * `boss_hp_multiplier`).
Values in the files: `boss_every_stages` 10, `timer_seconds` 30, `boss_hp_multiplier`
"20", `boss_gold_base` "15", `boss_gold_growth` "1.30", `auto_challenge_margin` "1.2".
Only one other value moved:
`enemy_hp_growth` 1.33 to 1.325 in `core_curves.json`. The roster is untouched. Retry
rule: farm mode and challenge (see `data_schema.md`). "Reached" means the fight of that
stage began.

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=72
    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=72 --auto=1

Two player models, both with the clicks and purchases of "Player model" below:

Both models use the same test, `FloorManager.can_beat_next_boss`: (click dps + total
power) * timer_seconds >= boss HP * `auto_challenge_margin`, with click dps = cps *
click damage in the simulator (measured over the last clicks in the game).

- Default: in farm mode, the player presses the button as soon as the test passes,
  checked once per simulated second.
- `--auto=1`: "Défi automatique" on; a farm kill starts the boss when the test passes.

| Target (brief) | Default model (3 clicks/s, 72 h run) | Gap |
|---|---|---|
| First boss reached in 2 to 3 min | 2.4 min (145.8 s) | Within target |
| First boss killed (stage 11) | 9.5 min, 1 failed attempt | No target in the brief |
| Stage 50 in about 1 h | 55.2 min, 4 failed attempts | 4.8 min early (-8%) |
| Net wall between stages 100 and 150 | Stage 100 at 8.6 h, 110 at 11.8 h, stage 110 boss still not challenged again at 72 h | In range and net: more than 60 h on the stage 110 boss |

Stage at 3 h: 70. Failed attempts: 11 in 72 h, because this model only comes back
when it expects to win, and each new boss it meets unprepared costs one attempt.

`--auto=1` at 3 clicks/s gives the same run within a few seconds: first boss killed
at 9.6 min, stage 50 at 55.2 min, 11 failed attempts.

The margin is needed. The estimate is optimistic because attacks land on whole
intervals. Without a margin, the same runs gave 26 failed attempts at 3 clicks/s, and
887 at 1 click/s, of which 865 between stages 100 and 110: a narrow estimate fails,
the estimate does not change, and the boss is challenged again. An auto challenge
with no test at all gave 7839 failed attempts and best stage 90 at 72 h.

Sensitivity to the click rate (`--auto=1`, 24 h runs):

| Clicks/s | First boss reached | First boss killed | Stage 50 | Stage 100 | Stage 110 | Failed |
|---|---|---|---|---|---|---|
| 1 | 4.6 min | 14.6 min | 67.6 min | 10.1 h | 15.8 h | 11 |
| 6 | 1.5 min | 5.9 min | 44.3 min | 6.7 h | 8.7 h | 11 |

What the tries showed (default model, 3 clicks/s, before the margin existed; farm
mode already makes progress much faster than the first rule, so `enemy_hp_growth`
could only go down a little):

| Multiplier / `enemy_hp_growth` | First boss killed | Stage 50 | Stage 100 | Wall seen |
|---|---|---|---|---|
| "6" / "1.32" | 5.7 min | 39.4 min | 5.2 h | 6 h run |
| "6" / "1.33" | 6.2 min | 48.3 min | not at 6 h | 6 h run |
| "10" / "1.325" | 6.5 min | 48.9 min | not at 6 h | 6 h run |
| "15" / "1.32" | 6.6 min | 48.7 min | not at 6 h | 6 h run |
| "30" / "1.32" | 9.9 min | 50.3 min | 6.6 h | 120 at 47.7 h |
| "15" / "1.33" | 7.1 min | 61.3 min | 10.9 h | 110 at 14.7 h, no 120 at 48 h |
| "25" / "1.33" | 10.4 min | 60.6 min | 10.9 h | 110 at 17.0 h, no 120 at 48 h |
| "20" / "1.325" (kept) | 8.1 min | 55.7 min | 8.5 h | 110 at 10.9 h, 120 at 66.8 h |

Where the wall comes from: farming a fixed stage gives a fixed income, while companion
costs grow exponentially, so power only grows slowly while farming. Stages 100 to 110
pass quickly because the farm before each boss also buys the stages after it. Around
stage 110 the boss needs 20 times an enemy HP within 30 s, and farm income can no
longer buy that power in reasonable time. The enemy curve sets the wall; the
multiplier decides how much farm each boss asks for, and only a little where the wall is.

Limits:

- The first boss cannot be beaten on arrival: in the default model it needs one failed
  attempt, then about 7 minutes of farm. It is still killable early, but a new
  player must understand farm mode and the button to get past it. A short message
  explains it at the first failed boss.
- The pace is uneven: 3.3 h between stages 100 and 110 is followed by more than 60 h
  for the next boss. The wall is clearly net, but such a stop may feel like a dead end
  rather than a goal; it needs a playtest.
- A real player pressing the button earlier than the test allows can pass a boss the
  models still wait on: the margin makes both models slightly cautious.
- The default model is informed: it computes what a real player can only feel. A real
  player will fail more attempts.
- The wall is measured with no prestige, talents, items or skills (stories 005 to 007);
  they will move it.
- The model clicks non-stop for days, and it never saves up for a better companion.

## Player model

- 3 clicks per second, without any pause, for the whole run (generous for hours).
- After every 0.1 s step, buys the cheapest affordable next level, repeatedly,
  until nothing is affordable. Not an optimal policy: it never saves up for a
  better companion, and a real player may do better or worse.

## Measured against the brief's hypotheses (without bosses)

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
