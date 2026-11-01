# UX Spec: Écran principal adaptatif

> **Status**: Approved par Amaury le 2026-11-01, décisions D1 à D8 acceptées telles que recommandées ; `/ux-review` : NOT ASSESSED (aucun palier d'accessibilité défini)
> **Author**: Amaury + ux-designer, ui-programmer, accessibility-specialist, godot-specialist, art-director, qa-tester
> **Last Updated**: 2026-11-01
> **Journey Phase(s)**: toutes (écran unique du jeu) ; pas de carte de parcours
> **Platform Target**: navigateur web (export Godot Compatibility, sans threads) ; tactile, souris, clavier. Manette : voir D2.
> **Template**: UX Spec

Les valeurs en « u » sont des unités logiques du jeu ; « px CSS » désigne la taille réelle à l'écran.

---

## Purpose & Player Need

Le joueur arrive pour voir où il en est, frapper, dépenser, et repartir. L'écran doit montrer d'un coup d'œil l'étage, l'or et le combat, et laisser dépenser sans cacher le combat, sur téléphone comme sur PC.

---

## Player Context on Arrival

- Première visite : étage 1, 0 or, aucun compagnon. Le joueur ne sait pas encore ce qu'il peut faire.
- Retour d'absence : le panneau d'or hors-ligne s'affiche d'abord.
- Session courte, souvent à une main sur téléphone, parfois téléphone tourné.
- Hypothèses non validées : il n'existe pas de carte de parcours joueur.

---

## Navigation Position

Racine du jeu, seul écran. Onglets Compagnons, Objets, Talents dans la zone de gestion. Réglages et retour d'absence sont les deux seules fenêtres modales qui restent.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Chargement de la page | Ouverture du lien | Sauvegarde locale, gain hors-ligne éventuel |
| Réinitialisation | Confirmation dans Réglages | Partie neuve, scène rechargée |
| Retour d'onglet caché | `visibilitychange` | Gain hors-ligne éventuel |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Réglages | Bouton de l'en-tête | Modal, le jeu attend |
| Retour d'absence | Absence de 60 s ou plus | Modal, le jeu attend, ne ferme plus aucun onglet |
| Fermeture de la page | Navigateur | Sauvegarde automatique existante |

---

## Layout Specification

### Mise à l'échelle et forme

**Remplace `aspect="keep"`, cause des bandes noires.** Choix retenu : `canvas_items`, `aspect="expand"`, `scale_mode="fractional"`, `html/canvas_resize_policy=2` conservé, et une taille de base choisie à l'exécution selon la forme.

| Forme | Base | Plancher | Exemple → taille logique (1 u en px CSS) |
|---|---|---|---|
| Portrait | 390x640 | 0,88 px CSS par u | 390x844 → 390x844 (1) ; 768x1024 → 600x800 (1,28) ; fenêtre de 320 de large → 363 u de large (0,88) |
| Paysage | 1280x720 | 0,88 px CSS par u | 1280x720 → 1280x720 (1) ; 1920x1080 → 1280x720 (1,5) ; 2560x1080 → 1707x720 (1,5) ; 844x390 → 959x443 (0,88) |

Écarté : une base fixe (1280x720 donne du texte à 0,3 sur téléphone ; 720x720 impose des cibles de 81 u, trop grosses sur PC, donc des paliers par appareil).

**Deux règles qui découlent du plancher, valables partout** : toute cible fait au moins 50 u (44 px CSS à 0,88) et tout texte au moins 16 u (14 px CSS à 0,88).

Échelle du portrait plafonnée à 1,28 : une tablette 768x1024 donne environ 600x800 u, et plus de lignes de liste.

**Détection** : rapport largeur/hauteur de la fenêtre lu sur `get_window().size_changed`. Passage en portrait sous 1,10, en paysage au-dessus de 1,20, démarrage à 1,15 (revue indépendante : à 900x900, le paysage laissait un monstre petit et des zones vides). L'hystérésis évite les bascules ; elle ne déclenche rien avec les barres de navigateur, loin de ces seuils. La forme est appliquée en synchrone dans `_ready`, sans clignotement d'une mauvaise disposition.

**Orientation** : jamais de verrouillage ni de message « tournez votre téléphone ». Écran en paysage → disposition paysage, jeu continu, conforme à ta préférence.

### ASCII Wireframe

Portrait 390x844 (taille réelle), sans barre de navigateur : environ 6 lignes de liste. Avec barres (hauteur 664) : moins de 3. Si la hauteur manque encore, la rangée du monstre descend de 170 à 120 u minimum avant que la liste ne réduise.

```
┌──────────────────────────────────────┐
│ Étage 43    Or        DPS     [Régl.]│ 56
│ record 60   182,7 M   95,1 B         │
├──────────────────────────────────────┤
│ [Abandonner]  BOSS 24 s ▓▓▓▓░░       │ 50  bandeau d'action
│ ● ●                            ● ●   │
│ ● ●       ( monstre )          ● ●   │ 170 sphères de part et d'autre
│                                      │
│ ▓▓▓▓▓▓▓▓▓░░░  2,9 M / 5,5 M          │ 24
│ [Gros coup][Frénésie][Bonus d'or]    │ 52  3 compétences, toujours visibles
│ v0.1.0              [Défi auto : NON]│ 50
├──────────────────────────────────────┤
│ [ x1 ][ x10 ][ Max ]                 │ 50
│ Éclaireur  Niv. 12   [ Améliorer 324]│ 56 par ligne
│ …                                    │ liste défilante
├──────────────────────────────────────┤
│ Compagnons •│  Objets  │ Talents (3) │ 56  barre d'onglets, sous le pouce (D7)
└──────────────────────────────────────┘
```

Paysage 1280x720 et plus. Même structure à 844x390 et 2560x1080 : seule l'échelle change. Toute la largeur est partagée 60/40.

```
┌───────────────────────────────────────────────────────────────┐
│ Étage 43 · record 60   Or : 182,7 M   DPS : 95,1 B    [Réglages]│
├──────────────────────────────────────┬────────────────────────┤
│ GAUCHE  │       CENTRE      │ DROITE │ [x1][x10][Max]         │
│ Gros    │  BOSS 24 s ▓▓░░   │ ● ●    │ Éclaireur Niv. 12 [324]│
│ coup    │                   │ ● ●    │ Lancier   Niv. 3  [ 41]│
│ Frénésie│    ( monstre )    │ ● ●    │ …                      │
│ Bonus   │                   │ ● ●    │                        │
│ d'or    │  ▓▓▓▓▓▓░░ 2,9 M   │[Défier]│                        │
│ v0.1.0  │                   │[Auto]  │ Compagnons•│Objets│Talents│
└──────────────────────────────────────┴────────────────────────┘
```

### Layout Zones

| Zone | Portrait | Paysage | Remplissage |
|---|---|---|---|
| En-tête | 56 u, 3 cellules sur 2 lignes + Réglages | 56 u, 1 ligne (49 px CSS à 844x390) | Fond `#0A0D17` jusqu'aux bords |
| Zone de jeu | Haut, hauteur fixe par rangées | Gauche 60 %, 3 colonnes | Fond `#171A29` ; halo teinté à 15 % de la couleur d'étage, bande de sol sur toute la largeur |
| Zone de gestion | Bas, tout le reste | Droite 40 % | Fond `#212130` |
| Onglets | Bas de l'écran | Bas de la colonne de droite | Même composant |

Largeur de gestion : une seule version de liste, qui s'adapte à sa propre largeur. Sous 640 u : détail qui remplace la liste, arbre sur une branche à la fois. À partir de 640 u : liste et détail côte à côte. L'arbre complet demande en plus 480 u de haut et assez de largeur pour ses branches, sinon il reste sur une branche ; son détail est une bande sous l'arbre, trois colonnes de nœuds ne laissant aucune place à côté.

**Monstre et ancrage.** Boîte carrée `MB` = plus grand carré de l'emplacement réservé, plafonnée à 640 u, jamais plus que 55 % de la largeur de zone. Aujourd'hui, 300 unités de dessin. `EnemyView` applique le facteur `MB/300` au dessin et à la zone de clic (`draw_set_transform`, pas `scale`, réservé à `play_hit`). Contrat stable pour les futurs chats : `clicked`, `set_stage`, `play_hit`, centre d'ancrage en coordonnées globales, rayon de clic. Couche de textes et sphères au-dessus de tout, position recalculée à chaque `resized`, via le centre du rectangle non tourné, jamais `position`. Marges dans la boîte : 20 % en haut, 10 % sur les côtés. Trajets des textes multipliés par `MB/300`.

**Sphères.** 8 emplacements fixes dans une disposition : 2 fois 2 de part et d'autre du monstre en portrait, 2 colonnes de 4 à droite en paysage. Rayon 14 u, pas de 36 u ; rayon et pas suivent `MB/300` au-delà, jusqu'à 28 et 72 u.

### Component Inventory

| Composant | Type | Contenu | Interactif | Motif |
|---|---|---|---|---|
| Cellule Étage | Texte | Étage, record | Non | Existant, record sorti de la ligne de score |
| Cellule Or | Texte | Or | Non | Existant |
| Cellule DPS | Bouton texte | DPS | Oui, ouvre le détail DPS et clic | Nouveau |
| Réglages | Bouton | Texte « Réglages » | Oui | Reprend `SaveScreen` + Effets visuels |
| Bandeau d'action | Bouton ou chrono | Défier, ou BOSS + chrono + Abandonner | Oui | Existant |
| Monstre | Zone cliquable | `EnemyView` | Oui | Existant |
| Barre de PV | Barre ancrée | PV | Non | Ancres au lieu de `size.x` |
| Compétences | 3 boutons | Nom, état (« Disponible », « En cours : 15 s », « Dans 60 s ») | Oui, appui long | Existant + nouveau |
| Défi automatique | Bascule | OUI/NON | Oui | Existant |
| Version | Texte 16 u | `v0.1.0` | Non | Reste visible dans un coin (ta demande d'origine) |
| Onglets | 3 boutons bascule (`ButtonGroup`) | Libellé, point, compteur | Oui | Nouveau |
| Sélecteur | 4 segments | x1, x10, Max, Palier | Oui | Nouveau |
| Lignes compagnon | Ligne + bouton | Nom, niveau, DPS, coût | Oui | Existant adapté |
| Objets | Emplacements, sac, détail | Comparaison | Oui | Refonte, story B |
| Talents | Branches, détail | Nœuds | Oui | Refonte, story B |
| Butin | Message non bloquant, 4 s | Objet reçu | Non | Dans la partie libre du bandeau d'action, sinon sous lui, sans couvrir les sphères ; ne capte aucun clic |
| Astuce boss | Bandeau bas du monstre | 2 à 3 lignes | Non | Existant déplacé |

Disparaissent de l'écran : « Dégâts de clic » (dans le détail DPS) et la ligne des buffs (les boutons affichent déjà « En cours : 15 s »).

### Information Hierarchy

1. Combat : monstre, PV, chrono de boss.
2. Étage et or.
3. Compétences et action de boss.
4. Liste de l'onglet ouvert.
5. DPS, record, version.

### Direction visuelle

Jetons issus des couleurs actuelles, 2 ors fusionnés : fonds `#0A0D17`, `#171A29` ; panneaux `#212130`, `#40404D` ; bord `#BFBFCC` ; or `#FFD640` ; PV `#D93333` sur `#471A1A` ; DPS `#FF9E73` ; prêt `#218040` + bord `#80F299` ; actif `#8C6B0D` + bord or ; désactivé `#2B2B33`.

Texte : 5 tailles au lieu de 15, soit 16, 20, 24, 32, 48 u. Portrait : étage et or 20, DPS, corps et secondaire 16, le secondaire se distinguant par sa couleur. Paysage : étage et or 32, DPS 24, corps 20, secondaire 16 ; le corps des panneaux Objets et Talents reste à 16, pour la densité. Un seul contour de 6 u. Un seul `Theme` partagé.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Défaut | Chargement | Onglet Compagnons |
| Première partie | Aucun compagnon | Point sur Compagnons dès le premier achat possible |
| Mode farm | Boss raté | Bouton Défier dans le bandeau |
| Combat de boss | Étage de boss | Chrono + Abandonner dans le bandeau |
| Détail ouvert | Toucher un objet ou talent, sous 640 u | Le détail remplace la liste, Retour + action fixe |
| Effets coupés | Réglage | Plus de textes, sphères, boules ni écrasement du monstre |
| Erreur de données | Chargement raté | Message seul, onglets et jeu masqués |
| Chargement | Démarrage Godot | Écran de démarrage à la couleur du fond |
| Sac vide, aucun talent achetable | Données vides | Texte d'état dans l'onglet |
| Changement de forme | Rotation, redimensionnement | Mêmes nœuds : onglet, défilement, détail et focus conservés |
| Onglet navigateur caché | `visibilitychange` | Effets effacés, sauvegarde |
| Réglages, retour d'absence | Ouverture | Largeur : le plus petit de 720 u et de la largeur moins 32 u. Hauteur limitée à la fenêtre, contenu défilant : Réglages (600 u aujourd'hui) ne tient pas dans les 443 u du paysage téléphone |

---

## Interaction Map

Tactile, souris, clavier. Manette selon D2.

| Composant | Tactile | Souris | Clavier | Retour | Résultat |
|---|---|---|---|---|---|
| Monstre | Appui (D6 pour plusieurs doigts) | Clic | Focus + Espace ou Entrée (D2) | Écrasement, chiffre | `click()` |
| Compétence | Toucher | Clic | Focus + Entrée, 1/2/3 selon D2 | État du bouton | Active |
| Détail compétence | Appui long 500 ms | Survol | Focus | Bulle | Lecture seule, n'active jamais |
| Détail DPS | Toucher | Clic | Focus + Entrée | Bulle | Compagnons, clics, dégâts de clic |
| Défier, Abandonner, Défi auto | Toucher | Clic | Focus + Entrée | État | Existant |
| Onglet | Toucher | Clic | Flèches sur la barre, Tab vers le contenu | Barre or, libellé or | Change le contenu, éteint son point |
| x1 / x10 / Max / Palier | Toucher | Clic | Flèches | Fond or, texte sombre | Change le coût des lignes (D3) |
| Acheter compagnon | Toucher | Clic | Entrée | Coût, niveau | Achat (lot unique) |
| Liste | Glisser | Molette | Flèches, suivi du focus | Défilement | Un glissé n'achète jamais |
| Objet ou talent | Toucher | Clic | Entrée | Détail | Action dans le détail (D5) |
| Échap | - | - | Échap | Retour | Ferme le détail ou Réglages ; aucun effet sinon |

**Appui long** : se déclenche après 500 ms en maintien, même sur un bouton désactivé. S'annule au-delà de 10 px CSS de déplacement, à un second doigt, à un changement d'onglet ou de forme, ou si la page se cache. Le relâchement qui suit ne déclenche pas le bouton. La bulle reste jusqu'au prochain toucher, qui ne fait que la fermer, et elle reste entière à l'écran.

**Raccourcis (selon D2)** : 1/2/3 sont inactifs dès qu'une fenêtre modale est ouverte ou que le champ de sauvegarde a le focus. Une touche globale d'attaque est exclue : Espace et Entrée activent déjà le bouton qui a le focus, donc le monstre devient focalisable et ces touches l'attaquent seulement quand il a le focus.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Étage, record, or, PV, boss | `FloorManager`, `GameState` | Read | Temps réel |
| Compagnons, coûts | `CompanionManager` | Read/Write | Ajouts sans nouvelle règle : coût total de N niveaux, nombre achetable, achat par lot avec un seul signal (D3) |
| Compétences | `SkillManager` | Read/Write | Existant |
| Objets, talents | `Inventory`, `TalentTree` | Read/Write | Existant, story B |
| Effets visuels, multiplicateur retenu | `DisplaySettings` | Read/Write | `user://settings.cfg`, hors sauvegarde |
| Points de notification | Interface | Mémoire | Non sauvegardés |

Aucun champ de sauvegarde ajouté.

Mises à jour : en-tête, PV et compétences à chaque image ou sur signal, comme aujourd'hui. Coûts x10 et Max recalculés sur changement d'or, 4 fois par seconde au plus. Points de notification : affichage dérivé des événements du jeu, sans donnée de jeu possédée par l'interface. Valeur absente : la ligne affiche « - » ; aucune valeur de jeu n'est inventée.

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Changer d'onglet | Aucun événement de jeu | - |
| Acheter en lot | Signal de lot | id, niveaux, coût ; modifie la sauvegarde comme un achat |
| Équiper, acheter un talent | Existants | Modifient la sauvegarde |
| Pas d'analytique | - | Choix délibéré |

---

## Transitions & Animations

- Entrée : aucune transition, l'écran de démarrage passe au jeu.
- Onglets, détail, bascule de forme : immédiats, sans animation.
- Fin de chrono : le libellé change, pas seulement la couleur.
- Effets visuels coupé arrête aussi l'écrasement du monstre. Le premier réglage suit `prefers-reduced-motion` ; un choix du joueur prime ensuite.

---

## Input Method Completeness Checklist

**Clavier**
- [x] Tout est atteignable au clavier, y compris le monstre (selon D2)
- [x] Ordre : en-tête, jeu, onglets, contenu
- [x] Focus visible : anneau unique de 3 px CSS clair à bord sombre, non coupé par les listes
- [x] Le focus reste dans une fenêtre modale tant qu'elle est ouverte
- [x] Échap ferme ou annule, ne quitte jamais
- [x] Si le nœud focalisé disparaît, le focus va à l'onglet actif

**Manette** : voir D2. Déplacement au D-pad par la navigation de focus ; aucun raccourci tant que D2 n'est pas tranché.

**Souris**
- [x] Survol défini ; il ne porte plus d'information exclusive
- [x] Cibles de 44 px au minimum
- [x] Clic droit sans effet
- [x] Molette dans les listes

**Tactile**
- [x] Cibles de 44 px CSS au minimum, en largeur et en hauteur
- [x] Pas de geste de balayage
- [x] Toutes les actions à une main en portrait, sauf la portée sur grand téléphone, à confirmer sur appareil réel
- [x] Appui long défini

---

## Accessibility

Aucun palier d'accessibilité n'est défini. Référence de travail : WCAG 2.1 AA, sauf lecteur d'écran.

| Problème mesuré | Valeur | Correction |
|---|---|---|
| Texte des boutons verts | 3,76:1, survol 3,06:1 | Texte blanc forcé (5,00:1), survol plus sombre |
| Talent achetable | 3,73:1, survol 3,00:1 | Idem |
| Compétence active | 4,11:1 | Idem |
| Texte désactivé porteur d'un coût | 3,53 à 4,30:1 | Gris à 0,62, environ 5 à 6,4:1 |
| Achat possible ou non | Couleur seule, 2,80:1 entre fonds | Bord épais sur le bouton achetable seulement (story 013) |
| Point de notification | 2,22:1 sur gris | Pastille or à bord sombre + compteur dans le libellé |

Information au survol seul remplacée : détail de compétence (appui long et focus), DPS (toucher), « Requiert : X » (imprimé sur le nœud verrouillé). Le texte des boutons reste lu au survol sur PC, sans exclusivité.

Double codage partout : rareté = couleur + bord + mot ; onglet choisi = barre + couleur ; sélecteur = fond inversé.

Lecteur d'écran : le canevas n'est pas lu par les lecteurs d'écran sur le web ; aucune promesse d'accessibilité à ce sujet (D8).

---

## Localization Considerations

Français seul pour l'instant, tout passe par `tr()`. Aucun libellé en majuscules forcées.

| Élément | Limite | Risque |
|---|---|---|
| Onglet | 11 caractères, compteur compris à 14 | Élevé (« Compagnons ») |
| Compétence | 10 caractères, 2 lignes | Élevé (« Bonus d'or ») |
| Bandeau d'action | 16 caractères | Élevé (« Abandonner le boss » raccourci en « Abandonner ») |
| Cellule d'en-tête | « Étage 999 », « 999,9 Qa » | Élevé : la largeur minimale dépasse aujourd'hui 680 u, les cellules doivent contenir ces valeurs sans déborder |
| Ligne compagnon | 12 caractères pour le nom | Moyen |

---

## Acceptance Criteria

- [ ] Aux 390x844, 844x390, 768x1024, 1280x720, 1920x1080, 2560x1080, en fenêtre étroite (320 de large) : aucune bande vide, aucun texte coupé, aucun chevauchement.
- [ ] `canvas.width` vaut `innerWidth × devicePixelRatio` à chaque taille, y compris pendant un redimensionnement en direct.
- [ ] 50 redimensionnements en 5 s : aucune erreur, forme finale correcte, barre de PV exacte.
- [ ] Rotation pendant un boss : chrono, PV, étage et onglet inchangés.
- [ ] Toutes les cibles font au moins 44 px CSS et tout texte au moins 14 px CSS, vérifié automatiquement sur l'export, y compris à 844x390 et à 360 de large.
- [ ] Un changement d'onglet s'affiche à l'image suivante, sans chute sous 55 images/s.
- [ ] Réglages s'ouvre et se ferme depuis l'en-tête à chaque taille, avec tout son contenu atteignable.
- [ ] Aucune information accessible seulement au survol.
- [ ] Un glissé dans une liste n'achète jamais ; un appui long n'active jamais.
- [ ] Touches et ordre de focus conformes à l'Interaction Map.
- [ ] Sauvegardes de la version en ligne et des formats 1 à 4 chargées, sans clé ajoutée.
- [ ] x10 et Max dépensent exactement la même somme que N achats simples.
- [ ] Le monstre, les textes et les boules restent alignés après chaque changement de forme, y compris sur un boss.
- [ ] 60 images/s stables dans l'export, avec 8 compagnons et clics rapides, ou écart mesuré noté ; même mesure avec processeur ralenti ; référence d'avant le changement.
- [ ] L'erreur de données masque onglets et jeu.
- [ ] Les 246 tests restent verts.

---

## Open Questions

Décisions d'Amaury, toutes acceptées le 2026-11-01 selon la recommandation :

- **D1. Pause.** Aujourd'hui Talents et Objets arrêtent le jeu, chrono de boss compris. Recommandation : les onglets ne mettent pas en pause, sinon l'idle s'arrête quand un onglet reste ouvert. C'est un changement de comportement à accepter, malgré « logique inchangée ». Seuls Réglages et le retour d'absence attendent.
- **D2. Raccourcis.** 1/2/3 n'existent pas aujourd'hui, et le monstre n'est pas attaquable au clavier. Recommandation : ajouter 1/2/3, et rendre le monstre focalisable (Espace ou Entrée, sans répétition en maintien). Manette : pas de prise en charge dédiée, malgré `ui-code.md`.
- **D3. x10 et Max.** Recommandation : x10 strict, désactivé si l'or manque ; Max affiche la quantité réelle. Exige d'ajouter un achat par lot dans le cœur du jeu, à coûts identiques. Coût de Max à mesurer d'abord. Story 013 : plus de « manque X », le coût seul ; ajout de Palier, tout ou rien jusqu'au prochain palier ; chaque ligne compagnon passe à 3 lignes de texte, la barre à droite du texte de palier sur toute la largeur de la ligne, et le seuil de lignes visibles à 320x568 passe de 2,5 à 2.
- **D4. Point de notification.** « Quand une action est possible » resterait allumé en permanence dans un idle. Recommandation : sur événement (nouveau compagnon ou palier, nouveau nœud achetable, nouvel objet gardé), éteint à la visite, jamais sur l'onglet ouvert, avec compteur de points de talents.
- **D5. Détail tactile.** Recommandation : toucher ouvre le détail, puis bouton Acheter ou Équiper. Confirmation avant la remise à zéro des talents.
- **D6. Plusieurs doigts.** Recommandation : chaque doigt compte comme un clic, à prendre en compte dans le réglage du mur.
- **D7. Onglets.** Recommandation : en bas de la zone de gestion, sous le pouce.
- **D8. Exigences.** `ui-code.md` impose taille de texte réglable et mode daltonien. Recommandation : double codage à la place du mode daltonien, taille de texte reportée, aucune promesse de lecteur d'écran ; décors de la zone de jeu génériques en attendant les chats.

Points ouverts techniques :

- Mesuré dans l'export web le 2026-11-01 : un prix coûte 39 ms au niveau 400, 150 ms au niveau 1000 ; 100 niveaux coûtent 2,8 s à partir du niveau 400, 13,9 s à partir du niveau 1000. Max n'est pas faisable sans accélérer le calcul : division par une puissance de 10 en décalage de chiffres, et somme incrémentale, à résultats exacts identiques (story 010).
- Plancher de 0,88 et seuils de forme (1,10 et 1,20) : valeurs de départ, à ajuster sur téléphone réel.
- Point de notification : compteur seulement sur Talents, où il existe ; Compagnons et Objets montrent la pastille seule.
- Saccade à la première préparation des tailles de texte, et effet d'un redimensionnement sur le cache de glyphes : à mesurer.
- Encoche : l'export ne lit pas les zones sûres ; le fond de la page comble l'espace, sans `viewport-fit=cover`.
- `SaveText` sur téléphone sans clavier virtuel : la copie à vérifier.
- Mesures réelles sur iPhone et Android impossibles ici, à faire par Amaury.
- Carte de parcours joueur non créée (modèle `.claude/docs/templates/player-journey.md`).
- Palier d'accessibilité non défini.
