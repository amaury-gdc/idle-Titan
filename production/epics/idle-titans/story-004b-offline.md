# Story 004b: Progression hors-ligne

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] L'heure réelle de la dernière sauvegarde est enregistrée.
- [ ] Au lancement, le temps écoulé depuis cette heure donne de l'or, d'après la puissance des compagnons (formule et taux en données).
- [ ] Le temps pris en compte est plafonné à 12 h (valeur en données).
- [ ] Aucun gain si le temps écoulé est nul ou négatif (horloge reculée), ni si la sauvegarde n'a pas d'heure (ancienne sauvegarde) ; ces sauvegardes restent valides.
- [ ] Un message indique au retour le temps pris en compte et l'or gagné.
- [ ] La sauvegarde et le rechargement fonctionnent dans l'export web.
- [ ] La courbe est remesurée avec le simulateur, et l'effet est noté dans `assets/data/balance_notes.md`.
- [ ] Une capture d'écran du message de retour est conservée dans `production/qa/evidence/`.

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

- `src/core/offline_income.gd`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `assets/data/core_curves.json`, `assets/data/data_schema.md`, `assets/data/balance_notes.md`
- `tests/unit/offline/offline_income_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/offline/offline_income_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-004-boss.md`
- Unlocks: `production/epics/idle-titans/story-005-skills.md`
