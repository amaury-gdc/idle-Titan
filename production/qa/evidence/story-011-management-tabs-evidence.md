# Preuves : story 011, onglets Objets et Talents

Export web release du 2026-11-01, avec la sonde invisible de la story 010 dans un clone jetable, jamais livrée. Edge piloté par clics, touchers et touches. Sac plein (12 objets légendaires), 3 objets équipés, arbre partiellement acheté, 21 points.

## Tailles contrôlées

Captures `[taille]-[état]`. La sonde échoue si l'état visé n'est pas réellement ouvert.

- Tailles (18) : 320x568, 320x700, 360x640, 390x844, 500x900, 640x900, 768x1024, 844x390, 900x900, 1000x1100, 1050x1250, 1100x1400, 1024x768, 1280x720, 1600x900, 1920x1080, 2560x1080, 2560x1440.
- États : compagnons, objets, détail d'objet comparé, détail d'objet sans comparaison, objet équipé, talents, détail de talent, confirmation de remise à zéro, autres branches.
- Contrôles : débordement horizontal, défilement horizontal, cibles de 44 px CSS, texte de 14 px CSS, texte coupé, mot coupé, chevauchement, hors écran.
- Résultat : 174 états contrôlés, 0 problème, 0 erreur console.

Défaut trouvé par ce contrôle et corrigé : à 900x900, la confirmation dépassait de la fenêtre de 34 u, l'arbre complet étant écrasé dans un panneau de 340 u de haut.

## Comportements vérifiés dans l'export

- Le chrono de boss continue avec Objets ouvert (26 → 23 s) et Talents ouvert (23 → 20 s).
- Échap ferme le détail. Avec Réglages ouvert, Échap ne ferme que Réglages.
- Quitter Talents ferme la confirmation de remise à zéro.
- Tab va de la barre d'onglets au contenu.
- Tactile à 390x844, événements livrés sur cette exécution : un toucher ouvre le détail sans équiper, un glissé défile de plus de 100 px sans ouvrir de détail, un toucher sur un nœud ouvre son détail.
- Fusion de l'or : de l'étage 28 à 119 en 6 s, au plus 3 textes d'or à l'écran, un par tranche de 0,3 s (`gold-merge-2`).
- Titre de l'onglet : Catitans.

Contrôle complet de la story 010 rejoué sur cet état : aucun problème sur l'écran principal aux 10 tailles, en dehors des deux faux positifs déjà connus (barre de boss, fenêtres modales au-dessus du jeu). Tactile, clavier, ancienne sauvegarde version 3, réinitialisation réelle : conformes.

## Fluidité

Fenêtre Edge normale, RTX 4060, écran 60 Hz, 8 compagnons niveau 150, mode Max, environ 13 clics/s, 3 passages de 10 s, effets activés puis coupés.

| Mesure | Effets activés | Effets coupés |
|---|---|---|
| Paysage 1280x720, Talents ouvert | 59,9 à 60,0 images/s, pire image 33,3 ms | 60,0, pire 16,9 ms |
| Portrait 390x844, Objets ouvert | 60,0, pire 16,8 ms | 60,0, pire 16,9 ms |
| Paysage, processeur ralenti ×4, Talents ouvert | 44,8 au premier passage, pire 300 ms ; puis 59,8 à 60,0 | 55,3 au premier passage, pire 167 ms ; puis 56,7 à 59,9 |

Le premier passage au ralenti est moins bon que dans la story 010 (52,2 images/s, onglet Compagnons). Les passages suivants retrouvent 60 images/s.

## Tests et simulateur

491 tests sur 491. Simulateur 24 h identique à la référence, hors durée d'exécution, rejoué après la dernière modification de `src/core/`. Sur le clone, 13 modifications volontaires du code ont chacune fait échouer un test, puis tout est repassé au vert.

## Relectures

`ux-designer` : corrections 1 à 10 de la revue de la story 010 et story 011 ; 8 corrections OK ; les points 4 et 8, partiels, sont corrigés ensuite, avec les 5 majeurs sauf l'inversion de couleurs, en attente d'arbitrage.

`lead-programmer` : aucun défaut bloquant ni majeur sur la story 011 ; corrections 13, 15, 16 OK à la lecture. Son rapport sur 11, 12, 14 et 17 n'est pas arrivé.

`godot-gdscript-specialist`, relecture à la lecture du code et de 6 captures, sans exécution : corrections 11, 12, 14, 17 et les 14 corrections finales ; aucun KO. Trois points partiels :

- Toucher annulé non testé, et fusion de plusieurs doigts : test ajouté ; le cas à plusieurs doigts reste, sans effet visible.
- Message de butin : limité aux lignes de son créneau, ajouté ensuite.
- Formes courtes sur les nœuds de talents (« Clic +4 % ») : conservées, le détail donnant le texte complet.

Cette relecture signale aussi l'absence de test du choix de version du butin : inexact, `test_narrow_slot_with_a_full_bag_shows_only_the_short_line` a échoué sur un mutant. Sérialisation de `src/core/` inchangée, vérifiée par le coordinateur. `Companion.tier_levels()` renvoie le tableau interne sans copie ; l'appelant actuel ne fait que lire.

## Limites

- Fusion de l'or : les chiffres de dégâts restent empilables, et le message de butin peut couvrir un texte d'or.
- Message de butin, sac plein, 320x568 : mesuré par la sonde de l'agent hors export, pas vu dans l'export.
- Sur téléphone, sac plein, le nom de l'objet reçu n'apparaît plus.
- À partir du niveau 100, à 320 de large, « Alchimiste Niv. 100 » passe sur 2 lignes.
- Le renommage change le chemin de sauvegarde web (`/userfs/godot/app_userdata/Catitans/`).
- Vrai téléphone : non testé.
