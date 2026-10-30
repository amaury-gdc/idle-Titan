# Data file schemas (assets/data/)

All files: JSON, snake_case keys, loaded with `DataLoader.load_json(path)`
(returns null if missing/invalid; JSON numbers load as floats). Each file has a
top-level `schema_version` (int); bump it on a breaking schema change.

Big values (costs, damage, gold) are decimal STRINGS of digits so they stay
exact beyond int64 and parse with `BigNumber.from_string`. Decimal factors are
decimal strings such as "1.1" for `BigNumber.multiply_decimal`.

STATUS: both files are PLACEHOLDERS that only prove the loader works. No game
code reads their keys yet (story 002 will); values are not balanced.

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
| `schema_version` | int | yes | Currently 1. |
| `cost_growth` | decimal string (unitless factor) | yes | Placeholder: per-level cost multiplier (1.1 = +10% per level). |
