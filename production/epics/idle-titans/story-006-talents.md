# Story 006: Arbre de talents

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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
- Talents liés au hors-ligne (hors-ligne hors périmètre V1).

---

## Files

- `src/core/talent_tree.gd`
- `src/ui/talent_screen.tscn`, `src/ui/talent_screen.gd`
- `assets/data/talents.json`
- `tests/unit/talents/talents_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/talents/talents_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-005-skills.md`
- Unlocks: `production/epics/idle-titans/story-007-loot.md`
