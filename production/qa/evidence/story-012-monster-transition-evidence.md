# Preuves : story 012, transition entre monstres

Export web release du 2026-11-01, avec la sonde invisible dans un clone jetable, jamais livrée.

## Captures

`trans-land-normal`, `trans-port-normal`, `trans-land-boss`, `trans-port-boss` : prises sur un build du clone aux durées multipliées par 10 environ (sortie 1,5 s, entrée 2 s, boss 3 s), seul moyen de photographier le fondu. Ces captures montrent l'ancien monstre, le nouveau et l'éclair du boss, pas les vraies durées. Le `v0.1.0` affiché vient du clone, dont la version n'était pas à jour.

## Comportements vérifiés dans l'export

| Critère | Résultat |
|---|---|
| Durées réelles lues dans les données | sortie 0,150 s, entrée 0,200 s |
| Ancre pendant la transition | déplacement 0,00, en paysage et en portrait |
| Clic pendant l'entrée | PV 38 → 37 alors que l'entrée vient de commencer |
| Kills très rapides | étage 34 à 118 en 5 s, éclair de 0,05 s sur 56 échantillons sur 100, sortie raccourcie à 0,09 s |
| Après une rafale | la transition s'arrête seule (durées réelles) |
| Réglage « Effets visuels » coupé | 0 échantillon de transition, le jeu continue d'avancer |
| `prefers-reduced-motion` au premier lancement | transition désactivée |
| Réglages ouvert | transition en pause |
| Erreurs console | 0 |

## Fluidité

Durées réelles. Fenêtre Edge normale, RTX 4060, écran 60 Hz, 8 compagnons niveau 150, mode Max, environ 13 clics/s, 3 passages de 10 s.

| Mesure | Effets activés | Effets coupés |
|---|---|---|
| Paysage 1280x720 | 59,9 à 60,0 images/s, pire image 33,4 ms | 60,0, pire 16,9 ms |
| Portrait 390x844 | 60,0, pire 16,9 ms | 60,0, pire 16,8 ms |
| Paysage, processeur ralenti ×4 | 44,2 au premier passage, pire 183 ms ; puis 59,0 à 60,0 | 51,9 au premier passage, pire 350 ms ; puis 57,2 à 60,0 |

Référence d'avant la story : mêmes ordres de grandeur (fiche de la story 011).

## Tests et simulateur

Simulateur 24 h identique à la référence, hors durée d'exécution. 491 tests sur 491 lancés par l'agent, aucun ne porte sur `EnemyView` : les tests sont dispensés à ce niveau. Un script jetable de 35 vérifications de l'agent passe, hors dépôt. Contrôle moteur `godot-gdscript-specialist` : aucun défaut bloquant.

## Limites

- Pendant le fondu, les formes du monstre se voient par transparence, comme accepté.
- En cadence d'éclair, un boss arrive sans sa marque d'entrée.
- Chaque changement d'ennemi compte comme un kill, y compris un boss abandonné.
- Avec une fenêtre de mesure très courte, un seul kill peut dépasser le seuil de 3 kills/s ; la valeur actuelle de 1 s n'est pas concernée.
- La sensation (durées, seuil, éclair du boss) reste à juger en jouant.

## Validation

- [x] Approved : sensation en jeu validée par Amaury le 2026-11-01 (durées, entrée du boss, éclair en cadence rapide, réglage « Effets visuels »)
