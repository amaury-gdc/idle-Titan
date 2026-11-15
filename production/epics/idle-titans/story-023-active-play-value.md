# Story 023: Valeur du jeu actif

> **Epic**: Idle Titans (MVP)
> **Status**: Complete (2026-11-15), avec écarts acceptés : seuil 1 et part du build Clic, voir « Écarts connus »
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-15

## Context

**GDD**: `design/economy-rework.md`
**Requirement**: hors brief MVP, demandé par Amaury à la clôture des mesures de la story 020

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Problème mesuré (story 020, `assets/data/balance_notes.md`, section « Economy calibration »)

Jouer activement pèse peu sur la progression, de deux façons.

**1. La part du clic est sous les cibles de `design/economy-rework.md`.**

| Mesure (profil de référence, graine 1) | Mesuré | Cible |
|---|---|---|
| Sans talents, 3 clics/s, au milieu (étages 50 à 150) | 24 % | environ 40 % |
| Sans talents, 3 clics/s, à l'étage 200 | 22 % | 10 à 20 % |
| Build Clic, 3 clics/s, à l'étage 200 | 32 % | 40 à 60 % |
| Build Compagnons (référence), à l'étage 200, 3 clics/s | 17 % | — |
| Build Compagnons (référence), à l'étage 200, 1 clic/s | 7 % | — |

Les courbes de PV ne changent pas la part du clic. Les leviers sont les talents de la branche Clic et `click_companion_power_factor` ; la story 020 n'y a pas touché.

**2. L'étage 200 est toujours payé par l'or du retour.**

Les temps d'arrivée aux étages hauts se calent sur les retours d'absence : étage 200 à 8,0 h actives pile dans cinq mesures sur six, étage 210 à 12,0 h, étage 220 juste après un retour. Entre deux retours, la session active n'avance presque plus : le joueur attend 8 à 12 jours devant le boss de l'étage 210, puis passe les étages 211 à 220 en une minute. Passer de 1 à 3 clics/s ne fait gagner qu'un jour sur l'étage 200 (jour 6 contre jour 5).

---

## Acceptance Criteria

*À préciser avec Amaury au démarrage : les cibles ci-dessous reprennent celles de `design/economy-rework.md`.*

- [x] Part du clic sans talents à 3 clics/s : environ 40 % au milieu, 10 à 20 % à l'étage 200. *Mesuré : 48 % à l'étage 50, 31 % à 100, 18 % à 200. Tenu à 200 ; 31 % à l'étage 100 est un écart accepté.*
- [ ] Un build Clic atteint 40 à 60 % à l'étage 200. *NON tenu : 30 %. Cible remplacée par Amaury le 2026-11-15 par le calendrier du build Compagnons ; écart accepté ci-dessous.*
- [ ] Poids de l'or d'absence mesuré et noté : part de l'or du retour dans l'or total dépensé entre les étages 150 et 210, avant et après. *Mesuré avant seulement, par les temps d'arrivée avec `offline_efficiency` à 0,1 / 0,05 / 0 ; pas remesuré après, la piste C n'étant pas faite.*
- [ ] Une session active de 2 h fait avancer le joueur de façon visible après l'étage 190, sans attendre le retour suivant (seuil à fixer avec Amaury). *NON tenu : seuil 1, écart accepté, à rejuger après l'essai des amis.*
- [x] La mesure de référence est relancée après chaque famille de valeurs changée (règle ci-dessous) : étage 200 aux jours 4 à 6, étage 230 non atteint à 40 h actives, pour les deux acheteurs. *Parts de clic : 3 graines, 2 acheteurs. « Frappe alliée » n'est pas dans le build de référence : mesurée sur le build Clic, graines 1 et 2, acheteur le moins cher seulement.*
- [x] Sensibilité et builds de sommet remesurés ; `balance_notes.md` et `real_data_test.gd` à jour ; tous les tests verts. *Suite 1032/1032 le 2026-11-15.*

---

## Décisions d'Amaury et journal

**2026-11-14, démarrage.**
- Seuil 1 : au moins un palier de boss (10 étages) entre 191 et 210 atteint en cours de session, hors des 2 premières minutes après un retour. Départ mesuré : 0 étage sur 30 entre 191 et 220.
- Seuil 2 (poids de l'or d'absence) : chiffre mesuré à chaque étape, pas une cible pour l'instant. Départ : étage 200 à 8,0 h avec l'or d'absence, 14,9 h sans.
- Ordre des pistes : B (parts de clic par compagnon) d'abord ; A (facteur de clic plat) écartée, elle rendrait le mur dépendant de la vitesse de clic ; C (or d'absence) décidée après B.
- Calendrier de la 020 à tenir : étage 200 aux jours 4 à 6, 230 non atteint à 40 h, premier boss vers 9 min. Les taux de PV après 190 ne sont pas touchés.

**2026-11-14 et 15, piste B.**
- Plafond : premier boss à 1 clic/s en 16 min au plus, pour le build de référence ; il passe avant la part du clic du début. 17,1 min sans talents à 1 clic/s : accepté.
- Série retenue (« A3 ») : parts 0,4 / 0,34 / 0,3 / 0,26 / 0,22 / 0,18 / 0,13 / 0,08, base de PV 36, taux 1,3159 dès 1 et 1,3424 dès 100. Premier boss à 7,8 min à 3 clics/s : accepté.
- Message au chargement : `balance_version` 2, texte et seuil par version dans les données, seuil au-dessus du premier boss.
- Simulateur : `--talents=2` ajouté (arbre présent, rien acheté, compétences verrouillées comme dans le jeu). Le profil « sans talents » de la 020 débloquait toutes les compétences ; notes de la 020 corrigées (10,2 min et non 8,6 min à 3 clics/s).
- Agents utilisés : `economy-designer` avant mesure (a contesté les parts du design, proposé une série plus douce, annoncé le recul du joueur à 1 clic/s) ; un agent indépendant après mesure (chiffres conformes aux sorties ; a trouvé le défaut du profil « sans talents », l'inadaptation du message de la version 1 et la baisse de l'or d'absence en début de partie).

**2026-11-15, build Clic.**
- Objectif fixé par Amaury : le build Clic retrouve le calendrier du build Compagnons (200 au jour 5, 210 au jour 7, 220 vers le jour 17, 225 fermé), sans viser 40 % de part.
- « Frappe alliée » de 50 à 70 % (accord d'Amaury). Mesuré de 50 à 120 % : dès 60 %, 200 au jour 5 et 210 au jour 7 ; le 220 ne suit pas le multiplicateur (38 h à 60 et 70 %, pas à 40 h à 50, 85, 100 et 120 %, graine 1) ; la cause de cet écart n'est pas identifiée. En attente devant le 210, le build Clic touche 28 Sp par retour, le build Compagnons 35 Sp.
- Vérifié à 70 % : 225 fermé à 1, 3 et 13 clics/s ; étage 200 au jour 5 à 3 clics/s. Part du clic à l'étage 200 : 30 % (27,5 % avant).
- Le build Clic avec « Rentes » touche 35 Sp par retour, comme le build Compagnons, et atteint quand même le 220 à 38 h (une mesure) : l'or par retour n'explique pas l'écart.
- Vérification par un agent indépendant : tous les chiffres des tableaux conformes aux sorties ; trois explications corrigées dans les notes (le casque est une conséquence du passage du 210 et non une cause, 35 Sp et non 42 Sp pour le build Compagnons en attente, le 210 bouge aussi à 13 clics/s par rapport à la 020). Non mesuré pour le build Clic : acheteur ratio, graine 3, Sursis hors 3 clics/s graine 1.
- Sensibilité, profil 4 h par jour et sommets Instinct de meute, Moisson, Rentier remesurés sur les nouvelles données : tableaux dans `assets/data/balance_notes.md`.

## Écarts connus (acceptés par Amaury)

| Sujet | Mesuré | Cible ou référence |
|---|---|---|
| Part du clic sans talents, étage 100, 3 clics/s | 31 % | environ 40 % |
| Part du clic sans talents, étage 10 | 60 % | 80 à 100 % dans le design, inatteignable avec le plafond du premier boss |
| 13 clics/s, graine 3, acheteur ratio | étage 200 au jour 3 (4,0 h) | jours 4 à 6 ; limite du profil extrême |
| Premier boss, sans talents, 1 clic/s | 17,1 min | plafond de 16 min, qui ne vaut que pour le build de référence |
| Premier retour à 1 clic/s | étage 59 | étage 66 avant |

| Build Clic, part du clic à l'étage 200, 3 clics/s | 30 % | 40 à 60 % ; l'objectif retenu est le calendrier |
| Build Clic, étage 220 | 38,0 h au jour 20 (graine 1), 36,0 h au jour 19 (graine 2), pas à 40 h avec le sommet Sursis | vers le jour 17, comme le build Compagnons |
| Build Clic, 13 clics/s | étage 200 au jour 3 (4,0 h) | jours 4 à 6 ; limite du profil extrême |
| Seuil 1 : un palier de boss entre 191 et 210 atteint en cours de session | 0 étage sur 30 entre 191 et 220, tous dans les 4 minutes après un retour, y compris avec le joueur qui défie (`--skills=3`) | au moins 10 étages hors des 2 premières minutes après un retour ; à rejuger après l'essai des amis |

**2026-11-15, piste C (or d'absence) : non faite, décision d'Amaury.** Le seuil 1 reste un écart accepté, à rejuger après l'essai des amis. Mesures de départ à reprendre si C est rouverte (profil de référence, graine 1, acheteur le moins cher) :

| `offline_efficiency` | Étage 200 | Étage 210 | Étage 220 |
|---|---|---|---|
| 0,1 (dans le fichier), données 020 | 8,0 h, jour 5 | 12,0 h, jour 7 | 36,0 h, jour 19 |
| 0,05, données 020 | 8,0 h, jour 5 | 14,0 h, jour 8 | pas à 40 h |
| 0, données 020 | 14,9 h, jour 8 | 30,4 h, jour 16 | pas à 40 h |
| 0,1, données 023 (parts de clic) | 8,0 h, jour 5 | 12,0 h, jour 7 | 32,0 h, jour 17 |

- Sur les étages 151 à 220, 40 sur 70 sont atteints dans les 2 minutes après un retour : 151 à 160 et tous ceux de 191 à 220 (données 020).
- Données 023, étages 191 à 200 : atteints 0,4 à 1,6 min après le retour de 8 h ; 201 à 210 : 0,4 à 1,4 min après le retour de 12 h. Avec `--skills=3` : 0,1 à 1,4 min après le retour de 10 h, puis 0,5 à 3,4 min après celui de 14 h.
- Le poids de l'or d'absence (seuil 2) n'a pas été remesuré sur les données 023 avec 0,05 et 0.

Non mesuré dans cette story : 1 h par jour, joueur qui ne revient qu'un jour sur deux, sans objets, flush IndexedDB du web.

---

## Règle des notes d'équilibrage (rappel)

Toute story qui ajoute de la puissance au joueur (objets, compétences, talents, éveil) relance la mesure de référence : profil 2 h par jour, 2 acheteurs, 40 h actives. Elle vérifie : étage 200 aux jours 4 à 6, étage 230 non atteint. La commande exacte et le tableau de sensibilité de la story 020 sont dans `assets/data/balance_notes.md`, section « Economy calibration (story 020) ».

Cette story change la puissance du clic et le poids de l'or : la règle s'applique à chaque famille de valeurs changée.

---

## Out of Scope

- Toute nouvelle mécanique, sauf décision d'Amaury au démarrage.
- Les courbes de PV de la story 020, sauf si la mesure de référence sort de sa cible.

---

## Files

Données et design :
- `assets/data/companions_roster.json` : `click_share` par compagnon.
- `assets/data/core_curves.json` : base de PV, taux avant l'étage 150, `balance_version` 2 et son message ; `click_companion_power_factor` retiré.
- `assets/data/talents.json` : « Frappe alliée » de 50 à 70 %.
- `assets/data/balance_notes.md`, `assets/data/data_schema.md`, `design/economy-rework.md`, `design/talent-tree-v2.md`.

Code :
- `src/core/balance_notice.gd`, `src/ui/main_screen.gd` : message d'équilibrage par version.
- `src/core/talent_tree.gd`, `src/core/floor_manager.gd` : exemples des commentaires seulement (×1,7).
- `tools/simulate_progress.gd`, `tools/sim_measures.gd` : `--talents=2`, `--skills=3`.

Tests :
- `tests/integration/balance/real_data_test.gd`
- `tests/unit/core-loop/balance_notice_test.gd`
- `tests/unit/ui/balance_notice_wiring_test.gd`
- `tests/unit/tools/sim_measures_test.gd`

Preuves :
- `production/qa/smoke-2026-11-14.md`
- `production/qa/evidence/story-023-active-play-value/01-message-equilibrage-v2-portrait-412x780.png`
- `production/qa/evidence/story-023-active-play-value/02-frappe-alliee-x1-7-portrait-412x780.png`

## QA Test Cases

*Sans talents à 1 et 3 clics/s ; build tout Clic avec chaque sommet ; build Économie (Rentes, Rentier, Longue veille) ; 1 h et 4 h par jour ; joueur qui ne revient qu'un jour sur deux.*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`, `assets/data/balance_notes.md`.

**Status**: [x] Créées. `production/qa/smoke-2026-11-14.md` ; `assets/data/balance_notes.md`, section « Active play value (story 023) » ; suite 1032/1032 le 2026-11-15 ; jeu lancé et observé : message d'équilibrage version 2 (capture 01) et carte « Frappe alliée » affichant « ×1,7 » (capture 02).

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-020-economy-calibration.md`
- Unlocks: None

---
