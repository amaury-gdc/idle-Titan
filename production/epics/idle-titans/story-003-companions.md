# Story 003: Compagnons et paliers

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 3`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 3, pillar "L'équilibrage d'abord" and the calibration targets:*

- [ ] Environ 8 compagnons sont définis dans un fichier de données (nom, coût de base, courbe de coût, dégâts de base, paliers).
- [ ] Le joueur achète un compagnon et l'améliore avec l'or ; le coût suit la courbe en données.
- [ ] Les compagnons attaquent seuls, à intervalle régulier, sans clic.
- [ ] Atteindre un palier de niveau multiplie les dégâts du compagnon selon le multiplicateur en données.
- [ ] La puissance totale des compagnons alimente la formule de dégâts de clic (story 002).
- [ ] L'état des compagnons est sauvegardé et rechargé (état de partie).
- [ ] La liste des compagnons est lisible : nom, niveau, dégâts, coût du prochain niveau.
- [ ] Courbe mesurée : premier boss atteint en 2 à 3 minutes, étage 50 en environ 1 h (hypothèses) ; l'écart est noté dans le fichier de données ou une note de réglage.
- [ ] Une capture d'écran du panneau des compagnons est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Toutes les valeurs d'équilibrage dans `assets/data/` ; on règle la courbe sans toucher au code.
- Prévoir un moyen de simuler la progression (script ou mode accéléré) pour mesurer les objectifs sans jouer des heures.

---

## Out of Scope

- [Story 004]: boss.
- [Story 006, 007]: talents et objets qui modifient les dégâts.

---

## Files

- `src/core/companion.gd`, `src/core/companion_manager.gd`
- `src/ui/companion_panel.tscn`, `src/ui/companion_panel.gd`
- `assets/data/companions_roster.json`
- `tests/unit/companions/companions_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/companions/companions_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-002-core-loop.md`
- Unlocks: `production/epics/idle-titans/story-004-boss.md`
