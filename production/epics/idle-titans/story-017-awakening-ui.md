# Story 017: Interface de l'éveil et grands nombres

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/economy-rework.md`
**Requirement**: hors brief MVP, refonte de l'économie demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] Au seuil, le bouton affiche « Éveiller » et son coût, sur le meilleur achat, avec le gain d'escouade.
- [ ] x10 s'arrête au seuil et affiche le vrai nombre ; Max s'arrête au seuil ; Palier vise le prochain palier ou seuil.
- [ ] Après le niveau 200, plus de « Dernier palier » trompeur tant qu'un éveil reste à venir.
- [ ] Le rang d'éveil se lit par la forme et le texte, jamais par la couleur seule.
- [ ] Le premier éveil affiche une phrase unique, une seule fois.
- [ ] Niveaux à 4 chiffres et nombres jusqu'à l'étage 300 tiennent sur les 18 tailles, sans texte ni mot coupé, avec 44 px et 14 px respectés, dans l'export.
- [ ] Aucune chute de fluidité dans l'export à 8 compagnons éveillés, processeur ×4 compris.
- [ ] Captures dans `production/qa/evidence/story-017-awakening-ui/`, et tous les tests verts.

---

## Out of Scope

- Règles et valeurs de l'éveil.
- Sons et animation longue.

---

## Files

- À remplir à la fin.

## QA Test Cases

*Or insuffisant, or exact, x10 à 3 niveaux du seuil, Max traversant un seuil, niveau 1000, suffixes Sp à Dc, notation scientifique, « Éclaireur Niv. 1000 » à 320 de large.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures dans `production/qa/evidence/story-017-awakening-ui/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-016-awakening.md`
- Unlocks: `production/epics/idle-titans/story-018-talent-tree-format.md`

---
