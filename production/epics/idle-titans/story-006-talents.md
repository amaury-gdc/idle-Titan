# Story 006: Arbre de talents

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 6`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 6 and the state-separation rule:*

- [ ] Le joueur gagne 1 point de talent tous les 5 étages atteints.
- [ ] L'arbre compte 3 branches (Clic, Compagnons, Économie) et environ 15 nœuds, définis dans un fichier de données (coût, effet, prérequis).
- [ ] Dépenser un point sur un nœud débloqué applique son effet aux formules de jeu (dégâts de clic, dégâts des compagnons, or).
- [ ] Un nœud n'est achetable que si son prérequis est rempli et qu'il reste des points.
- [ ] La réinitialisation est gratuite et rend tous les points dépensés ; elle est possible à tout moment pour tester d'autres builds.
- [ ] Les talents et les points appartiennent à l'état permanent (story 001) ; ils sont sauvegardés et survivent à une réinitialisation de la partie.
- [ ] L'arbre est lisible : branches distinctes, nœuds achetés, achetables et verrouillés se distinguent d'un coup d'œil.
- [ ] Une capture d'écran de l'arbre avec des nœuds achetés est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- L'état permanent doit accepter de nouveaux nœuds ou branches sans casser les anciennes sauvegardes (prestige et artefacts viendront après).

---

## Out of Scope

- [Story 007]: objets.

---

## Files

- `src/core/talent_tree.gd`, `.uid`
- `src/ui/talent_screen.tscn`, `src/ui/talent_screen.gd`, `.uid`
- `assets/data/talents.json`
- `src/core/floor_manager.gd`, `src/core/companion_manager.gd`, `src/core/permanent_state.gd`
- `src/core/offline_income.gd`, `src/core/skill_manager.gd`
- `tests/unit/talents/talents_test.gd`
- `design/game-brief.md`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `tools/simulate_progress.gd`
- `assets/data/data_schema.md`, `assets/data/balance_notes.md`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/talents/talents_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [x] Created: `tests/unit/talents/talents_test.gd`, 31 tests

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-005-skills.md`
- Unlocks: `production/epics/idle-titans/story-007-loot.md`

---

## Completion Notes

**Completed**: 2026-10-31
**Criteria**: 8/8 passing. À tester par Amaury, non vérifié ici : clic réel au pointeur dans l'arbre, Tab et manette (contrôlés seulement sans affichage), sensation des bonus de 2 à 10 %.
**Deviations**:
- Points dépensés déduits des nœuds achetés (non stockés), `talent_points` conservé sans usage, `best_stage_record` ajouté à la sauvegarde (v4).
- À la demande d'Amaury : « Gros coup » profite des talents de clic et de compagnons ; nœud Rentes (+25 % d'or hors-ligne) ajouté, la ligne « hors périmètre » retirée de la story ; brief mis à jour.
- Fichiers hors liste `## Files` : `.godot/global_script_class_cache.cfg` (généré, suivi volontairement), `EPIC.md`, `story-005-skills.md`, `production/bilan-2026-10-31.md` (restes de la 005), `tools/simulate_progress.gd`.
- `SkillManager._combat` n'est plus utilisé (le retirer touche aux tests de la 005).
- Valeurs provisoires (%, coûts, Rentes, mur avant l'étage 130) : réglage unique après la story 007. Premier boss à 1,5 min, sous la cible de 2 à 3 min.
**Test Evidence**: `tests/unit/talents/talents_test.gd` (31 tests, suite 137/137) ; captures dans `production/qa/evidence/story-006-talents/`, stamp à jour.
**Reviewed by**: self, no independent review
