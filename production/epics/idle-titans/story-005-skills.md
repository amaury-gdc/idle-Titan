# Story 005: Compétences actives

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] Trois compétences sont définies en données : gros coup, buff de dégâts, bonus d'or (effet, durée, temps de recharge).
- [ ] Activer une compétence applique son effet : le gros coup inflige des dégâts immédiats, le buff multiplie les dégâts pendant sa durée, le bonus d'or multiplie l'or gagné pendant sa durée.
- [ ] Après activation, la compétence est indisponible jusqu'à la fin de son temps de recharge.
- [ ] Le temps de recharge restant est visible sur le bouton de la compétence.
- [ ] Un buff actif et son temps restant sont visibles à l'écran.
- [ ] Les temps de recharge et les effets se règlent par les fichiers de données.
- [ ] Une capture d'écran des boutons de compétences (disponible et en recharge) est conservée dans `production/qa/evidence/`.

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

- `src/core/skill.gd`, `src/core/skill_manager.gd`
- `src/ui/skill_bar.tscn`
- `assets/data/skills.json`
- `tests/unit/skills/skills_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/skills/skills_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-004-boss.md`
- Unlocks: `production/epics/idle-titans/story-006-talents.md`
