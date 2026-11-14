# Story 020: Calibrage unique de l'économie

> **Epic**: Idle Titans (MVP)
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-12

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

## Écarts connus (décision d'Amaury, 2026-11-14)

La part du clic n'atteint pas ses cibles ; elle n'est pas corrigée ici. Ni les talents Clic ni `click_companion_power_factor` ne sont modifiés dans cette story. Suite : `production/epics/idle-titans/story-023-active-play-value.md`.

| Mesure (profil de référence, graine 1) | Mesuré | Cible |
|---|---|---|
| Build de référence (Compagnons), étage 200, 3 clics/s | 17 % | — |
| Build de référence (Compagnons), étage 200, 1 clic/s | 7 % | — |
| Sans talents, 3 clics/s, au milieu | 24 % | environ 40 % |
| Sans talents, 3 clics/s, étage 200 | 22 % | 10 à 20 % |
| Build Clic, étage 200, 3 clics/s | 32 % | 40 à 60 % |

Autres écarts notés : avec l'escouade à −3 %, l'étage 200 arrive au jour 7 (cible : jours 4 à 6) ; sans talents à 1 clic/s aussi. Les courbes retenues diffèrent de celles de `design/economy-rework.md` (base 24 et non 30, paliers du milieu montés, mur en deux marches), sur décision d'Amaury.

---

## Ajout de périmètre (demandé par Amaury, 2026-11-14)

Message affiché une fois au chargement, pour les sauvegardes dont le record dépasse l'étage 150 : titre « Équilibrage mis à jour », texte « L'équilibrage a changé : les monstres des étages élevés sont plus résistants. Tu ne perds rien. ». C'est du code (`BalanceNotice`, un champ de sauvegarde, l'écran principal) dans une story Config/Data dont le hors-périmètre exclut toute nouvelle mécanique : ajout accepté par Amaury, parce que les joueurs au-delà de l'étage 180 environ restent bloqués un temps.

- Données : `balance_version` 1 et `balance_notice_min_stage` 150 dans `core_curves.json`.
- Sauvegarde permanente : `balance_seen`, format 6 → 7 ; une ancienne sauvegarde lit 0.
- Ordre : message de retour, puis arbre de talents s'il est dû, puis celui-ci. Un record à 150 ou moins est noté « vu » sans message.
- Preuves : `tests/unit/core-loop/balance_notice_test.gd`, `tests/unit/ui/balance_notice_wiring_test.gd`, captures dans `production/qa/evidence/story-020-economy-calibration/`.

---

## Out of Scope

- Toute nouvelle mécanique.

---

## Files

- `assets/data/core_curves.json`
- `assets/data/balance_notes.md`
- `assets/data/data_schema.md`
- `design/game-brief.md`
- `design/economy-rework.md`
- `src/core/balance_notice.gd`
- `src/core/permanent_state.gd`
- `src/ui/main_screen.gd`
- `tests/integration/balance/real_data_test.gd`
- `tests/integration/save/talent_refund_test.gd`
- `tests/unit/core-loop/balance_notice_test.gd`
- `tests/unit/ui/balance_notice_wiring_test.gd`
- `production/qa/smoke-2026-11-14.md`
- `production/qa/evidence/story-020-economy-calibration/`
- `production/epics/idle-titans/story-023-active-play-value.md`, `production/epics/idle-titans/EPIC.md`

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
