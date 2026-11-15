# Story 023: Valeur du jeu actif

> **Epic**: Idle Titans (MVP)
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-14

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

- [ ] Part du clic sans talents à 3 clics/s : environ 40 % au milieu, 10 à 20 % à l'étage 200.
- [ ] Un build Clic atteint 40 à 60 % à l'étage 200.
- [ ] Poids de l'or d'absence mesuré et noté : part de l'or du retour dans l'or total dépensé entre les étages 150 et 210, avant et après.
- [ ] Une session active de 2 h fait avancer le joueur de façon visible après l'étage 190, sans attendre le retour suivant (seuil à fixer avec Amaury).
- [ ] La mesure de référence est relancée après chaque famille de valeurs changée (règle ci-dessous) : étage 200 aux jours 4 à 6, étage 230 non atteint à 40 h actives, pour les deux acheteurs.
- [ ] Sensibilité et builds de sommet remesurés ; `balance_notes.md` et `real_data_test.gd` à jour ; tous les tests verts.

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

## Écarts connus (acceptés par Amaury)

| Sujet | Mesuré | Cible ou référence |
|---|---|---|
| Part du clic sans talents, étage 100, 3 clics/s | 31 % | environ 40 % |
| Part du clic sans talents, étage 10 | 60 % | 80 à 100 % dans le design, inatteignable avec le plafond du premier boss |
| 13 clics/s, graine 3, acheteur ratio | étage 200 au jour 3 (4,0 h) | jours 4 à 6 ; limite du profil extrême |
| Premier boss, sans talents, 1 clic/s | 17,1 min | plafond de 16 min, qui ne vaut que pour le build de référence |
| Premier retour à 1 clic/s | étage 59 | étage 66 avant |

Restent à traiter dans cette story : le mode « défi avec compétences » du simulateur (seuil 1), le build Clic et ses talents, puis la décision sur la piste C.

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

- À remplir à la fin.

## QA Test Cases

*Sans talents à 1 et 3 clics/s ; build tout Clic avec chaque sommet ; build Économie (Rentes, Rentier, Longue veille) ; 1 h et 4 h par jour ; joueur qui ne revient qu'un jour sur deux.*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`, `assets/data/balance_notes.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-020-economy-calibration.md`
- Unlocks: None

---
