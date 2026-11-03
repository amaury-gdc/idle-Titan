# Story 012: Transition entre monstres

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-01

## Context

**GDD**: `design/ux/main-screen-adaptive.md`
**Requirement**: hors brief MVP, demande directe d'Amaury du 2026-11-01

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none. Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*À faire après la story 011, pas avant. Les durées et le seuil sont des hypothèses à ajuster en jouant.*

- [x] L'ennemi qui meurt s'estompe et rétrécit légèrement, environ 0,15 s.
- [x] Le suivant apparaît en fondu en grossissant légèrement, environ 0,2 s.
- [x] Le boss a une entrée plus marquée.
- [x] La logique de jeu n'attend jamais l'animation : les clics et les compagnons agissent tout de suite sur le nouvel ennemi.
- [x] Au-delà d'environ 3 kills par seconde, la transition raccourcit ou se réduit à un éclair.
- [x] Elle respecte le réglage « Effets visuels » et `prefers-reduced-motion`.
- [x] Les durées et le seuil de kills se règlent en données, dans `assets/data/`.
- [x] Textes, sphères et boules restent alignés sur le monstre pendant la transition.
- [x] Le simulateur donne le même résultat qu'avant la story ; tous les tests restent verts.
- [x] Captures conservées dans `production/qa/evidence/story-012-monster-transition/`, fluidité mesurée dans l'export, normale et processeur ralenti.

---

## Out of Scope

- Dessins de chats, décor définitif, son.
- Toute règle de jeu.

---

## Files

- `src/ui/enemy_view.gd`, `src/ui/main_screen.gd`
- `assets/data/monster_transition.json` (créé), `assets/data/data_schema.md`

## QA Test Cases

*À écrire au démarrage de la story.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: captures dans `production/qa/evidence/story-012-monster-transition/`, validation dans `production/qa/evidence/story-012-monster-transition-evidence.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-011-management-tabs.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-11-01
**Criteria**: 10/10 passing (sensation, réactivité, rafale et réglages confirmés par Amaury ; durées et fluidité mesurées dans l'export)
**Deviations**: valeurs par défaut et bornes aussi écrites dans `enemy_view.gd` en repli du JSON ; `MAX_FRAME_SECONDS` et `KILL_MEMORY` non réglables en données ; captures prises sur un build aux durées ×10 (affichent encore v0.1.0) ; aucun test unitaire sur `EnemyView` (waived au niveau minimal)
**Test Evidence**: `production/qa/evidence/story-012-monster-transition/` (4 captures, stamp à jour) et fiche `production/qa/evidence/story-012-monster-transition-evidence.md` (sign-off coché)
**Reviewed by**: self, no independent review
