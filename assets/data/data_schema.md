# Data file schemas (assets/data/)

All files: JSON, snake_case keys, loaded with `DataLoader.load_json(path)`
(returns null if missing/invalid; JSON numbers load as floats). Each file has a
top-level `schema_version` (int); bump it on a breaking schema change.

Big values (costs, damage, gold) are decimal STRINGS of digits so they stay
exact beyond int64 and parse with `BigNumber.from_string`. Decimal factors are
decimal strings such as "1.1" for `BigNumber.multiply_decimal`.

STATUS: all files hold PROVISIONAL balance, calibrated in stories 003 to 005
against the brief's hypotheses; measurements and gaps are in `balance_notes.md`.
`Combat` (`src/core/combat.gd`) reads the curves and builds one `Companion`
(`src/core/companion.gd`) per roster entry. `Combat.from_data` rejects a file with
the wrong `schema_version` or an invalid value and the main screen then shows the
error instead of the game. `BossFight.from_data` (`src/core/boss_fight.gd`) does the
same for `boss_curves.json`.

## companions_roster.json

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 2 (2 added cost, cadence and tiers). `Combat` refuses any other value. |
| `companions` | array of object | yes | One entry per companion (8 in the MVP), in display order. |
| `companions[].id` | string | yes | Unique stable id; the key used in `GameState.companion_levels`. Renaming one orphans the saved level. |
| `companions[].name` | string | yes | Display name (French). |
| `companions[].base_cost` | digit string (gold) | yes | Gold cost of level 1. |
| `companions[].base_damage` | digit string (damage per attack) | yes | Damage at level 1, before tiers. |
| `companions[].cost_growth` | decimal string (unitless factor) | no | Per-level cost multiplier. Default when absent: `cost_growth` of core_curves.json. |
| `companions[].attack_interval_seconds` | number (seconds, >= 0.001) | yes | Time between two automatic attacks; resolution 1 ms in the power formula. |
| `companions[].tiers` | array of object | yes | Level tiers, may be empty. |
| `companions[].tiers[].level` | integer >= 2, strictly increasing | yes | Level at which the tier applies. |
| `companions[].tiers[].damage_multiplier` | decimal string (unitless factor > 0) | yes | Multiplies the companion's damage from that level on; tiers stack by product. |

Formulas (exact BigNumber, level L >= 1, level 0 = not bought, deals 0):

- Cost of level L: `floor(base_cost * cost_growth^(L-1))`.
- Damage per attack at level L: `floor(base_damage * L * product of damage_multiplier
  of every tier with tier.level <= L)`. One floor, after the whole product.
- Damage per second at level L: `floor(damage per attack / attack_interval_seconds)`.
- Companion power (click formula input): sum of the damage PER SECOND of the bought
  companions. Per second rather than per attack because companions attack at
  different intervals: it measures what they really add to the fight, so a fast
  weak companion and a slow strong one with the same output feed the click equally.
  `click_companion_power_factor` is therefore a share of DPS.

## core_curves.json

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 3 (2 added the combat keys below; 3 added the `offline_*` keys). `Combat` reads 2 and 3 and refuses any other value, because 3 only added keys it does not read; `OfflineIncome` requires 3, so the game stops on a version 2 file. |
| `cost_growth` | decimal string (unitless factor) | only if a companion has no own `cost_growth` | Default per-level cost multiplier (1.08 = +8% per level). Value in file: "1.08". |
| `enemy_hp_base` | digit string (HP) | yes | HP of the stage-1 enemy. Value in file: "22". |
| `enemy_hp_growth` | decimal string (unitless factor >= 1 recommended) | yes | Per-stage HP multiplier. HP(stage) = floor(`enemy_hp_base` * growth^(stage-1)), exact, never below 1. Value in file: "1.325". |
| `gold_per_kill_base` | digit string (gold) | yes | Gold for killing the stage-1 enemy. Default in file: "3". |
| `gold_per_kill_growth` | decimal string (unitless factor) | yes | Per-stage gold multiplier. Gold(stage) = floor(`gold_per_kill_base` * growth^(stage-1)), exact. Value in file: "1.28". |
| `click_damage_base` | digit string (damage per click) | yes | Click damage before any companion share. Default in file: "1". |
| `click_companion_power_factor` | decimal string (unitless fraction of companion power) | yes | Share of total companion power (damage per second) added to a click: click = base + floor(power * factor). "0.1" = 10%. Companion power is 0 until companions are bought. Value in file: "0.1". |
| `autosave_interval_seconds` | number (seconds, > 0) | no | Period of the main screen autosave. If missing or not a positive number the code uses 10 (constant `FALLBACK_AUTOSAVE_SECONDS` in `src/ui/main_screen.gd`). Value in file: 5. |
| `offline_efficiency` | decimal string (unitless fraction) | yes | Share of what the companions would earn by farming the current stage that an absence pays. See the formula below. Value in file: "0.1". |
| `offline_max_hours` | number (hours, > 0) | yes | Cap of the absence time counted (brief: 12 h). Value in file: 12. |
| `offline_min_seconds` | number (seconds, >= 0) | yes | An absence shorter than this earns nothing and shows no message, so that reloading the page does not open it each time. Set it to 0 to see the message on any return. Value in file: 60. |

Offline gold (`OfflineIncome`, `src/core/offline_income.gd`), granted once at startup:

- Counted seconds = min(now - `GameState.last_saved_unix`, `offline_max_hours` * 3600).
- Gold = floor(companion power * counted seconds * Gold(stage) / HP(stage) *
  `offline_efficiency`), exact. Stage is `GameState.stage`; Gold and HP are those of the
  normal enemy of that stage, even on a boss stage. Only gold changes.
- No gain when the saved time is unknown, when the elapsed time is zero or negative
  (clock moved back), when it is below `offline_min_seconds`, or with no companion.

Saved field: `last_saved_unix` (int, Unix seconds, default 0 = unknown) in the game save,
stamped by `SaveManager` on every game save and cleared by `GameState.reset()`. The game
save has no version number: an older save has no such key, loads with 0, stays valid and
earns nothing on its first return. A negative, non-numeric or absurd value also gives 0.

Growth factors are applied exactly as floor(base * numerator^n / 10^(scale*n)) by
`GrowthCurve` (`src/core/growth_curve.gd`), not by repeated truncation, so the
value at stage N does not depend on the earlier stages' rounding. Companion
levels are read from `GameState.companion_levels`; ids absent from the roster are
ignored.

## boss_curves.json

All keys are required. An invalid or missing file stops the game on the main screen
error, like the two files above.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 3 (2 replaced `boss_hp_base` and `boss_hp_growth` by `boss_hp_multiplier`; 3 added `auto_challenge_margin`). `BossFight` refuses any other value. |
| `boss_every_stages` | integer >= 2 | yes | A stage S is a boss stage when `S % boss_every_stages == 0`. Must be >= 2 so that a fallback can never reach a stage below 1 or another boss stage. Value in file: 10. |
| `timer_seconds` | number (seconds, > 0) | yes | Length of the countdown of one boss fight; it starts when the fight begins. Value in file: 30. |
| `boss_hp_multiplier` | decimal string (unitless factor) | yes | Boss HP(S) = floor(enemy HP of stage S * `boss_hp_multiplier`), exact (`multiply_decimal`), never below 1. Value in file: "20". |
| `boss_gold_base` | digit string (gold) | yes | Base of the boss gold curve. Boss gold(S) = floor(`boss_gold_base` * `boss_gold_growth`^(S-1)), exact. Replaces the normal kill gold on a boss stage. Value in file: "15". |
| `boss_gold_growth` | decimal string (unitless factor) | yes | Per-stage multiplier of boss gold. Value in file: "1.30". |
| `auto_challenge_margin` | decimal string (unitless factor >= 1 recommended) | yes | Safety margin of "Défi automatique": the estimated damage must cover boss HP * this factor. Without it, a narrow estimate fails attempt after attempt. Value in file: "1.2". |

Retry rule (story 004, implemented by `FloorManager`): FARM MODE AND CHALLENGE. When
the countdown runs out the player falls back to the previous stage (boss at stage 10
-> stage 9) in farm mode: a kill grants gold and respawns an enemy of the same stage,
with no stage advance, for as long as the player wants. The "Défier le boss" button,
shown only in farm mode, leaves it and starts the boss of the next stage at full HP
with a full countdown; failing again returns to farm mode. The "Abandonner le boss"
button, shown only during a boss fight, counts as a failed fight. With the "Défi automatique"
setting (off by default) a kill in farm mode does the same by itself, but only when
the estimated damage covers the boss: (companion damage per second + measured click
damage per second) * `timer_seconds` >= boss HP * `auto_challenge_margin`. Otherwise
the player keeps farming.

Saved fields: `farming` (bool, default false) in the game save, kept across a reload
and cleared by `GameState.reset()`; in the permanent save (version 3), `auto_challenge`
(bool, default false), a preference that survives run resets, and `boss_hint_shown`
(bool, default false), set when the message of the first failed boss is shown, so it
appears only once per player. Older saves load with these at false. If a loaded save says farming but the next stage is not a boss
stage (the boss data changed), `FloorManager` clears the flag. Nothing about a
running fight is saved: loading a save on a boss stage starts the boss at full HP with
a fresh countdown.

A stage counts as reached (`GameState.max_stage_reached`, the score) as soon as its
fight begins, boss included; a fallback never lowers it.

## skills.json

Loaded by `SkillManager` (`src/core/skill_manager.gd`), one `Skill`
(`src/core/skill.gd`) per entry. An invalid or missing file stops the game on the main
screen error, like the files above.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 1. `SkillManager` refuses any other value. |
| `skills` | array of object | yes | Exactly one skill per effect (3 in the MVP), in display order. |
| `skills[].id` | string | yes | Unique stable id; the key used in `GameState.skill_timers`. Renaming one drops its saved timers. |
| `skills[].name` | string | yes | Display name (French). |
| `skills[].effect` | string | yes | `burst`, `damage_multiplier` or `gold_multiplier`. |
| `skills[].dps_seconds` | decimal string (seconds, > 0) | `burst` only | Seconds of damage dealt at once, see the formula below. Value in file: "6". |
| `skills[].multiplier` | decimal string (unitless factor > 1) | the two buffs only | `damage_multiplier`: factor on all damage dealt. `gold_multiplier`: factor on the gold of kills. Values in file: "1.5" and "1.5". |
| `skills[].duration_seconds` | number (seconds, > 0) | the two buffs only | How long the effect lasts. Values in file: 15 and 20. |
| `skills[].cooldown_seconds` | number (seconds, > 0, >= duration) | yes | Time from activation until the skill is ready again; it includes the duration. Values in file: 60, 90 and 120. |

Effects (exact BigNumber, applied by `FloorManager`):

- Burst damage = floor((companion power + click damage) * `dps_seconds`), dealt at once.
  The click term keeps it useful before the first companion, and companion power makes
  it scale up to the bosses. It is multiplied by the damage buff when that runs.
- The damage buff applies to clicks, companion attacks and the burst, and always adds at
  least 1 damage per hit: floor(1 * 1.5) would leave the smallest hits untouched. The
  gold bonus applies to the gold of normal kills and boss kills.
- While the damage buff runs, the DPS line, its tooltip and the click damage on screen
  show the buffed values. The DPS of each companion in the panel stays buff-free.
- Offline gold (`OfflineIncome`) uses neither buff. `FloorManager.can_beat_next_boss`
  ignores both too: "Défi automatique" does not count on a temporary buff.

Cooldown modifier: `SkillManager.set_cooldown_modifier(factor)` scales every cooldown
started afterwards, for the talents of story 006. Default 1.0, never below the duration.
Not saved: talents will set it again at startup.

Time: timers count game time fed to `SkillManager.tick`, cut to 5 s per call
(`MAX_TICK_SECONDS`, same bound as the companions and the boss countdown), so skills stop
when the game stops:

- Tab in the background: a hidden tab runs no frames (measured in story 004b), so
  cooldowns and running buffs are PAUSED, with no catch-up. On return, the first frame
  credits at most 5 s. This return itself was reasoned from the code, not measured in a
  browser.
- "Bon retour !" panel: `_process` stops ticking and skill presses are ignored until it
  is closed.
- Absence: no recharge. A cooldown resumes where it stopped.

Saved field: `skill_timers` in the game save (object, default empty), id ->
`{"cooldown_left", "active_left"}` in seconds, only for skills that are not ready. So
reloading the page does not refill the skills and a running buff survives it. An older
save has no such key and loads with every skill ready. A malformed entry is dropped,
unknown ids are ignored, and values are cut to the current data. As saves happen every
`autosave_interval_seconds`, a reload can lose up to that much of a timer in either
direction. The game save has no version number, so none was bumped.
