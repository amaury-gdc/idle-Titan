# Epic: Idle Titans (MVP)

> **Status**: Active
> **Source**: `design/game-brief.md`

## Goal

Un idle game 2D dans le navigateur où l'on clique pour frapper, où des compagnons combattent seuls, et où l'on monte d'étage en étage jusqu'au mur, l'étage atteint étant le score.

## Scope (brief MVP)

1. Boucle clic, compagnons automatiques, étages et or
2. Boss tous les 10 étages avec chrono et repli
3. 8 compagnons achetables et améliorables, avec paliers
4. Données externes, état de partie séparé de l'état permanent, sauvegarde locale, grands nombres
5. 3 compétences actives avec temps de recharge
6. Arbre de talents (3 branches, environ 15 nœuds)
7. Objets et butin (5 types, 3 raretés, 9 stats)
8. Hors-ligne : or gagné d'après la puissance des compagnons, selon l'heure réelle, plafonné à 12 h

Hors périmètre : prestige, artefacts, familiers, clan, tournois, monnaie premium, publicité, son.

## Order

Fondations (données, état, sauvegarde), puis boucle, compagnons (mesure de la courbe), boss, hors-ligne, compétences, talents, objets en dernier.

## Stories

Stories terminées 001 à 018 : fichiers dans `production/archive/idle-titans/` (index : `INDEX.md`).

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Données, état et sauvegarde | Integration | Complete | N/A |
| 002 | Boucle de base : clic, étages, or | Logic | Complete | N/A |
| 003 | Compagnons et paliers | Logic | Complete | N/A |
| 004 | Boss et repli | Logic | Complete | N/A |
| 004b | Progression hors-ligne | Logic | Complete | N/A |
| 005 | Compétences actives | Logic | Complete | N/A |
| 006 | Arbre de talents | Logic | Complete | N/A |
| 007 | Objets et butin | Logic | Complete | N/A |
| 009 | Retours visuels (hors brief MVP) | Visual/Feel | Complete | N/A |
| 010 | Disposition adaptative, onglets et onglet Compagnons (hors brief MVP) | UI | Complete | N/A |
| 011 | Onglets Objets et Talents (hors brief MVP) | UI | Complete | N/A |
| 012 | Transition entre monstres (hors brief MVP) | Visual/Feel | Complete | N/A |
| 013 | Retouches compagnons (hors brief MVP) | UI | Complete | N/A |
| 014 | Mesures du simulateur et référence d'équilibre (hors brief MVP) | Logic | Complete | N/A |
| 015 | PV par segments et clic par compagnon (hors brief MVP) | Logic | Complete | N/A |
| 016 | Éveil des compagnons (hors brief MVP) | Logic | Complete | N/A |
| 017 | Interface de l'éveil et grands nombres (hors brief MVP) | UI | Complete | N/A |
| 018 | Arbre v2, format, verrous et rendu des points (hors brief MVP) | Logic | Complete | N/A |
| 019 | Arbre v2, effets, contenu et écran (hors brief MVP) | UI | Complete | N/A |
| 019b | Refonte UI/UX mobile (hors brief MVP) | UI | In Progress | N/A |
| 020 | Calibrage unique de l'économie (hors brief MVP) | Config/Data | Complete | N/A |
| 021 | Variété des monstres (hors brief MVP) | Visual/Feel | Ready | N/A |
| 022 | Écran allumé et mode économie (hors brief MVP) | UI | Ready | N/A |
| 023 | Valeur du jeu actif (hors brief MVP) | Config/Data | Not Started | N/A |
