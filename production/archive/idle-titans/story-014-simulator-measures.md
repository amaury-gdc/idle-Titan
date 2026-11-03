# Story 014: Mesures du simulateur et référence d'équilibre

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/game-brief.md`
**Requirement**: hors brief MVP, préalable à la refonte de l'économie demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*Aucune règle de jeu ne change : cette story mesure et fige l'existant avant de le modifier.*

- [x] Sans les nouvelles options, le simulateur imprime exactement la même sortie qu'avant, hors « Real time ».
- [x] `--milestones=10,20,...` choisit les étages suivis ; les étages du premier boss restent suivis.
- [x] `--report=1` imprime à chaque jalon les niveaux des 8 compagnons, la puissance, la part estimée du clic et les dégâts par pièce d'or du prochain niveau.
- [x] `--buyer=cheapest` (défaut) ou `--buyer=ratio` choisit l'achat, parmi les niveaux abordables ; une autre valeur est refusée avec un message clair.
- [x] Un test charge les vrais fichiers de `assets/data/` et les déclare valides.
- [x] Un test fige les valeurs actuelles : PV aux étages 1, 10, 50, 100 et 120, PV de boss, coûts de niveau, formule du clic.
- [x] Une référence mesurée sur 72 h, à 1 et 3 clics/s, est notée dans `assets/data/balance_notes.md`.
- [x] Tous les tests restent verts.

---

## Out of Scope

- Toute courbe, toute valeur de `assets/data/` hors `balance_notes.md`.
- L'éveil, les nouveaux talents, le modèle des compétences verrouillées.
- Une mesure de la part du clic coup par coup : l'estimation par jalon suffit.

---

## Files

- `tools/simulate_progress.gd`, `tools/sim_measures.gd` (créé), `.godot/global_script_class_cache.cfg` (généré, nouvelle classe)
- `tests/unit/tools/sim_measures_test.gd`, `tests/integration/balance/real_data_test.gd` (créés)
- `assets/data/balance_notes.md`

## QA Test Cases

*Liste de jalons vide, valeur invalide, doublons, ordre quelconque ; aucun compagnon abordable ; égalité de ratio ; aucun dégât.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tools/sim_measures_test.gd`, `tests/integration/balance/real_data_test.gd`.

**Status**: [x] Created: `tests/unit/tools/sim_measures_test.gd`, `tests/integration/balance/real_data_test.gd`

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-013-companion-touch-ups.md`
- Unlocks: stories de la refonte de l'économie

---

## Completion Notes
**Completed**: 2026-11-02
**Criteria**: 8/8 passing
**Deviations**: `--report=1` sans test automatique (essai manuel) ; « sortie identique » comparée à la main, à refaire à chaque story touchant le simulateur ; références 72 h dépendantes du calendrier de retours ; `.godot/global_script_class_cache.cfg` modifié (généré) à commiter avec la story
**Test Evidence**: `tests/unit/tools/sim_measures_test.gd`, `tests/integration/balance/real_data_test.gd` (écrits, bien que dispensés au niveau minimal)
**Reviewed by**: self, no independent review
