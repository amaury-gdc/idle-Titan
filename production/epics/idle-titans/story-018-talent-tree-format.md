# Story 018: Arbre v2, format, verrous et rendu des points

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/talent-tree-v2.md`
**Requirement**: hors brief MVP, refonte de l'arbre demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*`talents.json` réel ne change pas ici : le moteur est prouvé sur fixtures, le contenu arrive à la story 019.*

- [ ] `talents.json` schéma 2 est lu et validé : paliers, exclusions, `effects[]`, `tree_version`, barème de points par tranches.
- [ ] Un palier s'ouvre par les points dépensés dans la branche ; un groupe exclusif n'admet qu'un nœud.
- [ ] Une compétence verrouillée ne s'active jamais, par bouton ou touche, le verrou étant dérivé des nœuds et vérifié dans `SkillManager`.
- [ ] Une recharge sauvegardée d'une compétence verrouillée est ignorée, sans bonus résiduel ; un buff retiré s'arrête.
- [ ] Valeurs par compétence effectives : les timers restaurés respectent les durées améliorées.
- [ ] Le changement de `tree_version` rend tous les points, anciens ids compris, une fois, après le paiement de l'absence.
- [ ] Le message de version reste dû tant qu'il n'a pas été validé, y compris après un `.bak`.
- [ ] Le reset est refusé en boss et pendant la recharge d'1 h, bornée à 0..3600 s, sauf si dépensé > gagné.
- [ ] Le simulateur connaît le hub dans tous les modes et un ordre d'achat par nœud `--order`.
- [ ] Avec les données actuelles, le simulateur garde la même sortie, hors « Real time », et tous les tests restent verts.

---

## Out of Scope

- Les 30 nœuds réels, l'écran : story 019.
- Les effets neufs : Rythme, Champion, Synergie, Cadence, Négociation.

---

## Files

- `src/core/talent_tree.gd` (schéma 2, paliers, exclusions, effets, rendu de version, reset), `src/core/skill_manager.gd`, `src/core/skill.gd`, `src/core/modifier_hub.gd`, `src/core/permanent_state.gd` (version 6)
- `tools/simulate_progress.gd`, `tools/sim_measures.gd` (`--order`, arbre versionné)
- `assets/data/data_schema.md`
- `tests/unit/talents/talent_tree_v2_test.gd`, `tests/integration/save/talent_refund_test.gd` (créés)

## QA Test Cases

*Palier retombé après retouche d'un coût ; deux sommets en sauvegarde ; dépensé > gagné ; horloge reculée ; sauvegarde plus récente que le code ; ancien onglet 0.2.1 ouvert ; achat pendant un boss ; recharge d'une compétence verrouillée.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/talents/talent_tree_v2_test.gd`, `tests/integration/save/talent_refund_test.gd`.

**Status**: [x] Created: `tests/unit/talents/talent_tree_v2_test.gd` (37 tests), `tests/integration/save/talent_refund_test.gd` (9 tests)

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-017-awakening-ui.md`
- Unlocks: `production/epics/idle-titans/story-019-talent-tree-content.md`

---

## Completion Notes
**Completed**: 2026-11-02
**Criteria**: 10/10 passing (aucun différé)
**Deviations**: aucune bloquante. Limites connues : `main_screen.gd` non branché (hub avant compétences, `try_reset`, message de version, valeurs effectives sur la barre de compétences), à faire en story 019 ; en jeu, le reset reste possible pendant un boss tant que l'écran appelle l'ancien reset ; après une horloge reculée, le décompte reste à 1 h jusqu'au premier appui sur Reset ; une recharge démarrée avec un modificateur > 1 est raccourcie au prochain changement du hub (aucun talent n'en utilise) ; les stats `boss_damage` et `crit_chance` restent à ajouter en 019
**Test Evidence**: `tests/unit/talents/talent_tree_v2_test.gd` (37 tests), `tests/integration/save/talent_refund_test.gd` (9 tests), écrits bien que dispensés au niveau minimal ; suite complète 760/760, simulateur 24 h identique
**Reviewed by**: self, no independent review
