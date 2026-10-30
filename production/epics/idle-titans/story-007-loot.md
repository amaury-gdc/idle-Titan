# Story 007: Objets et butin

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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
- [ ] 9 stats possibles : dégâts du clic, dégâts globaux, dégâts critiques, chance de critique, dégâts des compagnons, dégâts de boss, or global, or des boss, or hors-ligne (cette dernière est définie mais sans effet tant que le hors-ligne n'existe pas).
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
- Effet de la stat « or hors-ligne » (hors-ligne hors périmètre V1).

---

## Files

- `src/core/item.gd`, `src/core/inventory.gd`, `src/core/loot_table.gd`
- `src/ui/inventory_screen.tscn`, `src/ui/inventory_screen.gd`
- `assets/data/items.json`
- `tests/unit/loot/loot_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais la capture d'écran conservée ne l'est pas.*

**Story Type**: Logic
**Required evidence**: `tests/unit/loot/loot_test.gd` (facultatif) ; capture d'écran conservée dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-006-talents.md`
- Unlocks: None
