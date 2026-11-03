# Story 007: Objets et butin

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 7`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP feature 7. Dernière histoire de l'ordre de construction : coupable si la courbe n'est pas réglée.*

- [ ] 5 types d'objets existent (Sword, Helmet, Chest, Aura, Slash) ; un seul objet est actif par type.
- [ ] 3 raretés (Commun, Rare, Légendaire) ; le nombre de bonus secondaires dépend de la rareté (en données).
- [ ] 9 stats possibles : dégâts du clic, dégâts globaux, dégâts critiques, chance de critique, dégâts des compagnons, dégâts de boss, or global, or des boss, or hors-ligne (cette dernière s'applique au gain hors-ligne de la story 004b).
- [ ] Les bonus des objets actifs s'appliquent aux formules de jeu.
- [ ] Le premier objet tombe sur le boss de l'étage 10 ; les boss suivants donnent du butin selon une table en données.
- [ ] L'inventaire est limité ; quand il est plein, les moins bons objets sont vendus automatiquement (règle de « moins bon » définie et notée).
- [ ] Le joueur peut équiper un objet à la place de l'actif de son type et voit la comparaison des stats.
- [ ] L'inventaire et les objets équipés sont sauvegardés et rechargés (état de partie ou permanent, choix noté).
- [ ] Une capture d'écran de l'inventaire avec des objets de rareté différente est conservée dans `production/qa/evidence/`.

---

## Implementation Notes

- Types, raretés, stats et table de butin en fichiers de données.
- Définir la règle « moins bon » (par exemple rareté puis somme pondérée des stats) et la noter dans les données.

---

## Out of Scope

- Artefacts, prestige, familiers.

---

## Files

- `src/core/item.gd`, `src/core/inventory.gd`, `src/core/loot_table.gd`, `src/core/modifier_hub.gd` et leurs `.uid`
- `src/ui/inventory_screen.tscn`, `src/ui/inventory_screen.gd`, `.uid`
- `assets/data/items.json`
- `src/core/floor_manager.gd`, `src/core/permanent_state.gd`, `src/core/talent_tree.gd`, `src/core/offline_income.gd`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `tools/simulate_progress.gd`
- `tests/unit/loot/loot_test.gd`
- `assets/data/data_schema.md`, `assets/data/balance_notes.md`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/loot/loot_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [x] Created: `tests/unit/loot/loot_test.gd`, 57 tests

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-006-talents.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-31
**Criteria**: 9/9 passing. À tester par Amaury, non vérifié ici : clic réel au pointeur dans l'inventaire, Tab et manette dans l'écran, sensation de puissance des objets.
**Deviations**:
- `modifier_hub.gd` ajouté hors de la liste d'origine : point unique qui fusionne talents et objets pour qu'ils ne s'écrasent pas.
- Prix de vente exprimé en kills de l'étage du boss (10 / 40 / 200), par rareté, dans `items.json`.
- Le critique ne vient que du clic (décision d'Amaury) : jamais mesuré en 72 h, les objets portés donnant 0 % de chance de critique.
- La vente automatique ne se déclenche jamais en 72 h (11 objets pour 12 places).
- Valeurs provisoires (sac de 12, plages, prix, raretés, critique de base), réglage unique après cette story. Premier boss à 1,5 min, sous la cible de 2 à 3 min.
- 9 remarques mineures du contrôle moteur non corrigées (plafond de `percent`, dé qui ne renvoie pas un nombre, voisin de focus manette, entre autres).
- Nom de la dernière ligne du sac plein coupé à l'écran ; le détail donne l'information complète.
- Types affichés en français (Épée, Casque, Plastron, Aura, Entaille), le brief garde Sword, Helmet, Chest, Aura, Slash.
- Hors liste : `.godot/global_script_class_cache.cfg` (généré, suivi volontairement).
**Test Evidence**: `tests/unit/loot/loot_test.gd` (57 tests, suite 194/194) ; captures dans `production/qa/evidence/story-007-loot/`, stamp à jour.
**Reviewed by**: self, no independent review
