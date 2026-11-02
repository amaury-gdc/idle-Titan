# Story 020: Calibrage unique de l'économie

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/economy-rework.md`
**Requirement**: hors brief MVP, refonte de l'économie demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*Toutes les sources de puissance sont en place : c'est le seul calibrage, mesuré dans le moteur.*

- [ ] Les courbes de `design/economy-rework.md` sont dans les données, valeurs recalées et notées.
- [ ] Au profil de référence, à 3 clics/s, l'étage 200 arrive en 4 à 6 jours, avec 8 à 10 h actives ; 12 h au plus à 1 clic/s.
- [ ] Étage 230 non atteint après 40 h actives, pour chaque build de sommet.
- [ ] Premier éveil payé entre les étages 60 et 80 à 3 clics/s ; l'écart à 1 clic/s est noté.
- [ ] Part du clic sans talents à 3 clics/s : environ 40 % au milieu, 10 à 20 % à l'étage 200 ; un build clic atteint 40 à 60 % à 200.
- [ ] Tableau avant et après noté : étages 10, 50, 100, 150, 200, à 1 et 3 clics/s, niveaux, part du clic, moments des éveils.
- [ ] Mesures sur 3 graines, deux acheteurs, et sensibilité ×0,8 / ×1,2 du coût d'éveil et ±3 % de l'escouade notées.
- [ ] Premier boss battable sans ouvrir l'onglet Talents, à 1 et 3 clics/s.
- [ ] `design/game-brief.md`, `balance_notes.md` et `data_schema.md` à jour ; `real_data_test.gd` fige les nouvelles valeurs.
- [ ] Tous les tests restent verts, et Amaury a joué une partie reprise de sa vraie sauvegarde.

---

## Out of Scope

- Toute nouvelle mécanique.

---

## Files

- À remplir à la fin.

## QA Test Cases

*Build tout Clic, tout Compagnons, tout Économie, chaque sommet ; 1 h et 4 h par jour ; 13 clics/s ; sans objets ; sans talents.*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`, `assets/data/balance_notes.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-019-talent-tree-content.md`
- Unlocks: None

---
