# Story 004b: Progression hors-ligne

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 8`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Vérifier l'heure réelle et la sauvegarde dans l'export web ; consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 8:*

- [x] L'heure réelle de la dernière sauvegarde est enregistrée.
- [x] Au lancement, le temps écoulé depuis cette heure donne de l'or, d'après la puissance des compagnons (formule et taux en données).
- [x] Le temps pris en compte est plafonné à 12 h (valeur en données).
- [x] Aucun gain si le temps écoulé est nul ou négatif (horloge reculée), ni si la sauvegarde n'a pas d'heure (ancienne sauvegarde) ; ces sauvegardes restent valides.
- [x] Un message indique au retour le temps pris en compte et l'or gagné.
- [x] La sauvegarde et le rechargement fonctionnent dans l'export web.
- [x] La courbe est remesurée avec le simulateur, et l'effet est noté dans `assets/data/balance_notes.md`.
- [x] Une capture d'écran du message de retour est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Le gain ne fait pas avancer les étages : seul l'or change.
- À trancher à l'implémentation : le taux, car le gain ne doit pas remplacer le jeu actif.

---

## Out of Scope

- Talents liés au hors-ligne (non prévus en V1).
- [Story 007]: effet de la stat « or hors-ligne ».

---

## Files

- `src/core/offline_income.gd`, `src/core/offline_income.gd.uid`
- `src/core/game_state.gd`, `src/core/save_manager.gd`, `src/core/combat.gd`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `assets/data/core_curves.json`, `assets/data/data_schema.md`, `assets/data/balance_notes.md`
- `tools/simulate_progress.gd`
- `tests/unit/offline/offline_income_test.gd`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/offline/offline_income_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [x] Created (`tests/unit/offline/offline_income_test.gd`)

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-004-boss.md`
- Unlocks: `production/epics/idle-titans/story-005-skills.md`

---

## Completion Notes
**Completed**: 2026-10-31
**Criteria**: 8/8 passing (export web testé dans Edge en headless, un seul navigateur)
**Deviations**: Advisory : la sauvegarde faite au masquage de l'onglet reste en mémoire (onglet fermé caché : repart du dernier autosave, 5 s perdues au maximum) ; navigation privée sans avertissement, non testée ; un second retour avec le panneau ouvert remplace le message (or crédité) ; pause du jeu derrière le panneau, minimum de 60 s et schéma 2 ou 3 acceptés par `Combat`, ajouts hors critères d'origine. Hors périmètre : la clôture de la story 004 n'est pas encore committée.
**Test Evidence**: `tests/unit/offline/offline_income_test.gd` (9 tests, suite 102/102) ; captures dans `production/qa/evidence/story-004b-offline/`
**Reviewed by**: self, no independent review

**Recontrôle du 2026-10-31**: 8/8, statut inchangé. Une revue de code a trouvé deux défauts, corrigés dans le commit de la story 005 car `main_screen.gd` y est modifié : on pouvait cliquer autour du panneau « Bon retour ! » (par exemple défier un boss au chrono figé), reproduit puis corrigé dans Edge, capture 07 ; et l'or hors-ligne était accordé avant la validation de `skills.json`. Le critère web est vérifié dans Edge en headless, avec des entrées simulées : Chrome et Firefox ne sont pas testés. À tester par Amaury : aucun critère, seulement le retour d'onglet dans son navigateur (voir `production/bilan-2026-10-31.md`).
