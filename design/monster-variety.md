# Variété des monstres

> **Status**: Approuvée par Amaury le 2026-11-02
> **Story**: 021

## Règles

| Sujet | Règle |
|---|---|
| Cosmétique | Aucun effet sur PV, or, dégâts, butin, zone de clic, sauvegarde |
| Générateur | Un troisième générateur dédié, jamais celui des objets ou des critiques |
| Tirage | Un seul appel au dé, sans boucle ; un candidat unique se répète sans dé |
| Répétition | Jamais le même deux fois de suite pour l'ennemi affiché, id unique dans tout le fichier |
| Cadence | L'apparence et le nom changent au plus toutes les `appearance_min_seconds`, 0,6 s, avec ou sans Effets visuels |
| Zones | Fenêtre glissante : la zone z prend les formes z, z+1, z+2 modulo la liste ; une zone couvre 10 étages, boss compris |
| Boss | Fixé par zone, même adversaire après un échec |
| Couleur | Portée par la variante ; le halo porte l'identité de zone, 5 teintes en cycle |
| Au-delà de la fin | Modulo, aucune liste vide |

Le plafond de 0,6 s déroge à « jamais deux fois de suite » à l'écran au-delà de 1,67 kill/s : accepté contre le clignotement. Le tirage sous ce plafond respecte la règle. Un boss entre et sort aussitôt, et une apparence absente de la zone est retirée.

## Catalogue

`assets/data/monster_appearances.json` : `monsters`, `bosses`, `zone_size`, `window_size`, `appearance_min_seconds`, `zone_tints`. Chaque entrée : `id`, `name`, et `drawn` ou `image` avec `anchor` en pixels.

`src/core/monster_catalog.gd` : pur, lecture, validation, tirage injecté. `src/ui/monster_art.gd` : cache de textures et repli.

Données invalides : repli et avertissement console, jamais l'écran d'erreur. Un test bloquant vérifie le fichier réel : zéro problème, tous les étages couverts, au moins 2 entrées par liste.

## Variantes

| id | Nom provisoire | Silhouette | Corps |
|---|---|---|---|
| `chat_rond` | Boule de Poils | Cercle, 2 oreilles pointues | `#5A9BD0` |
| `chat_trapu` | Gros Matou | Ellipse large, oreilles rondes | `#E0823A` |
| `chat_boite` | Chat en Boîte | Carré, rabats de carton | `#BC9660` |
| `chat_efflanque` | Grand Maigre | Ellipse haute, oreilles à touffes | `#A78BC9` |
| `chat_herisse` | Poil Hérissé | Disque à pointes, oreilles couchées | `#76A860` |
| `chat_aile` | Chauve-Chat | Cercle réduit, ailes | `#3CA89F` |
| `chat_cyclope` | Œil-de-Chat | Poire, une corne, un œil | `#E07FA0` |

Deux formes diffèrent sur au moins 2 axes : masse, haut, côtés. Les corps ont une luminance proche, pour que la forme distingue les variantes et limite le contraste entre deux monstres. Or et rouge restent réservés.

Boss : médaillon dessiné par le code (disque, anneau, couronne séparée de l'anneau), pupille en fente. Noms provisoires : Roi Matou, Grand Griffu, Mère Griffe, Ronron Titan. Ton : familier pour les monstres, épique pour les boss.

## Rendu

- `set_stage(stage, is_boss, look = null)` : `null` garde le dessin actuel.
- Le fantôme garde toute l'ancienne apparence.
- `anchor_global()` et `hit_radius()` ne lisent jamais l'apparence.
- Budget : 24 primitives par monstre, `_draw` à 1 ms au plus au processeur ×4.

## Nom

Ligne de 23 u à 16 u sous la barre de vie, toutes formes, hauteur toujours réservée, sans animation. `MONSTER_ROW_MIN` passe de 120 à 106 u. Largeur mesurée à 191 u au plus, environ 20 caractères ; filet par points de suspension sur les tailles non testées. Le test de 2 lignes à 320x568 calcule sa valeur depuis `AdaptiveLayout`.

## Dessins

| Sujet | Règle |
|---|---|
| Fichier | `assets/art/monsters/monster_<id>.png`, 512 px, transparent, `.png` et `.import` versionnés |
| Import | Avec perte, mipmaps actives, `fix_alpha_border` |
| Poids | 150 Ko au plus par image, 100 Ko en moyenne, 15 Mo gzip au total |
| Chargement | `ResourceLoader.exists` puis `load`, jamais `FileAccess.file_exists` ni `has_alpha` |
| Mémoire | 32 Mio de textures au plus, préchargement par zone |
| Ancre | Pixels de l'image, tout le dessin tient dans ±256 px autour d'elle |
| Hébergeur | GitHub Pages |

Preuve de l'export : une sonde dans un clone jetable avec témoin négatif, sans image livrée. Le téléphone de référence reste à fixer pour la passe sur appareil.

Hors périmètre : bestiaire, message « nouveau monstre », marque de cycle.
