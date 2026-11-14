# Game Brief: Idle Titans

**One-sentence pitch:** Un idle game 2D dans le navigateur où l'on clique pour frapper, où des compagnons combattent seuls, et où l'on monte d'étage en étage jusqu'au mur, l'étage atteint étant le score.

## Core loop
- Un ennemi par étage : on clique, les compagnons attaquent seuls, l'ennemi meurt, on gagne de l'or.
- Dégâts de clic = base + % de la puissance des compagnons, pour que le clic reste utile.
- L'or achète et améliore les compagnons, ce qui permet de monter d'étage.
- Boss tous les 10 étages, chrono 30 s (hypothèse) ; en cas d'échec, retour à l'étage précédent et farm.

## Player goal & fail state — what "working" looks like
- But : monter le plus haut possible ; l'étage atteint est le score.
- Fin de la V1 : le mur, quand on ne peut plus avancer. Le mur est normal.
- Objectifs de calibrage (story 020, mesurés) : au profil de référence (2 h de jeu par jour, 3 clics/s), étage 200 atteint en 4 à 6 jours, mur vers les étages 210 à 220, étage 230 non atteint après 40 h actives. Mesuré : premier boss tué vers 9 min, étage 50 vers 45 min, étage 200 au jour 5. Les anciennes hypothèses (premier boss en 2 à 3 min, étage 50 en 1 h, mur entre 100 et 150) sont abandonnées. Détail : `assets/data/balance_notes.md`.

## MVP — what must exist to be the game
- Boucle clic, compagnons automatiques, étages et or (dégâts de clic = base + % compagnons).
- Boss tous les 10 étages avec chrono et repli à l'étage précédent.
- 8 compagnons achetables et améliorables, avec paliers qui multiplient leurs dégâts.
- Données externes (compagnons, courbes, talents), état de partie séparé de l'état permanent, sauvegarde locale, grands nombres (1,5 M, 3,2 B).
- 3 compétences actives avec temps de recharge : gros coup, buff de dégâts, bonus d'or.
- Arbre de talents : 3 branches (Clic, Compagnons, Économie), environ 15 nœuds, 1 point tous les 5 étages, réinitialisation gratuite.
- Objets et butin : 5 types (Sword, Helmet, Chest, Aura, Slash), 1 actif par type, 3 raretés, 9 stats, premier objet sur le boss de l'étage 10, inventaire limité avec vente automatique des moins bons.
- Hors-ligne : or gagné d'après la puissance des compagnons et le temps réel écoulé depuis la dernière sauvegarde, plafonné à 12 h, améliorable par l'arbre de talents.

## Out of scope — not building this
- Prestige et artefacts (prévus après la V1, l'architecture doit les accepter sans tout réécrire).
- Familiers, clan, tournois, monnaie premium, publicité, son.

## Build order
1. Boucle de base, fichiers de données et grands nombres.
2. Compagnons et or, puis mesure de la courbe contre les objectifs de calibrage.
3. Boss et repli.
4. Sauvegarde locale.
5. Hors-ligne.
6. Compétences actives.
7. Arbre de talents.
8. Objets et butin (dernier, coupable si la courbe n'est pas réglée).

---
**Who it's for / what they feel:** Quelques amis testeurs, sessions courtes ; ils sentent la progression et comprennent l'état du jeu d'un coup d'œil.

**Art & audio direction:** Formes simples, chiffres lisibles, univers et visuels originaux ; aucun son en V1.

**Reference game:** Tap Titans 2, dont la V1 garde la boucle clic, compagnons, étages, boss et talents, sans prestige, artefacts, familiers ni clan.
