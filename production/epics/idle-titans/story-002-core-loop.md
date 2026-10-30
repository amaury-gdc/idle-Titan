# Story 002: Boucle de base : clic, étages, or

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- `src/core/combat.gd`, `src/core/floor_manager.gd`
- `src/ui/main_screen.tscn`, `src/ui/main_screen.gd`
- `tests/unit/core-loop/core_loop_test.gd`

---

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
