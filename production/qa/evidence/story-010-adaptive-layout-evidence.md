# Preuves : story 010, disposition adaptative

Export web release du 2026-11-01, avec une sonde invisible ajoutée dans un clone jetable (jamais livrée) qui relit les contrôles réels. Edge piloté par clics, touchers et touches.

## Tailles contrôlées

Captures `[taille]-normal`, `-boss`, `-reglages`, `-absence`.

| Taille | Échelle | Résultat de la sonde (cibles 44 px CSS, texte 14 px CSS, texte coupé, chevauchement, hors écran), avec aussi « Étage 999 » et « 999,9 Qa » |
|---|---|---|
| 390x844, 360x640, 320x568, 844x390, 768x1024 | 1 ; 0,92 ; 0,88 ; 0,88 ; 1,28 | Aucun problème |
| 1280x720, 1920x1080, 2560x1080 | 1 ; 1,5 ; 1,5 | Aucun problème |
| 500x900, 900x900 | 1,28 ; 1,28 | Aucun problème |

Écarté : `BossLabel` et `CountdownLabel` partagent la barre de boss, alignés à gauche et à droite : faux chevauchement de la sonde, vérifié sur capture.

`canvas.width` vaut `innerWidth × devicePixelRatio` à toutes les tailles, et après 50 redimensionnements en direct.

## Fluidité

Fenêtre Edge normale, RTX 4060, écran 60 Hz, 8 compagnons niveau 150, mode Max, environ 13 clics/s, 3 passages de 10 s.

| Mesure | Effets activés | Effets coupés |
|---|---|---|
| Paysage 1280x720 | 60,0 images/s, pire image 16,9 ms | 60,0, pire 16,9 ms |
| Portrait 390x844 | 60,0, pire 16,9 ms | 60,0, pire 17,0 ms |
| Paysage, processeur ralenti ×4 | 52,2 au premier passage, pire 183 ms ; puis 60,0 | 57,5 au premier passage, pire 100 ms ; puis 58,6 à 60,0 |

Référence d'avant la story : 60 images/s (fiche de la story 009).

Prix mesurés dans l'export, avant → après : niveau 1000 de 149,6 à 1,4 ms ; 100 niveaux depuis le niveau 1000 de 13 877 à 4 ms ; Max sur 8 lignes au niveau 1000 : 7 ms en régime établi, 13 ms au premier calcul après chargement. Tâches longues de 60 à 90 ms toutes les 1 à 2 s en Max avec niveaux 300 et 1e30 d'or.

## Comportements vérifiés dans l'export

Tactile (quand le navigateur livre les événements tactiles) : un doigt −1 PV, deux doigts −2 PV ; x10 dépense exactement 139 et donne le niveau 10 ; un glissé fait défiler de 148 px sans acheter ; un appui long montre la bulle sans activer ; un toucher active.

Clavier : 1, 2, inactif derrière Réglages pour 3 ; ordre de Tab conforme ; Espace et Entrée attaquent quand le monstre a le focus ; Échap ferme Réglages.

Autres : rotation pendant un boss (chrono, PV, étage intacts) ; ancienne sauvegarde version 3 chargée, aucune clé ajoutée ; réinitialisation réelle (réglage conservé, forme conservée) ; `prefers-reduced-motion` au premier lancement ; aucune erreur console.

Simulateur 24 h : résultat identique à la référence. Tests : 396 sur 396.

## Point non résolu

Sur environ la moitié des exécutions de l'émulation tactile, avec ou sans GPU, le navigateur ne livre aucun `touchstart` et produit un `click` au relâchement. Le glissé ne défile alors pas, et l'appui long active la compétence. La cause n'est pas établie. Hypothèses écartées par mesure : rendu logiciel, âge de la page, blocage du fil principal, `touch-action` absent du canevas. À vérifier sur un vrai téléphone.

## Revues indépendantes

`lead-programmer`, `ux-designer`, `accessibility-specialist` : aucun défaut bloquant côté code et accessibilité ; 2 bloquants et 4 majeurs côté UX, corrigés avec 11 autres points avant ces captures. Ces revues portaient sur l'état d'avant les corrections, qui n'ont pas été relues par elles.
