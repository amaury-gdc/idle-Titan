# Preuves : story 009, Retours visuels

Build mesuré : export web release du 2026-11-01, servi en local, joué dans Edge par clics réels.

## Captures

Dans `production/qa/evidence/story-009-visual-feedback/`.

| Fichier | Montre |
|---|---|
| `01-click-normal.png` | Chiffre d'un clic normal |
| `02-click-critical.png` | Chiffre critique, plus gros, avec « ! » |
| `03-gros-coup.png` | Chiffre très gros de Gros coup |
| `04-gold-enemy.png` | « + or » d'un ennemi |
| `05-boss-before.png`, `06-gold-boss.png` | Boss, puis « + or » plus gros à sa mort |
| `07-eight-spheres-balls.png`, `08-eight-spheres-balls-later.png` | 8 sphères, or des kills des compagnons, aucun chiffre par attaque |
| `09-eight-spheres-balls-boss-gold.png` | Boules en vol vers le monstre |
| `10-back-from-hidden-tab.png` | Retour d'onglet caché : aucun effet accumulé |
| `11-setting-on.png`, `12-setting-off.png`, `13-setting-off-after-reload.png` | Réglage activé, coupé, toujours coupé après rechargement |

## Fluidité

Fenêtre Edge normale, 1280x720, rendu matériel (RTX 4060), écran à 60 Hz. 8 compagnons niveau 150, critiques à chaque clic, environ 13 clics/s, 10 s par mesure. La fréquence est plafonnée à 60 images/s par l'écran.

| Mesure | Images/s | Médiane | 95e centile | Pire image |
|---|---|---|---|---|
| Effets activés, 3 passages | 60,0 / 60,0 / 60,0 | 16,7 ms | 16,8 ms | 17,0 ms |
| Effets coupés, 3 passages | 60,0 / 60,0 / 60,0 | 16,7 ms | 16,8 ms | 16,8 ms |

Le même test avec le processeur ralenti six fois, pour estimer la marge, à environ 10 clics/s :

| Mesure | Passage 1 | Passage 2 | Passage 3 |
|---|---|---|---|
| Effets activés | 50,1 images/s, pire image 150 ms | 59,6, pire 33 ms | 59,2, pire 133 ms |
| Effets coupés | 58,6, pire 83 ms | 59,9, pire 33 ms | 60,0, pire 17 ms |

Sous ce ralentissement, les effets ajoutent des saccades isolées, surtout au premier passage. Cause probable, non prouvée : la première préparation des chiffres à chaque taille de texte. Ce ralentissement simulé ne touche que le processeur, et aucune machine modeste réelle n'a été mesurée.

## Sans effet sur le jeu

- `tools/simulate_progress.gd`, 24 h simulées, avant et après la story : résultats identiques.
- Test `test_scenario_same_dice_gives_same_game_with_the_setting_on_or_off`.
- Suite complète : 246 tests sur 246.

## Validation

La sensation (rythme, poids, lisibilité en jeu) ne se juge pas sur une capture.

- [x] Approved — Amaury, le 2026-11-01 (« c'est parfait »)
