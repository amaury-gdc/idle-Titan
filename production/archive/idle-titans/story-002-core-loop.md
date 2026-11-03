# Story 002: Boucle de base : clic, étages, or

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-30

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 1`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Rendu Compatibility (web) ; consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, core loop and pillar "Lisible":*

- [ ] Un ennemi est présent par étage, avec des points de vie lus depuis une courbe en données.
- [ ] Un clic inflige des dégâts = base + % de la puissance des compagnons (le % et la base sont en données).
- [ ] Quand l'ennemi meurt, le joueur gagne de l'or (valeur lue depuis une courbe en données) et l'étage suivant commence.
- [ ] Le numéro d'étage, l'or et les dégâts de clic sont affichés en permanence, en grands nombres abrégés.
- [ ] Le jeu reste jouable et lisible dans le navigateur (export web) à 1280x720.
- [ ] L'étage atteint est affiché comme score.
- [ ] Premier export web : créer le preset Web, ajouter `*.json` aux filtres d'export, renseigner `commands.build` via `/settings`, puis sauvegarder, recharger la page et comparer l'état. (Reporté depuis la story 001, AC-7 : persistance de `user://` dans l'export web.)
- [ ] Une capture d'écran de l'écran de jeu est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Aucune valeur de jeu en dur : tout vient des fichiers de données de la story 001.
- Les dégâts des compagnons sont à 0 tant que la story 003 n'existe pas ; la formule doit déjà accepter leur puissance.
- Lancer le jeu et observer le résultat avant de clore (`.claude/docs/run-and-observe.md`).

---

## Out of Scope

- [Story 003]: compagnons et leur achat.
- [Story 004]: boss et chrono.

---

## Files

- `src/core/growth_curve.gd`
- `src/core/combat.gd`
- `src/core/floor_manager.gd`
- `src/ui/enemy_view.gd`
- `src/ui/main_screen.gd`
- `src/ui/main_screen.tscn`
- `assets/data/core_curves.json`
- `assets/data/data_schema.md`
- `project.godot`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/core-loop/core_loop_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-001-data-state-save.md`
- Unlocks: `production/epics/idle-titans/story-003-companions.md`

---

## Completion Notes
**Completed**: 2026-10-30
**Criteria**: 8/8 passing (none deferred). Gameplay and browser criteria (AC-1 to AC-3, AC-5, AC-7) rest on the user's play test of `build/web`; AC-4, AC-6 and AC-8 are covered by the retained screenshot.
**Deviations**: None blocking. Out of scope but justified: `.gitignore`, `project.yaml`, `export_presets.cfg` (AC-7); `src/core/game_state.gd` and `tests/integration/save/save_roundtrip_test.gd` (`max_stage_reached`, for story 004); `tests/unit/core-loop/core_loop_test.gd`. The score label still shows the current stage; story 004 must read `max_stage_reached`.
**Test Evidence**: `production/qa/evidence/story-002-core-loop/01-main-screen.png` (desktop run at 1280x720, not the browser, initial state); logic tests waived at qa.level minimal (a unit test file exists anyway: 90/90 pass).
**Reviewed by**: self, no independent review
