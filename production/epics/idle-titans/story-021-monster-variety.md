# Story 021: Variété des monstres

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: `design/monster-variety.md`
**Requirement**: hors brief MVP, demande directe d'Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Cette story fait entrer la toute première texture du jeu dans l'export. Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*Indépendante de l'économie : elle peut démarrer dès la fin de la story 017.*

**Tirage et données**

- [ ] `monster_appearances.json` est validé : repli et avertissement sur défaut, test bloquant sur le fichier réel.
- [ ] Le tirage ne répète jamais l'ennemi affiché, liste correcte par étage et par zone, boss fixé par zone, testé sans aléa.
- [ ] Cadence : apparence et nom changent au plus toutes les 0,6 s, avec ou sans Effets visuels, horloge injectée.

**Cosmétique**

- [ ] PV, or, dégâts, butin, zone de clic et sauvegarde sont inchangés, prouvés par un scénario jumeau vu en échec avant d'être cru.
- [ ] Le générateur est séparé, le simulateur donne la même sortie avec `--loot=1` sur 2 graines.

**Rendu**

- [ ] Au moins 6 variantes dessinées par le code, reconnaissables sans la couleur, boss en médaillon.
- [ ] Le fantôme garde son apparence ; l'ancre reste immobile, déplacement 0,00, y compris image vers dessin.
- [ ] Le nom s'affiche sous la barre de vie, entier à 844x390, 2 lignes de compagnons conservées à 320x568, calculées et non en dur.

**Dessins**

- [ ] Une image test fournie par le code est prouvée dans l'export par une capture à l'écran et un témoin négatif, dans un clone jetable.
- [ ] Poids du téléchargement mesuré avant et après, brut et gzip.

**Contrôle**

- [ ] Textes coupés, 44 px, 14 px, débordements contrôlés dans l'export sur 18 tailles, avec le nom le plus long.
- [ ] Fluidité dans l'export : au moins 59 images/s, pire image 33,4 ms ; processeur ×4 au moins 40 au premier passage, puis 55, référence remesurée le même jour.
- [ ] Captures dans `production/qa/evidence/story-021-monster-variety/`, tests verts, sensation validée par Amaury dans `production/qa/evidence/story-021-monster-variety-evidence.md`.

---

## Out of Scope

- Dessins définitifs, bestiaire, message « nouveau monstre », marque de cycle.
- Toute règle de jeu.

---

## Files

- À remplir à la fin.

## QA Test Cases

*Liste à 1 ou 2 éléments, liste vide, changement de zone, reprise de sauvegarde, abandon de boss, farm, plusieurs kills dans une image, dé à 0,0 et 1,0.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `tests/unit/monsters/monster_catalog_test.gd`, captures et fiche dans `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-017-awakening-ui.md`
- Unlocks: None

---
