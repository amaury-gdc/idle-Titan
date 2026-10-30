# Story 001: Données, état et sauvegarde

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-30

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 4`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 4 and pillar "Prêt pour la suite":*

- [ ] Compagnons, courbes et (plus tard) talents et objets sont lus depuis des fichiers de données externes, jamais codés en dur ; changer une valeur dans un fichier change le jeu sans toucher au code.
- [ ] L'état de partie (étage, or, niveaux de compagnons) et l'état permanent (talents, futurs artefacts) sont deux structures distinctes avec des sauvegardes distinctes.
- [ ] Réinitialiser l'état de partie ne touche pas à l'état permanent.
- [ ] La sauvegarde locale écrit les deux états et les recharge à l'identique (aller-retour).
- [ ] Une sauvegarde absente ou illisible démarre une partie neuve sans erreur.
- [ ] Les grands nombres s'affichent en abrégé (1 500 000 → « 1,5 M », 3 200 000 000 → « 3,2 B ») et restent exacts au-delà de la plage d'un entier 64 bits.
- [ ] La sauvegarde fonctionne dans l'export web (stockage local du navigateur).

---

## Implementation Notes

- Données en fichiers (JSON ou Resource) sous `assets/data/`, chargés au démarrage.
- Prévoir l'ajout de prestige et d'artefacts : l'état permanent doit accepter de nouveaux champs sans casser les anciennes sauvegardes (champ de version).
- Les histoires suivantes étendent la sauvegarde pour leur propre état.

---

## Out of Scope

- [Story 002]: la boucle de jeu elle-même.
- Or hors-ligne (hors périmètre V1).

---

## Files

- `src/core/big_number.gd`
- `src/core/game_state.gd`
- `src/core/permanent_state.gd`
- `src/core/save_manager.gd`
- `src/core/data_loader.gd`
- `assets/data/companions_roster.json`
- `assets/data/core_curves.json`
- `assets/data/data_schema.md`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs (advisory).*

**Story Type**: Integration
**Required evidence**: `tests/integration/data/save_roundtrip_test.gd` OU note de playtest (sauvegarde, rechargement de la page, état identique).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/idle-titans/story-002-core-loop.md`

---

## Completion Notes
**Completed**: 2026-10-30
**Criteria**: 6/7 passing (AC-7 deferred: web persistence of `user://` untested, moved to story 002 as its first-web-export criterion)
**Deviations**: `data_loader.gd` added outside the original Files list (approved). Review points left open: `*.json` export filter, explicit type annotations (`:=`), clamping of out-of-range floats, non-atomic write (mitigated by the `.bak` copy). Criteria AC-2 to AC-6 rest on the user's confirmation after a throwaway headless script run by the implementing agent; no evidence was retained.
**Test Evidence**: waived at qa.level minimal
**Reviewed by**: self, no independent review
