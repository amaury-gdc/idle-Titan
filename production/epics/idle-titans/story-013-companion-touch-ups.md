# Story 013: Retouches compagnons

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-01

## Context

**GDD**: `design/ux/main-screen-adaptive.md`
**Requirement**: hors brief MVP, demande directe d'Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none. Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*Règle réelle des paliers, dans `companions_roster.json` : 10, 25, 50 (×2), 100, 150, 200 (×3), cumulés. Le code lit les données et ne suppose aucun rythme.*

**Bouton d'achat**

- [x] Le bouton n'affiche plus « manque X » : seulement le coût, grisé tant qu'il n'est pas achetable.
- [x] L'état non achetable reste distinguable sans la couleur : seul le bouton achetable a une bordure épaisse, vérifié par un test.

**Prochain palier**

- [x] Chaque ligne affiche « Palier niv. N : ×X », lus dans les données, avec une petite barre de progression qui va du palier précédent au prochain.
- [x] Après le dernier palier : « Tous les paliers atteints », barre pleine.
- [x] La barre a un équivalent texte : le niveau et le palier sont imprimés, la couleur n'est jamais seule.

**Option Palier**

- [x] Le sélecteur propose x1 / x10 / Max / Palier ; le choix est conservé hors sauvegarde.
- [x] Palier achète exactement jusqu'au prochain palier, tout ou rien, et dépense la somme exacte des achats simples.
- [x] Le bouton affiche le vrai nombre de niveaux et ce qu'une pression achète.
- [x] Après le dernier palier, en mode Palier, le bouton est désactivé.

**Contrôle**

- [x] Textes coupés, mots coupés, cibles de 44 px, texte de 14 px, chevauchements et débordements contrôlés automatiquement dans l'export, sur toutes les tailles de la story 011, avec les nombres les plus longs.
- [x] Le simulateur donne le même résultat ; sauvegardes inchangées ; tous les tests restent verts.
- [x] Captures conservées dans `production/qa/evidence/story-013-companion-touch-ups/`.

---

## Out of Scope

- Toute règle de jeu, tout changement des paliers.
- Détail DPS, onglets Objets et Talents.

---

## Files

- `src/core/companion.gd`, `companion_manager.gd`, `display_settings.gd`
- `src/ui/buy_quote.gd`, `companion_panel.gd/.tscn`, `main_theme.tres`
- `tests/unit/core-loop/companion_next_tier_test.gd`, `tests/unit/ui/buy_quote_tier_test.gd`, `companion_panel_tier_test.gd` (créés)
- `tests/unit/ui/buy_quote_test.gd`, `companion_cost_text_test.gd`, `companion_panel_press_test.gd`, `display_choices_test.gd`, `main_theme_contrast_test.gd`
- `design/ux/main-screen-adaptive.md`

## QA Test Cases

*Cas limites : niveau 0, niveau égal à un palier, dernier palier, entre deux paliers, compagnon sans palier, or exact, or insuffisant d'une unité.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures conservées dans `production/qa/evidence/story-013-companion-touch-ups/`.

**Status**: [x] Created: captures dans `production/qa/evidence/story-013-companion-touch-ups/`

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-011-management-tabs.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-11-01
**Criteria**: 12/12 passing (comportement de l'achat Palier, conservation du mode et lisibilité confirmés par Amaury)
**Deviations**: barre à droite du texte de palier et non dessous ; mémo dans `Companion.cost_of_levels_from` (valeur exacte, simulateur identique) ; marges de liste réduites dans l'onglet Compagnons (4 lignes au lieu de 5 sur 390x844, 7 au lieu de 8 sur 1280x720, seuil de 2 lignes à 320x568 atteint sans marge) ; couleurs de la barre prises dans les jetons sans avis de la direction artistique
**Test Evidence**: `production/qa/evidence/story-013-companion-touch-ups/` (108 captures, stamp à jour)
**Reviewed by**: self, no independent review
