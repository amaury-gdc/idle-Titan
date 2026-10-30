# Data file schemas (assets/data/)

All files: JSON, snake_case keys, loaded with `DataLoader.load_json(path)`
(returns null if missing/invalid; JSON numbers load as floats). Each file has a
top-level `schema_version` (int); bump it on a breaking schema change.

Big values (costs, damage, gold) are decimal STRINGS of digits so they stay
exact beyond int64 and parse with `BigNumber.from_string`. Decimal factors are
decimal strings such as "1.1" for `BigNumber.multiply_decimal`.

STATUS: both files hold PLACEHOLDER balance, not balanced (story 003 tunes it).
Story 002 (`Combat`, `src/core/combat.gd`) reads every key below except
`cost_growth` (read by story 003, companion purchase) and the roster's `name`
and `base_cost` (display and purchase, story 003). `Combat.from_data` rejects a
file with the wrong `schema_version` or an invalid value and the main screen
then shows the error instead of the game.

## companions_roster.json

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 1. |
| `companions` | array of object | yes | One entry per companion (8 in the MVP). |
| `companions[].id` | string | yes | Unique stable id; the key used in `GameState.companion_levels`. |
| `companions[].name` | string | yes | Display name. |
| `companions[].base_cost` | digit string (gold) | yes | Gold cost of level 1. |
| `companions[].base_damage` | digit string (damage per attack) | yes | Damage at level 1. |

No optional fields yet; future optional fields must state their default here.

## core_curves.json

| Key | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | Currently 2 (2 added the combat keys below). `Combat` refuses any other value. |
| `cost_growth` | decimal string (unitless factor) | yes | Placeholder: per-level cost multiplier (1.1 = +10% per level). Not read before story 003. |
| `enemy_hp_base` | digit string (HP) | yes | HP of the stage-1 enemy. Default in file: "15". |
| `enemy_hp_growth` | decimal string (unitless factor >= 1 recommended) | yes | Per-stage HP multiplier. HP(stage) = floor(`enemy_hp_base` * growth^(stage-1)), exact, never below 1. Default in file: "1.3". |
| `gold_per_kill_base` | digit string (gold) | yes | Gold for killing the stage-1 enemy. Default in file: "3". |
| `gold_per_kill_growth` | decimal string (unitless factor) | yes | Per-stage gold multiplier. Gold(stage) = floor(`gold_per_kill_base` * growth^(stage-1)), exact. Default in file: "1.25". |
| `click_damage_base` | digit string (damage per click) | yes | Click damage before any companion share. Default in file: "1". |
| `click_companion_power_factor` | decimal string (unitless fraction of companion power) | yes | Share of total companion power added to a click: click = base + floor(power * factor). "0.1" = 10%. Companion power is 0 until companions are bought (story 003). Default in file: "0.1". |
| `autosave_interval_seconds` | number (seconds, > 0) | no | Period of the main screen autosave. If missing or not a positive number the code uses 10 (constant `FALLBACK_AUTOSAVE_SECONDS` in `src/ui/main_screen.gd`). Value in file: 5. |

Growth factors are applied exactly as floor(base * numerator^n / 10^(scale*n)) by
`GrowthCurve` (`src/core/growth_curve.gd`), not by repeated truncation, so the
value at stage N does not depend on the earlier stages' rounding. Companion
power (placeholder, story 003 replaces it) = sum over bought companions of
`base_damage` * level, with level read from `GameState.companion_levels`; ids
absent from the roster are ignored.
