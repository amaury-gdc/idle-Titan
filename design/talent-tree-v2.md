# Arbre de talents v2

> **Status**: Approuvée par Amaury le 2026-11-02, valeurs à recaler à la story 020
> **Stories**: 018, 019, 020

## Règles

| Sujet | Règle |
|---|---|
| Points | 1 tous les 5 étages jusqu'à 100, puis 1 tous les 20 : 25 à l'étage 200 |
| Paliers | Points dépensés dans la branche : 0, 2, 4, 8, 12 |
| Sommets | Un seul choix par branche au palier 5 ; un seul sommet par partie en pratique |
| Reset | Gratuit en points, interdit en combat de boss, recharge d'1 h réelle, offert après un changement de version |
| Compétences | Gros coup acquis ; Frénésie et Bonus d'or à débloquer pour 1 point chacun |
| Version | `tree_version` change : tous les points sont rendus, avec un message unique |

Le reset reste possible malgré la recharge si les points dépensés dépassent les points gagnés. Le verrou d'une compétence est dérivé des nœuds achetés, jamais stocké, et il est vérifié dans `SkillManager`.

Plafonds à 25 points : dégâts ×2 et or ×1,4 par rapport à l'arbre actuel, compétences comprises. Aucun nœud ni objet ne touche le multiplicateur d'escouade ni le coût d'éveil.

## Nœuds

30 nœuds, 69 points : un joueur renonce à plus de la moitié de l'arbre.

| id | Branche | P | Nom | Coût | Prérequis | Effet | Type |
|---|---|---|---|---|---|---|---|
| click_grip | Clic | 1 | Poigne ferme | 1 | - | Clic +8 % | stat |
| click_crit | Clic | 1 | Œil vif | 1 | - | 8 % de critique sur clic | stat, code |
| click_ally | Clic | 2 | Frappe alliée | 2 | - | Parts de clic ×1,5 | code |
| bighit_power | Clic | 2 | Gros coup puissant | 2 | - | 6 → 8 s de dégâts | compétence |
| click_rhythm | Clic | 3 | Rythme | 3 | - | Tous les 40 clics, Gros coup gratuit de 1 s, 5 s minimum entre deux | code |
| click_heavy | Clic | 3 | Coup lourd | 2 | - | Clic +15 % | stat |
| boss_hunter | Clic | 4 | Chasseur de boss | 3 | - | +10 % de dégâts sur boss | stat, code |
| bighit_cd | Clic | 4 | Gros coup rapide | 3 | bighit_power | Recharge 60 → 40 s | compétence |
| click_top_timer | Clic | 5 | Sursis | 3 | - | Chrono de boss +5 s | exclusif, code |
| click_top_rhythm | Clic | 5 | Virtuose | 3 | click_rhythm | Rythme : 30 clics, 1,5 s | exclusif |
| frenzy_unlock | Compagnons | 1 | Frénésie | 1 | - | Débloque ×1,5, 15 s, recharge 90 s | compétence |
| comp_camaraderie | Compagnons | 1 | Camaraderie | 1 | - | Compagnons +3 % | stat |
| comp_cadence | Compagnons | 2 | Cadence | 2 | - | Vitesse d'attaque +5 % | code |
| frenzy_long | Compagnons | 2 | Frénésie durable | 2 | frenzy_unlock | 15 → 20 s | compétence |
| comp_synergy | Compagnons | 3 | Synergie | 2 | - | +1 % par compagnon au niveau 100, 6 % au plus | code |
| comp_formation | Compagnons | 3 | Formation | 3 | - | Compagnons +8 % | stat |
| frenzy_power | Compagnons | 4 | Frénésie ardente | 3 | frenzy_unlock | ×1,5 → ×1,75 | compétence |
| comp_legion | Compagnons | 4 | Légion | 3 | - | Compagnons +8 % | stat |
| comp_top_champion | Compagnons | 5 | Champion | 3 | - | Compagnon le plus puissant +12 % | exclusif, code |
| comp_top_instinct | Compagnons | 5 | Instinct de meute | 3 | frenzy_unlock | Frénésie passive ×1,2, bouton « Passif » | exclusif |
| gold_unlock | Économie | 1 | Bonus d'or | 1 | - | Débloque ×1,5, 20 s, recharge 120 s | compétence |
| eco_purse | Économie | 1 | Bourse | 1 | - | Or +3 % | stat |
| economy_offline | Économie | 2 | Rentes | 2 | - | Or hors-ligne +25 % | stat |
| eco_flair | Économie | 2 | Flair | 2 | - | 10 points de poids Commun → Rare | code |
| eco_haggle | Économie | 3 | Négociation | 3 | - | Coûts de niveau -5 %, éveil exclu | code |
| gold_long | Économie | 3 | Bonus durable | 2 | gold_unlock | 20 → 30 s | compétence |
| gold_cd | Économie | 4 | Bonus rapide | 3 | gold_unlock | Recharge 120 → 80 s | compétence |
| eco_vigil | Économie | 4 | Longue veille | 3 | - | Plafond hors-ligne 12 → 16 h | code |
| eco_top_rentier | Économie | 5 | Rentier | 3 | - | Or hors-ligne +40 % | exclusif |
| eco_top_harvest | Économie | 5 | Moisson | 3 | - | Or en mode farm +12 % | exclusif, code |

`click_ally` remplace l'ancienne idée « 10 → 12 % », car le facteur disparaît. Instinct garde le bouton à sa place, pour que les touches 1/2/3 ne bougent pas ; il annule Frénésie durable et ardente, ce que la fiche doit dire.

## Écarté

Combo, niveau d'objet, chance de butin, choix manuel du favori. Passifs par compagnon : lot suivant, hors de cette refonte.

## Données

`talents.json` schéma 2 : `tree_version`, `stage_point_bands`, `tier_thresholds`, nœuds avec `tier`, `exclusive_group`, `effects[]`. Types d'effet : `stat`, `skill_unlock`, `skill_mod`, `skill_passive`, `rhythm`, `boss_timer`, `offline_cap_hours`, `synergy`, `champion`, `loot_shift`.

Sauvegarde : `PermanentState` v6, `talent_tree_seen` et `talent_reset_unix`. Le rendu efface toutes les clés, anciens ids compris, et se fait après le paiement de l'absence.

## Interface

- Téléphone : sous-onglets gardés, grille de 2 tuiles, en-têtes de palier « Palier 3 : 4 points sur 8 », barre de points réduite.
- Trois colonnes gardées quand elles tiennent, bandeau de détail sous l'arbre dès 560 u.
- Toucher ouvre la fiche, le bouton achète, la fiche se ferme ensuite. Ignorer l'action 250 ms après l'ouverture.
- Fiche : effet, total avant → après, coût, et « Exclut X » pour un sommet.
- États non colorés : Acheté, Coût, Manque, Palier fermé, Requiert, Exclu.
- Compétence verrouillée : 3 boutons gardés, « À débloquer », le toucher ouvre sa fiche, la touche affiche une bulle sans changer d'onglet.
- Changement de version : fenêtre unique, qui dit que les bonus sont retirés jusqu'aux prochains achats.
