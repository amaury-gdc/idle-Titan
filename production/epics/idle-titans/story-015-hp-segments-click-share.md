# Story 015: PV par segments et clic par compagnon

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

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

*Le moteur change, les valeurs jouées non : cette story reste neutre pour le joueur.*

- [ ] `core_curves.json` accepte des segments de PV ; l'ancien scalaire reste lu, donc les fixtures ne cassent pas.
- [ ] Les PV sont continus et exacts aux jonctions de segments, par des ancres calculées au chargement.
- [ ] Le roster accepte `click_share` par compagnon, ancien schéma toujours lu.
- [ ] La formule du clic passe par les parts, avec un seul floor, sans talents dans `dps_i`.
- [ ] Avec les données actuelles, `real_data_test.gd` reste vert et le simulateur donne la même sortie, hors « Real time ».
- [ ] Le calcul des PV à l'étage 300 n'est pas plus lent qu'aujourd'hui, mesure notée.
- [ ] `data_schema.md` documente les nouveaux champs, et tous les tests restent verts.

---

## Out of Scope

- Les valeurs de la nouvelle courbe : story 020.
- L'éveil : story 016.

---

## Files

- `src/core/combat.gd`, `src/core/companion.gd`
- `assets/data/data_schema.md`
- `tests/unit/core-loop/hp_segments_test.gd`, `tests/unit/core-loop/click_share_test.gd` (créés)
- `design/economy-rework.md` (note de schéma alignée)

## QA Test Cases

*Jonctions 100/101, 150/151, 190/191 ; boss 200, 210, 300 ; aucun compagnon ; part 0 ; un seul segment ; segments mal ordonnés refusés.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core-loop/hp_segments_test.gd`, `tests/unit/core-loop/click_share_test.gd`.

**Status**: [x] Created: `tests/unit/core-loop/hp_segments_test.gd` (32 tests), `tests/unit/core-loop/click_share_test.gd` (24 tests)

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-014-simulator-measures.md`
- Unlocks: `production/epics/idle-titans/story-016-awakening.md`

---

## Completion Notes
**Completed**: 2026-11-02
**Criteria**: 7/7 passing
**Deviations**: aucune version de schéma ajoutée (champs optionnels lus avec les schémas actuels), la 020 pourra en relever une ; mesure de l'étage 300 faite par un script jetable hors dépôt : 144 µs avant, 145 µs après avec le même scalaire, 46 µs avec 4 segments ; borne de sécurité `from_stage` de 100 000, non liée à l'équilibre
**Test Evidence**: `tests/unit/core-loop/hp_segments_test.gd` (32 tests), `tests/unit/core-loop/click_share_test.gd` (24 tests), écrits bien que dispensés au niveau minimal
**Reviewed by**: self, no independent review
