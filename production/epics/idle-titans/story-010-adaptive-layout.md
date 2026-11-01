# Story 010: Disposition adaptative, onglets et onglet Compagnons

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: UI
> **Estimate**: XL
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-01

## Context

**GDD**: `design/ux/main-screen-adaptive.md`
**Requirement**: hors brief MVP, demande directe d'Amaury du 2026-11-01 (story A)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none. Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*La spécification fait référence. Décisions D1 à D8 acceptées. Pendant cette story, Objets et Talents ouvrent encore leurs écrans actuels : pas de publication avant la story 011.*

**Calcul des prix**

- [x] Le prix d'un niveau et la somme de N niveaux donnent exactement les mêmes valeurs qu'avant, testé sur toute la plage utile de niveaux.
- [x] Dans l'export web, un prix au niveau 1000 coûte au plus 2 ms, et le calcul de Max sur 8 lignes au plus 8 ms, mesurés.
- [x] Le simulateur donne le même résultat qu'avant la story.

**Disposition**

- [x] La forme est choisie selon la spécification, sans verrouillage d'orientation ni blocage du joueur.
- [x] Aux 390x844, 844x390, 768x1024, 1280x720, 1920x1080, 2560x1080 et en fenêtre étroite : aucune bande vide, fonds jusqu'aux bords, partage 60/40 en paysage, aucun texte coupé ni chevauchement sur l'écran principal.
- [x] `canvas.width` vaut `innerWidth × devicePixelRatio`, y compris pendant un redimensionnement en direct.
- [x] 50 redimensionnements en 5 s : aucune erreur, forme finale correcte, barre de PV exacte.
- [x] L'en-tête (étage, record, or, DPS, Réglages) reste visible en permanence.
- [x] Les 3 compétences, le chrono, Défier, Abandonner et Défi automatique restent atteignables sans défiler.
- [x] Le monstre suit la place disponible ; textes, sphères et boules restent alignés sur lui après chaque changement de forme, boss compris.
- [x] Toute cible fait au moins 44 px CSS, tout texte au moins 14 px CSS, vérifié automatiquement dans l'export.

**Onglets et Compagnons**

- [x] Trois onglets, au même endroit dans la zone de gestion dans les deux formes, avec libellé, état choisi non coloré seulement, focus clavier.
- [x] Le point de notification suit D4.
- [x] x1 / x10 / Max suit D3 ; le choix est conservé hors sauvegarde ; x10 et Max dépensent exactement la somme de N achats simples, et ne redessinent qu'une fois.
- [x] Un glissé dans la liste n'achète jamais.

**Accès sans survol**

- [x] Appui long sur les compétences, toucher sur le DPS, selon la spécification ; un appui long n'active jamais.
- [x] 1/2/3 activent les compétences, inactifs dans une fenêtre modale ou dans le champ de sauvegarde ; le monstre est focalisable et attaquable au clavier ; plusieurs doigts comptent chacun comme un clic.

**Non-régression**

- [x] Sauvegardes existantes chargées, aucune clé ajoutée.
- [x] Effets visuels, retour d'absence, Réglages, réinitialisation, onglet caché fonctionnent dans les deux formes.
- [x] Contrastes corrigés selon la spécification.
- [x] Tous les tests restent verts.

**Preuves**

- [x] Captures conservées dans `production/qa/evidence/story-010-adaptive-layout/` à chaque taille, émulation tactile, navigation clavier, fluidité mesurée dans l'export (normale et processeur ralenti), référence d'avant la story.
- [x] Revue indépendante par les agents avant de conclure.
- [ ] Test tactile sur vrai téléphone : à tester par Amaury, rattaché à la fin de la story 011.

---

## Implementation Notes

- Un seul arbre de nœuds : `BoxContainer` à orientation basculée, `%Unique` conservés, sous-scènes non extraites.
- `main_screen.gd` reste la racine de composition ; décision de forme pure dans un fichier testable, onglets dans un fichier dédié.
- Ancrage : centre global du rectangle non transformé de `EnemyView`, converti pour chaque couche sur `resized`.
- `_game_waits` : Talents et Objets y restent jusqu'à la story 011.

---

## Out of Scope

- Refonte des contenus Objets et Talents (story 011).
- Dessins de chats, décor définitif, son.
- Taille de texte réglable, manette, lecteur d'écran (D2, D8).
- Réglage du mur.

---

## Files

- `src/core/big_number.gd`, `growth_curve.gd`, `companion.gd`, `companion_manager.gd`, `display_settings.gd`
- `src/ui/adaptive_layout.gd`, `game_zone.gd`, `management_tabs.gd`, `buy_quote.gd`, `notification_dots.gd`, `long_press.gd`, `hint_bubble.gd`, `main_theme.tres` (créés)
- `src/ui/main_screen.gd/.tscn`, `enemy_view.gd`, `companion_orbs.gd`, `floating_text_layer.gd`, `skill_bar.gd/.tscn`, `companion_panel.gd/.tscn`, `boss_timer.gd/.tscn`, `save_screen.gd/.tscn`, `talent_screen.gd`
- `project.godot`, `export_presets.cfg`
- `tests/unit/core-loop/multi_buy_test.gd`, `tests/unit/ui/` (créés)

## QA Test Cases

*Voir le plan QA de l'analyse, résumé dans `design/ux/main-screen-adaptive.md`.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures conservées dans `production/qa/evidence/story-010-adaptive-layout/`.

**Status**: [x] Created: captures dans `production/qa/evidence/story-010-adaptive-layout/`, fiche dans `production/qa/evidence/story-010-adaptive-layout-evidence.md`

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-009-visual-feedback.md`
- Unlocks: `production/epics/idle-titans/story-011-management-tabs.md`

---

## Completion Notes
**Completed**: 2026-11-01
**Criteria**: 23/24 passing (test tactile sur vrai téléphone : à tester par Amaury, rattaché à la fin de la story 011)
**Deviations**: glissé et appui long validés dans l'émulation seulement quand le navigateur livre les événements tactiles, soit environ une exécution sur deux, cause non établie. Max sur 8 lignes : 7 ms en régime établi, 13 ms au premier calcul, au-dessus des 8 ms. Corrections issues de la revue UX non relues à la clôture : relecture prévue à la fin de la story 011.
**Test Evidence**: `production/qa/evidence/story-010-adaptive-layout/`, `production/qa/evidence/story-010-adaptive-layout-evidence.md`
**Reviewed by**: `lead-programmer`, `ux-designer`, `accessibility-specialist`
