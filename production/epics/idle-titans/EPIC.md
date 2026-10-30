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

Hors périmètre : hors-ligne, prestige, artefacts, familiers, clan, tournois, monnaie premium, publicité, son.

## Order

Fondations (données, état, sauvegarde), puis boucle, compagnons (mesure de la courbe), boss, compétences, talents, objets en dernier.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Données, état et sauvegarde | Integration | Ready | N/A |
| 002 | Boucle de base : clic, étages, or | Logic | Ready | N/A |
| 003 | Compagnons et paliers | Logic | Ready | N/A |
| 004 | Boss et repli | Logic | Ready | N/A |
| 005 | Compétences actives | Logic | Ready | N/A |
| 006 | Arbre de talents | Logic | Ready | N/A |
| 007 | Objets et butin | Logic | Ready | N/A |
