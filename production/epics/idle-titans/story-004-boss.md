# Story 004: Boss et repli

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

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

- Règle retenue : après un repli, farm continu de l'étage précédent, bouton « Défier le boss » et réglage « Défi automatique », désactivé par défaut, qui ne défie que si les dégâts estimés suffisent. Règle notée dans `assets/data/data_schema.md`.
- Valeurs en données (durée du chrono, courbes de boss).

---

## Out of Scope

- [Story 007]: butin de boss (premier objet à l'étage 10).
- Bonus de dégâts de boss et or des boss (stats d'objets, story 007).

---

## Files

- `src/core/boss_fight.gd`, `src/core/floor_manager.gd`
- `src/core/game_state.gd`, `src/core/permanent_state.gd`
- `src/ui/boss_timer.tscn`, `src/ui/boss_timer.gd`
- `src/ui/enemy_view.gd`, `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `assets/data/boss_curves.json`, `assets/data/core_curves.json`
- `assets/data/data_schema.md`, `assets/data/balance_notes.md`
- `tools/simulate_progress.gd`

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
- Unlocks: `production/epics/idle-titans/story-004b-offline.md`

---

## Completion Notes
**Completed**: 2026-10-31
**Criteria**: 7/7 passing (comportement confirmé par le user en test navigateur ; captures 01-05 conservées)
**Deviations**: Advisory : captures 01-03 montrent l'ancien interrupteur de défi automatique (05 montre l'actuel) ; contrôle moteur non relancé depuis le défi automatique et l'abandon ; à 3 clics/s le boss 110 n'est pas battu en 72 h (arrêt de plus de 60 h, à juger en équilibrage). Hors `## Files` mais déjà au commit 119be38 : réintégration du hors-ligne (brief, epic, stories 001/004b/005/006/007), DPS de clic, `tools/*` à exclure du preset Web.
**Test Evidence**: waived at qa.level minimal ; captures dans `production/qa/evidence/story-004-boss/`
**Reviewed by**: self, no independent review
