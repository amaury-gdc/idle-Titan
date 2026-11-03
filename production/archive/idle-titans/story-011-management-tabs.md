# Story 011: Onglets Objets et Talents

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-01

## Context

**GDD**: `design/ux/main-screen-adaptive.md`
**Requirement**: hors brief MVP, demande directe d'Amaury du 2026-11-01 (story B)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none. Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [x] L'inventaire et l'arbre de talents sont le contenu de leurs onglets, plus des écrans plein écran.
- [x] D1 : le jeu, le chrono de boss et les effets continuent avec Objets ou Talents ouvert ; seuls Réglages et le retour d'absence font attendre.
- [x] D5 : un toucher ouvre le détail, avec Retour et action fixe ; confirmation avant la remise à zéro des talents.
- [x] Sous 640 u de largeur, le détail remplace la liste et l'arbre montre une branche à la fois ; à partir de 640 u, liste et détail côte à côte ; arbre complet si le panneau fait aussi 480 u de haut, avec le détail en bande sous lui.
- [x] Aucune information au survol seul : « Requiert : X » imprimé sur les nœuds verrouillés, comparaison lisible au tactile.
- [x] Butin reçu avec Objets ouvert : liste à jour, sélection et défilement conservés.
- [x] Le retour d'absence ne ferme plus d'onglet.
- [x] Changement de forme : onglet, détail, branche, défilement et focus conservés.
- [x] Focus : Échap revient en arrière, aucun focus perdu quand un bouton se désactive ou disparaît.
- [x] Plus de `focus_behavior_recursive` désactivé pour ces écrans ; ils n'échappent pas au modal Réglages.
- [x] Toute cible fait au moins 44 px CSS, tout texte au moins 14 px CSS, aucun texte coupé ni chevauchement, vérifié automatiquement, y compris sac plein et arbre complet.
- [x] Aucun débordement horizontal, ni dans les onglets ni ailleurs, de 320 à 2560 px de large.
- [x] L'arbre de talents défile verticalement en portrait, sans colonnes fixes.
- [x] Le contrôle automatique des textes coupés, des chevauchements et des cibles de 44 px couvre aussi les onglets Objets et Talents, y compris le détail d'un objet et d'un talent.
- [x] Quand les ennemis meurent très vite, les « + or » fusionnent en un seul texte flottant, somme sur environ 0,3 s, sans superposition.
- [x] Sauvegardes existantes chargées, aucune clé ajoutée ; tous les tests restent verts.
- [x] Captures conservées dans `production/qa/evidence/story-011-management-tabs/` à chaque taille, émulation tactile, navigation clavier, fluidité mesurée dans l'export.
- [x] Revue indépendante par les agents avant de conclure.
- [x] Corrections issues de la revue UX relues par un agent différent de celui qui les a faites.
- [x] Test tactile sur vrai téléphone, repris de la story 010 : à tester par Amaury.

---

## Out of Scope

- Nouvelles règles d'objets ou de talents.
- Dessins de chats, décor définitif, son.

---

## Files

- `src/ui/pane_focus.gd` (créé)
- `src/ui/talent_screen.gd/.tscn`, `inventory_screen.gd/.tscn`, `management_tabs.gd`, `main_screen.gd/.tscn`, `main_theme.tres`, `companion_panel.gd`, `notification_dots.gd`, `floating_text_layer.gd`, `save_screen.gd`
- `src/core/display_settings.gd`, `assets/data/items.json` (libellé « Dégâts de clic »), `project.godot` (nom Catitans)
- `tests/unit/ui/inventory_pane_test.gd`, `talent_pane_test.gd`, `floating_text_gold_merge_test.gd`, `companion_cost_text_test.gd`, `management_tabs_test.gd` (créés)
- `tests/unit/ui/main_theme_contrast_test.gd`, `notification_dots_test.gd`, `companion_panel_press_test.gd`, `tests/unit/talents/talents_test.gd`, `tests/unit/visual-feedback/visual_feedback_test.gd`
- `design/ux/main-screen-adaptive.md`, `CLAUDE.md` (règle d'écriture)

## QA Test Cases

*Voir le plan QA de l'analyse.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures conservées dans `production/qa/evidence/story-011-management-tabs/`.

**Status**: [x] Created: captures dans `production/qa/evidence/story-011-management-tabs/`, fiche dans `production/qa/evidence/story-011-management-tabs-evidence.md`

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-010-adaptive-layout.md`
- Unlocks: `production/epics/idle-titans/story-012-monster-transition.md`

---

## Completion Notes
**Completed**: 2026-11-01
**Criteria**: 21/21 passing. Le test tactile sur vrai téléphone est attesté par Amaury, sans preuve conservée ; il couvre aussi celui de la story 010.
**Deviations**: détail de talent en bande sous l'arbre en mode large ; corps de texte à 16 u en paysage dans Objets et Talents ; sac plein sur téléphone, le message de butin ne nomme plus l'objet ; simulateur non relancé après les dernières modifications de l'interface (aucun fichier de `src/core/` modifié depuis). Décisions encore ouvertes : couleurs des talents, publication.
**Test Evidence**: `production/qa/evidence/story-011-management-tabs/`, `production/qa/evidence/story-011-management-tabs-evidence.md`
**Reviewed by**: `ux-designer`, `godot-gdscript-specialist`, `lead-programmer` (rapport partiel), hors des portes de revue, désactivées en mode solo
