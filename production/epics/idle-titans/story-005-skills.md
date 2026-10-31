# Story 005: Compétences actives

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 5`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 5:*

- [x] Trois compétences sont définies en données : gros coup, buff de dégâts, bonus d'or (effet, durée, temps de recharge).
- [x] Activer une compétence applique son effet : le gros coup inflige des dégâts immédiats, le buff multiplie les dégâts pendant sa durée, le bonus d'or multiplie l'or gagné pendant sa durée.
- [x] Après activation, la compétence est indisponible jusqu'à la fin de son temps de recharge.
- [x] Le temps de recharge restant est visible sur le bouton de la compétence.
- [x] Un buff actif et son temps restant sont visibles à l'écran.
- [x] Les temps de recharge et les effets se règlent par les fichiers de données.
- [x] Une capture d'écran des boutons de compétences (disponible et en recharge) est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Les recharges courent en temps réel ; vérifier le comportement quand l'onglet du navigateur passe en arrière-plan (pause ou rattrapage, à noter).
- Les talents (story 006) pourront réduire les recharges : prévoir des modificateurs.

---

## Out of Scope

- [Story 006]: talents modifiant les compétences.
- Compétences supplémentaires au-delà des 3.

---

## Files

- `src/core/skill.gd`, `src/core/skill.gd.uid`, `src/core/skill_manager.gd`, `src/core/skill_manager.gd.uid`
- `src/core/floor_manager.gd`, `src/core/game_state.gd`
- `src/ui/skill_bar.gd`, `src/ui/skill_bar.gd.uid`, `src/ui/skill_bar.tscn`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `assets/data/skills.json`, `assets/data/data_schema.md`, `assets/data/balance_notes.md`
- `tools/simulate_progress.gd`
- `tests/unit/skills/skills_test.gd`, `tests/unit/skills/skills_test.gd.uid`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/skills/skills_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [x] Partial (`tests/unit/skills/skills_test.gd` : buff de dégâts seulement)

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-004b-offline.md`
- Unlocks: `production/epics/idle-titans/story-006-talents.md`

---

## Completion Notes
**Completed**: 2026-10-31
**Criteria**: 7/7 passing (critère 2 confirmé en jeu par Amaury)
**Deviations**: Advisory : plancher d'au moins +1 dégât par coup sous buff, ajouté après le signalement d'Amaury (un coup de 1 passe à 2, soit ×2) ; premier boss à 1,9 min avec les compétences utilisées dès que prêtes, sous la cible de 2 à 3 min ; le simulateur ne mesure pas un joueur qui défie tôt avec ses compétences ; le nom « Frénésie » est provisoire. Hors `## Files` d'origine : `floor_manager.gd`, `game_state.gd`, `main_screen.gd/.tscn`, `simulate_progress.gd`, les documents de données, et les corrections du panneau « Bon retour ! » de la story 004b.
**Test Evidence**: `tests/unit/skills/skills_test.gd` (4 tests, suite 106/106) ; captures dans `production/qa/evidence/story-005-skills/`. Sauvegarde, recharge et expiration vérifiées par des contrôles jetables et dans Edge, pas par des tests conservés.
**Reviewed by**: lead-programmer (revue de code, rapport lu et défauts corrigés) ; godot-gdscript-specialist (contrôle moteur)
