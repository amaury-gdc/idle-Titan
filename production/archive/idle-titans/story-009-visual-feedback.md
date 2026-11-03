# Story 009: Retours visuels

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-01

## Context

**GDD**: `design/game-brief.md`
**Requirement**: hors brief MVP, demande directe d'Amaury du 2026-10-31

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Consulter `docs/engine-reference/godot/` avant tout appel d'API.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*Critères donnés par Amaury. Les effets sont de l'affichage pur : ils lisent le jeu et ne le modifient jamais.*

**Dégâts**

- [ ] Chaque clic affiche un chiffre de dégâts flottant, égal aux dégâts réellement infligés (buff et critique compris), y compris sur le clic qui tue.
- [ ] Un critique affiche un chiffre plus gros, suivi d'un « ! ».
- [ ] Gros coup affiche un chiffre très gros.
- [ ] Une attaque de compagnon n'affiche aucun chiffre.

**Or**

- [ ] À la mort d'un ennemi ou d'un boss, un texte « + or » doré, égal à l'or réellement gagné, monte en diagonale vers la droite et s'efface.
- [ ] Ce texte est plus gros pour un boss.

**Compagnons**

- [ ] Chaque compagnon acheté apparaît en sphère colorée à côté du monstre, y compris après un rechargement de la partie.
- [ ] À chaque attaque, sa sphère lance une petite boule vers un point d'ancrage au centre du monstre.
- [ ] Le nombre de boules est plafonné par une limite de fréquence indépendante de la logique : une boule non lancée ne change ni le nombre d'attaques ni leurs dégâts.

**Système commun**

- [ ] Un seul système de texte flottant sert aux dégâts et à l'or.
- [ ] Il affiche au plus une douzaine de textes à la fois, avec des objets réutilisés : aucun objet n'est créé ni détruit pendant le jeu. Au-delà de la limite, le texte le plus ancien est repris.
- [ ] Tout texte flottant a un contour sombre.
- [ ] Les textes, sphères et boules ne bloquent aucun clic : le monstre et les boutons restent cliquables à travers eux.
- [ ] Rien n'est animé quand l'onglet est caché, et aucun effet accumulé ne se rejoue au retour.
- [ ] Un réglage « Effets visuels », activé par défaut, coupe les trois effets. Il prend effet immédiatement et est conservé au rechargement.
- [ ] Le texte « Critique ! » actuel de l'écran principal disparaît : le chiffre flottant le remplace, pour ne pas montrer le critique deux fois.

**Sans effet sur le jeu**

- [ ] Sur un même scénario et les mêmes dés, les dégâts, l'or et la sauvegarde sont identiques avec le réglage activé ou coupé.
- [ ] Le réglage n'entre ni dans la sauvegarde, ni dans le texte de « Copier ma sauvegarde », et « Réinitialiser ma sauvegarde » ne le touche pas.
- [ ] `tools/simulate_progress.gd` donne les mêmes résultats avant et après la story.

**Preuves**

- [ ] Des captures d'écran sont conservées dans `production/qa/evidence/story-009-visual-feedback/` : chiffres normal, critique et Gros coup ; « + or » d'un ennemi et d'un boss ; sphères et boules avec les 8 compagnons ; réglage coupé.
- [ ] La fluidité est vérifiée dans l'export web, avec les 8 compagnons, des clics rapides et la limite de textes atteinte : images par seconde mesurées avec le réglage activé puis coupé, chiffres notés, en fenêtre normale avec rendu matériel. Cible proposée : au moins 55 images/s et pas d'écart visible entre les deux mesures.

---

## Implementation Notes

- **Dégâts du clic.** `FloorManager.click()` renvoie les dégâts avant buff et critique, et `ClickDpsMeter` en dépend : ne pas changer cette valeur. `enemy_damaged` n'est pas émis sur le coup qui tue. Il faut donc un signal d'affichage dédié, qui porte les dégâts infligés et le critique, émis dans tous les cas. Même besoin pour Gros coup, qui passe par `apply_damage` comme les compagnons et ne s'en distingue pas aujourd'hui.
- **Or.** `enemy_killed` porte déjà la récompense finale. `boss_killed` n'arrive qu'après lui : le système doit savoir que c'est un boss au moment de créer le texte.
- **Boules.** `companion_attacked` existe déjà. Les dégâts tombent à l'attaque, pas à l'arrivée de la boule : la boule ne fait que montrer le coup.
- **Sphères.** Couleur par compagnon en données, dans `companions_roster.json`. Placement à décider sur l'écran : à gauche se trouvent les compétences (x 10 à 200) et le monstre occupe environ x 235 à 485.
- **Réglage.** Il est gardé dans un petit fichier séparé, `user://settings.cfg`, pour tenir la règle « ne modifie pas la sauvegarde » sans changer le schéma de `PermanentState`. L'interrupteur va sur l'écran principal : le panneau « Ma sauvegarde » ne parle que de la sauvegarde.
- **Limites d'affichage.** Taille du pool, durées, tailles de texte et fréquence des boules sont des constantes d'affichage, comme celles de `main_screen.gd`.
- **Onglet caché.** S'appuyer sur l'écouteur `visibilitychange` de `main_screen.gd` : effacer les effets en cours au masquage. Un premier delta très long au retour ne doit pas lancer une rafale de boules.
- **Chemin critique.** Pas d'allocation par image, pas de recherche dans l'arbre de scène : pool créé au démarrage. Regrouper les boules dans un seul dessin plutôt qu'un nœud par boule si la mesure le demande.

---

## Out of Scope

- Son, particules, secousse d'écran, animation du monstre.
- Chiffres de dégâts pour Frénésie, Bonus d'or ou les compagnons.
- Écran de réglages complet : un seul interrupteur.
- Réglage du mur et de l'équilibrage.

---

## Files

- `src/core/display_settings.gd` (créé), `.uid`
- `src/ui/floating_text_layer.gd` (créé), `.uid`
- `src/ui/companion_orbs.gd` (créé), `.uid`
- `src/core/floor_manager.gd`, `src/core/skill_manager.gd`
- `src/ui/main_screen.gd`, `src/ui/main_screen.tscn`
- `assets/data/companions_roster.json`, `assets/data/data_schema.md`
- `tests/unit/visual-feedback/visual_feedback_test.gd` (créé, 40 tests)
- `.godot/global_script_class_cache.cfg` (mis à jour par Godot, versionné)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal` : tests facultatifs, mais les captures conservées ne le sont pas. Une story Visual/Feel demande aussi une validation : `production/qa/evidence/story-009-visual-feedback-evidence.md`, approuvée par Amaury après avoir joué, car une capture ne montre pas la sensation.*

**Story Type**: Visual/Feel
**Required evidence**: captures dans `production/qa/evidence/story-009-visual-feedback/` et validation dans `production/qa/evidence/story-009-visual-feedback-evidence.md`. Tests recommandés dans `tests/unit/visual-feedback/` : limite de 12 et réutilisation du pool, limite de fréquence, résultats identiques réglage activé ou coupé.

**Status**: [x] Created: `tests/unit/visual-feedback/visual_feedback_test.gd`, 40 tests ; captures dans `production/qa/evidence/story-009-visual-feedback/` ; validation d'Amaury à faire

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-007-loot.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-11-01
**Criteria**: 21/21 passing (sensation validée par Amaury : « c'est parfait »)
**Deviations**: Advisory :
1. « Réinitialiser ma sauvegarde » ne touche pas le réglage : vu une seule fois par l'agent dans un essai jetable, pas de test conservé (le réglage est dans `user://settings.cfg`, hors des fichiers de sauvegarde).
2. Des textes se superposent et deviennent illisibles quand plusieurs morts ou clics tombent ensemble (captures 09 et 11).
3. Processeur ralenti six fois : le premier passage avec effets tombe à 50 images/s, avec une image de 150 ms ; cause non prouvée, aucune machine modeste réelle mesurée.
4. Onglet caché vu seulement dans Edge headless ; bouton « Effets visuels » essayé seulement à la souris.
5. Remarques mineures du contrôle moteur : enum `HitSource` mal placée dans `floor_manager.gd`, redessin des sphères pendant qu'une boule vole, aspect du fondu avec contour, focus gardé par le bouton.
Hors périmètre : `EPIC.md` et la fiche de preuves absents de `## Files`. `_roll_critical` devient `_rolls_critical` (mêmes conditions de tirage). `.godot/global_script_class_cache.cfg` mis à jour par Godot.
**Test Evidence**: `tests/unit/visual-feedback/visual_feedback_test.gd` (40 tests, suite 246/246) ; 13 captures dans `production/qa/evidence/story-009-visual-feedback/`, stamp à jour ; validation dans `production/qa/evidence/story-009-visual-feedback-evidence.md`.
**Reviewed by**: self, no independent review
