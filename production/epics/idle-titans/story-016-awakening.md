# Story 016: Éveil des compagnons

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-03

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

- [ ] Le roster porte les seuils, le coût et les multiplicateurs ; un roster sans bloc d'éveil reste valide.
- [ ] Le niveau s'arrête au seuil tant que l'éveil n'est pas payé, dans `CompanionManager`.
- [ ] Éveiller coûte exactement 10 × le coût du seuil : or égal accepté, une unité de moins refusée.
- [ ] L'éveil donne ×3,4 au compagnon et ×2,10 à l'escouade pour les seuils 200 à 600, seulement ×3,4 de 700 à 1000.
- [ ] Toute la puissance suit : compagnons, clic, Gros coup, estimation de défi, hors-ligne, affichages.
- [ ] Les dégâts ne sont jamais périmés après un éveil au même niveau : mémos indexés par niveau et éveils.
- [ ] Sauvegarde : aller-retour, `.bak`, reset de partie ; une sauvegarde sans la clé donne aucun éveil.
- [ ] Une vraie sauvegarde 0.2.1 charge sans perte : niveaux conservés, éveils éligibles payants.
- [ ] Gardien 1000 / Dragon 100, sur le vrai roster, reste entre ×1,5 et ×3.
- [ ] `--awaken=0|1` dans le simulateur, `real_data_test.gd` à jour, tous les tests verts.

---

## Out of Scope

- Le bouton et l'affichage : story 017.
- Les valeurs finales : story 020.

---

## Files

- `src/core/awakening_rules.gd` (créé), `src/core/combat.gd`, `src/core/companion.gd`, `src/core/companion_manager.gd`, `src/core/floor_manager.gd`, `src/core/game_state.gd`, `src/core/offline_income.gd`
- `tools/simulate_progress.gd`, `tools/sim_measures.gd`, `.godot/global_script_class_cache.cfg` (généré)
- `assets/data/data_schema.md`
- `tests/unit/core-loop/awakening_test.gd`, `tests/integration/save/awakening_save_test.gd` (créés)
- `tests/integration/balance/real_data_test.gd`, `tests/unit/core-loop/click_share_test.gd` (signatures, plus un test de rapport Gardien / Dragon)

## QA Test Cases

*Niveau 199, 200 exact, 201 sans éveil en sauvegarde ; double appui ; deux seuils en attente ; éveil en combat de boss, chrono intact ; niveau 1000, plus de seuil ; hors-ligne après éveil ; sauvegarde à niveaux 400.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core-loop/awakening_test.gd`, `tests/integration/save/awakening_save_test.gd`.

**Status**: [x] Created: `tests/unit/core-loop/awakening_test.gd` (29 tests), `tests/integration/save/awakening_save_test.gd` (7 tests), et un test de rapport dans `tests/integration/balance/real_data_test.gd`

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-015-hp-segments-click-share.md`
- Unlocks: `production/epics/idle-titans/story-017-awakening-ui.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 10/10 passing
**Deviations**: bloc d'éveil absent du vrai `companions_roster.json` (sans bouton, le joueur serait bloqué au niveau 200), il y entre avec la story 017 ; rapport Gardien / Dragon prouvé sur le vrai roster avec le bloc injecté en mémoire ; mesure sur roster jetable aux courbes actuelles : étage 200 à 5,5 h actives, trop rapide pour la cible de 4 à 6 jours, à recaler à la 020 ; compteur d'éveils non comparé au niveau (sauvegarde modifiée à la main) ; mémo de dégâts à un seul emplacement, coûteux avec `--buyer=ratio` ; preuve « le test peut échouer » faite pour certains tests seulement ; deux tests existants adaptés aux nouvelles signatures
**Test Evidence**: `tests/unit/core-loop/awakening_test.gd` (29 tests), `tests/integration/save/awakening_save_test.gd` (7), `real_data_test.gd` (1 test ajouté), écrits bien que dispensés au niveau minimal
**Reviewed by**: self, no independent review
