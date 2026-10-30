# Story 004: Boss et repli

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 2`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, core loop and fail state:*

- [ ] Un étage multiple de 10 contient un boss (points de vie et or selon des courbes de boss en données).
- [ ] Un chronomètre démarre au début du combat de boss ; sa durée (30 s par défaut) est en données.
- [ ] Tuer le boss avant la fin du chrono passe à l'étage suivant.
- [ ] Si le chrono expire, le joueur retourne à l'étage précédent et continue de farmer ; le boss n'est retenté que sur demande ou selon la règle choisie et notée.
- [ ] Le chrono et le boss sont clairement visibles à l'écran (lisibilité).
- [ ] L'étage maximal atteint est conservé comme score, même après un repli.
- [ ] Une capture d'écran d'un combat de boss est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Règle à trancher et noter à l'implémentation : reprise automatique du boss après le repli, ou bouton « retenter ».
- Valeurs en données (durée du chrono, courbes de boss).

---

## Out of Scope

- [Story 007]: butin de boss (premier objet à l'étage 10).
- Bonus de dégâts de boss et or des boss (stats d'objets, story 007).

---

## Files

- `src/core/boss_fight.gd`, `src/core/floor_manager.gd`
- `src/ui/boss_timer.tscn`
- `tests/unit/boss/boss_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/boss/boss_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-003-companions.md`
- Unlocks: `production/epics/idle-titans/story-005-skills.md`
