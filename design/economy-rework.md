# Refonte de l'économie et éveil des compagnons

> **Status**: Approuvée par Amaury le 2026-11-02 ; PV recalés à la story 020 (2026-11-14), part du clic reportée à la story 023
> **Stories**: 015, 016, 017, 020
> **Référence**: `assets/data/balance_notes.md`, section « Reference before the economy rework »

## Objectifs

| Sujet | Cible |
|---|---|
| Mur | Étage 200 atteint, étage 230 non atteint après 40 h actives |
| Temps vers 200 | 4 à 6 jours au profil de référence |
| Profil de référence | 2 h de jeu par jour, 22 h d'absence, 12 h comptées |
| Premier éveil | Étages 60 à 80 |
| Part du clic sans talents, 3 clics/s | 80 à 100 % au tout début, 40 % au milieu, 10 à 20 % à la fin |
| Build clic | 40 à 60 % à l'étage 200 |
| Gardien 1000 / Dragon 100 | Entre ×1,5 et ×3 |

Les cibles « premier boss en 2 à 3 min » et « étage 50 vers 1 h » du brief sont abandonnées : à mettre à jour dans `design/game-brief.md` à la story 020.

## PV par paliers

Valeurs recalées à la story 020 (mesures et raisons : `assets/data/balance_notes.md`, « Economy calibration »). `enemy_hp_base` passe de 22 à 24. Le taux de croissance dépend de l'étage :

| À partir de l'étage | Taux retenu (story 020) | Taux proposé avant mesure |
|---|---|---|
| 1 | 1,32 | 1,32 |
| 100 | 1,345 | 1,33 |
| 150 | 1,38 | 1,345 |
| 190 | 1,40 | 1,40 |
| 205 | 1,27 | 1,6 |
| 211 | 1,6 | — |

La base proposée avant mesure était 30 : elle mettait le premier boss à 11,8 min, d'où 24 (9,0 min). Le mur est en deux marches parce que l'or ne monte qu'avec l'étage : avec 1,6 dès 205, le joueur reste bloqué devant le boss de 210 pendant les 40 h.

Formule : `HP(s) = max(1, floor(A_k * g_k^(s - f_k)))`, avec `A_1 = base` et `A_(k+1) = floor(A_k * g_k^(f_(k+1) - f_k))`. Les ancres `A_k` sont calculées une fois au chargement, ce qui rend le calcul moins cher qu'aujourd'hui à haut étage. Or, coûts et boss sont inchangés.

Données : `enemy_hp_segments` dans `core_curves.json`, champ optionnel lu sans changer de version de schéma (story 015) ; il remplace `enemy_hp_growth`, jamais les deux ensemble. Les fixtures de tests gardent le scalaire.

## Clic

`click_companion_power_factor` est retiré. Il fixe la part du clic à 25 % à 3 clics/s, à toutes les phases.

`clic = base + floor(somme(part_i * dps_i))`, avec `dps_i` sans talents.

| Compagnon | Éclaireur | Lancier | Archer | Gardien | Mage | Chevalier | Alchimiste | Dragon |
|---|---|---|---|---|---|---|---|---|
| `click_share` | 1 | 0,8 | 0,6 | 0,45 | 0,35 | 0,25 | 0,15 | 0,06 |

La mesure de `click_companion_power_factor` montre qu'il pèse peu sur le rythme : à 0, l'étage 100 ne bouge presque pas.

## Éveil

| Règle | Valeur |
|---|---|
| Seuils | 200, 300, ... 1000, pour chaque compagnon |
| Coût | 10 × `cost_of_level(seuil)` |
| Effet propre | ×3,4 sur ce compagnon |
| Effet d'escouade | ×2,10 sur tous les compagnons, seuils 200 à 600 seulement |
| Blocage | Le niveau s'arrête au seuil tant que l'éveil n'est pas payé |
| Achat | Bouton « Éveiller », jamais automatique |
| Palier ×3 du niveau 200 | Conservé |
| Au-delà de 1000 | Niveaux libres, sans éveil |
| Reset de partie | L'éveil suit la partie : il est effacé |
| Sauvegardes existantes | Niveaux conservés ; éveils éligibles payants, jamais offerts |

Le blocage rend le joueur prudent et le joueur optimal équivalents. Sans lui, un joueur qui éveille dès que possible arrive à 200 environ deux fois plus vite.

Dégâts : `D = floor(base * niveau * paliers * 3,4^a * 2,10^A)`, un seul floor, avec `a` les éveils du compagnon et `A` les éveils d'escouade comptés. Le multiplicateur est calculé une fois à chaque éveil. L'éveil reste dans `Combat` et `Companion`, jamais dans `ModifierHub`.

Données : bloc `awakening` et `click_share` dans `companions_roster.json`, schéma 3. État : `GameState.companion_awakenings`, id vers nombre. Les mémos de `Companion` sont indexés aussi par les éveils.

### Interface

- Au seuil, le bouton affiche « Éveiller » et le coût, avec le gain d'escouade.
- x10 s'arrête au seuil et affiche le vrai nombre, par exemple « x5 ». Cela amende la décision D3 de `buy_quote.gd`.
- Max s'arrête au seuil. Palier vise le prochain palier ou seuil.
- La barre affiche « Éveil disponible » : indice texte, pas seulement couleur.
- Rang visible par la forme et le texte, par exemple « Éveil II ». Première fois : phrase unique sur la force de l'escouade.

## Mesures du candidat dans le moteur

Profil de référence, avec ×2,10 sur tous les seuils et l'arbre actuel. La limite aux seuils 200-600 reste à mesurer.

| Étage | 3 clics/s | 1 clic/s |
|---|---|---|
| 10 | 1,3 min | 3,3 min |
| 50 | 21 min | 40 min |
| 100 | 1,9 h | 2,7 h |
| 150 | 3,4 h | 4,6 h |
| 200 | 8,8 h, jour 5 | 10,3 h, jour 6 |

Le réglage est nerveux : ×2,05 donne 11,9 h, ×2,20 donne 5,6 h à 3 clics/s. L'arbre v2 ajoute environ ×2,3 de puissance : le calibrage final se fait donc une seule fois, à la story 020.
