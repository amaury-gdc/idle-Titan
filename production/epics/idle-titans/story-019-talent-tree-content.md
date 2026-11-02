# Story 019: Arbre v2, effets, contenu et écran

> **Epic**: Idle Titans (MVP)
> **Status**: In Progress
> **Layer**: Feature
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/talent-tree-v2.md`
**Requirement**: hors brief MVP, refonte de l'arbre demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] Chaque effet neuf agit, testé et modélisé dans le simulateur : Frappe alliée, Rythme, Sursis, Cadence, Synergie, Champion, Flair, Négociation, Longue veille, Moisson.
- [ ] Rythme respecte 5 s minimum entre deux déclenchements, et son compteur n'est pas sauvegardé.
- [ ] Instinct garde le bouton à sa place, marqué « Passif », et les touches 1/2/3 ne bougent pas.
- [ ] `talents.json` réel contient les 30 nœuds ; un test le déclare valide et chaque palier atteignable.
- [ ] Une compétence à débloquer garde son bouton, « À débloquer » ; le toucher ouvre sa fiche, la touche affiche une bulle.
- [ ] L'écran montre paliers, sommets, fiche avant → après, tous les états sans couleur seule, et le message de version.
- [ ] Sous-onglets en grille de 2 tuiles sur téléphone, trois colonnes quand elles tiennent, bandeau de détail dès 560 u.
- [ ] L'écran refuse le reset pendant un combat de boss : il passe par `TalentTree.try_reset` (avec `FloorManager.is_boss_fight()`), plus par l'ancien `reset()` sans règle ; test qui échoue si l'écran rappelle l'ancien reset.
- [ ] Le décompte d'1 h du reset affiche le temps restant réel dès l'ouverture de l'écran, même après une horloge reculée : jamais figé à 1 h en attendant un premier appui sur Reset ; test avec une date de dernier reset dans le futur.
- [ ] Textes, 44 px, 14 px, chevauchements et débordements contrôlés dans l'export sur 18 tailles, avec les noms les plus longs.
- [ ] Fluidité mesurée dans l'export, onglet ouvert, normale et processeur ×4.
- [ ] Captures dans `production/qa/evidence/story-019-talent-tree-content/`, et tous les tests verts.

---

## Out of Scope

- Le calibrage final : story 020.
- Passifs par compagnon, Combo, niveau d'objet.

---

## Files

- `assets/data/talents.json` (30 nœuds, schéma 2, tree_version 1), `assets/data/data_schema.md`, `design/talent-tree-v2.md` (Négociation hors éveil, 69 points)
- `src/core/talent_tree.gd`, `modifier_hub.gd`, `floor_manager.gd`, `boss_fight.gd`, `combat.gd`, `companion.gd`, `companion_manager.gd`, `offline_income.gd`, `loot_table.gd`, `skill_manager.gd`
- `src/ui/main_screen.gd`, `main_screen.tscn`, `talent_screen.gd`, `skill_bar.gd`, `talent_card_text.gd` (créé)
- `tools/simulate_progress.gd`, `tools/sim_measures.gd`, `.godot/global_script_class_cache.cfg` (généré)
- Tests créés : `tests/unit/talents/talent_effects_test.gd`, `talents_real_file_test.gd`, `talent_hub_test.gd`, `tests/unit/ui/talent_wiring_test.gd`, `talent_screen_v2_test.gd`, `talent_glyphs_test.gd` ; adaptés : `talent_refund_test.gd`, `talent_tree_v2_test.gd`, `talents_test.gd`, `talent_pane_test.gd`

## QA Test Cases

*Première ouverture avec points rendus ; arbre vide ; sommet exclu ; palier fermé ; double toucher à 250 ms ; reset en recharge ; Champion qui change ; Flair à poids Commun nul ; Négociation avec Max et éveil.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures dans `production/qa/evidence/story-019-talent-tree-content/`, tests dans `tests/unit/talents/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-018-talent-tree-format.md`
- Unlocks: `production/epics/idle-titans/story-020-economy-calibration.md`

---
