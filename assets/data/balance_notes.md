# Balance notes (stories 003, 004, 004b, 005)

Measured with `tools/simulate_progress.gd`, on the real `Combat`, `FloorManager`
and `CompanionManager` (and `BossFight` since story 004). All values are provisional.
The sections below the "Bosses" one are the story 003 measurements, taken WITHOUT
bosses and with `enemy_hp_growth` 1.33, where "first boss" meant reaching stage 10.
The numbers that apply to the game today are in "Bosses".

Re-run:

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=24

## Active skills (story 005)

Values in `skills.json` (formulas and rules in `data_schema.md`): "Gros coup" 6 s of
damage, cooldown 60 s; "Frénésie" damage x1.5 for 15 s, cooldown 90 s; "Bonus d'or" gold
x1.5 for 20 s, cooldown 120 s.

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=72 --auto=1 --away=0.5:8,3:8,6:12,24:8,36:8,48:12 --skills=1

3 clicks/s, `--auto=1`, 72 h of active play, six returns. Times are active play. The "No
skills" and "kept" rows were measured on the real `skills.json`, after the damage floor
of the buff (it adds at least 1 per hit). The other variants come from a copy of the data,
before that floor. Two skill models: `--skills=1` activates each
skill as soon as it is ready, for 72 h without a miss, which is an upper bound.
`--skills=2` keeps the burst and the damage buff for boss fights, and uses the gold bonus
when ready. Each variant is burst seconds / cooldown, damage factor / duration / cooldown,
gold factor / duration / cooldown.

| Variant | Model | First boss reached | First boss killed | Stage 50 | Stage 100 | Stage 110 | Best stage at 72 h | Failed |
|---|---|---|---|---|---|---|---|---|
| No skills | - | 2.4 min | 9.6 min | 43.4 min | 7.06 h | 10.34 h | 110 | 11 |
| 10/60, x2/15/90, x2/30/120 (first try) | 1 | 1.5 min | 6.2 min | 30.3 min | 5.32 h | 7.21 h | 120 (70 h) | 12 |
| same | 2 | 2.1 min | 7.5 min | 30.4 min | 6.01 h | 8.21 h | 110 | 11 |
| 6/60, x1.5/15/90, x1.5/20/120 (kept) | 1 | 1.9 min | 8.0 min | 34.7 min | 6.02 h | 8.61 h | 110 | 11 |
| same | 2 | 2.4 min | 8.8 min | 39.0 min | 6.45 h | 9.47 h | 110 | 11 |
| 5/90, x1.5/15/120, x1.5/15/120 | 1 | 2.3 min | 8.3 min | 35.7 min | 6.02 h | 8.91 h | 110 | 11 |
| same | 2 | 2.4 min | 8.9 min | 39.6 min | 6.47 h | 9.55 h | 110 | 11 |

Why these values: the first try crossed the wall (stage 120) and brought the first boss
well below the 2 to 3 min target. The kept values leave best stage 110 at 72 h, with stage
50 10 to 20% earlier. The third variant gave nearly the same curve, so the stronger burst
was kept: it is the skill that has to count against a boss. Values were not tuned further.

Open point: with the damage floor, the buff doubles the hits of 1 damage, so with
`--skills=1` the first boss comes at 1.9 min (2.2 min before the floor), just below the
target. The other milestones did not move. With `--skills=2` it stays at 2.4 min. Left as
it is: changing it is a design decision.

Against a boss, with the buff started first, the kept values add about 16.5 s of damage to
the 30 s of the fight: 9 s from the burst (6 s * x1.5) and 7.5 s from the buff.

Limits:

- Both models challenge a boss only when the estimate passes, and that estimate ignores
  skills on purpose. So the wall is measured for a player who does not count on them. A
  player who challenges early and uses all skills well needs about a third less damage
  per second, not measured here. It may move the wall: to check in playtest.
- Without absences, the kept values with `--skills=1` give stage 50 at 46.4 min, against
  55.2 min without skills (-16%), for a model that never misses a cooldown. The brief's
  target is about 1 h.
- The burst and the buff count their full effect in the simulator; a real player loses
  some of it to reaction time, and spends attention on the buttons.
- Cooldown modifiers (story 006) are not measured: they will increase all of these effects.

## Offline progress (story 004b)

Values in `core_curves.json`: `offline_efficiency` "0.1", `offline_max_hours` 12,
`offline_min_seconds` 60. Formula in `data_schema.md`: an absence pays 10% of what the
companions would earn by farming the current stage. The rate is tied to the stage
because gold per point of damage falls from about 0.136 at stage 1 to about 0.004 at
stage 100: a flat rate would be too generous early or worthless late.

    <godot console exe> --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=24 --auto=1 --away=0.5:8,3:8,6:12 --eff=0.1

Three returns during the run (8 h at 0.5 h active, 8 h at 3 h, 12 h at 6 h), 28 h away
in total. Times are active play, without the time away. 0 is the run without offline gold.

| `offline_efficiency` | Stage 50 | Stage 100 | Stage 110 | Gold of the 12 h return (stage 89) |
|---|---|---|---|---|
| 0 | 55.2 min | 8.56 h | 11.84 h | 0 |
| 0.05 | 46.7 min | 7.70 h (-10%) | 10.98 h | 3.9 T, 32 min of recent active income |
| 0.1 (kept) | 43.4 min | 7.06 h (-17.5%) | 10.34 h | 8.2 T, 67 min |
| 0.25 | 35.8 min | 6.02 h (-30%) | 9.09 h | 23.8 T, 195 min |
| 0.5 | 31.0 min | 6.01 h | 8.52 h | 51 T, 313 min |

Why 0.1: 28 h away saves about 1.5 h of active play, and a 12 h return is worth about
1 h of active income, against 12 h actually played. Absence helps without replacing
active play. At 0.25 absences already save 30% of the time to stage 100.

The wall holds. With six returns over 72 h of active play (the three above, then 12 h
at 12, 24 and 48 h active), the run stays at best stage 110, like the run without
offline gold: stage 120 is not reached. Each 12 h return at the wall pays 550 T to
1.1 Qa, about 60 to 100 min of recent active income.

Limits:

- "Recent active income" is the average of the last 10 active minutes. It lags behind
  an income that keeps growing, so it is underestimated early in a run, while income
  doubles quickly, and the equivalent in minutes is inflated there: the 118 min of the
  first return (stage 29, 0.5 h active) overstates its value. Compare the stage times
  rather than these minutes for early returns.
- The first return is the strongest in relative terms: stage 50 comes 21% earlier, and
  the model only spends 30 min before leaving for 8 h.
- The gold is computed once at the return, from the power and stage at that moment.
- The model buys at once and clicks non-stop; a real player's return may be worth more
  against a lower active income. Needs a playtest.
- Measured with no skills (see "Active skills"), talents or items (stories 006, 007), and
  the stat "or hors-ligne" of items (story 007) is not applied.

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
