# Story 019b: Refonte UI/UX mobile

> **Epic**: Idle Titans (MVP)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: XL
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-12

## Context

**GDD**: N/A (minimal) ; maquette validée `production/design/ui-refonte/` (option B, compétences fixes), spec UX de base `design/ux/main-screen-adaptive.md`
**Requirement**: hors brief MVP, écran mobile peu lisible ; reprendre la hiérarchie de TT2 (panneau déployable, lignes à structure fixe, un seul bouton d'achat, onglets colorés) demandée par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Consulter `docs/engine-reference/godot/` avant tout appel d'API. Export web : stretch `canvas_items` / `expand` / `fractional`, échelle pilotée par `AdaptiveLayout` (plancher 0,88 px CSS par u).

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

Aucun changement d'économie, de monstres ni de moteur. Analyse : `ux-designer` et `accessibility-specialist`, 2026-11-03, avant toute écriture.

---

## Spec retenue (portrait 390x742 u, proportionnelle ailleurs)

- **Échelle** : la largeur fixe l'échelle (base 390 u de large), la hauteur se répartit. Fixe : en-tête 52 + compétences 68 + onglets 56. Panneau ≥ max(45 % de la hauteur, 243 u) ; scène bornée entre 160 et 208 u, elle cède avant le panneau ; tout surplus va au panneau.
- **En-tête 52 u** : « Étage N » + « Record N » (14 u) à gauche ; or au centre (26 u, pièce, contour noir) avec le **DPS total en 14 u dessous, visible sur les 3 onglets** ; réglages à droite (roue, 44 u visuels).
- **Scène** : monstre centré ; 8 souris vectorielles de 38 u (4 à gauche, 4 à droite, décoratives : ni toucher ni focus) ; PV 30 u en bas, texte 16 u contouré ; bouton « Boss » 44 u en surimpression en haut à droite, visible quand `farming` ; pendant le combat ce coin devient « Abandonner », et le chrono est une bande fine au-dessus des PV, avec les secondes en chiffres.
- **Compétences** : rangée fixe 68 u, 3 ronds de 56 u (rangée dessinée pour 5 sans refonte) : anneau de recharge, pastille de secondes (14 u), halo + anneau plein quand prête, cadenas tant qu'un talent ne l'a pas débloquée, état Passif (icône grisée sans anneau, « Passif » dans la bulle). Icône seule ; le nom reste dans la bulle (appui long, focus) et dans le nom accessible. Touches 1/2/3 inchangées.
- **Panneau** : poignée 22 u (zone tactile de toute sa bande) qui replie et déploie ; repli mémorisé dans `DisplaySettings` ; toucher un onglet déploie. En-tête 46 u propre à chaque onglet. Pas de poignée en paysage.
- **Souris** : en-tête « DPS total » + un bouton « Achat ×N » ; un appui avance ×1 → ×10 → ×100 → Max → Palier → ×1, icône de rotation à la place du chevron. ×100 ajouté en fin de `BuyQuote.Mode` pour garder le mode déjà enregistré. Lignes 70 u : portrait 52 u (vectoriel, prévu pour des textures), nom gras 16 u + « Niv. N » bleu, « DPS · part % » gris 14 u (part du DPS des compagnons), ligne d'éveil (barre + « Éveil N ») ; bouton 112x56 u : coût (16 u gras) / « +X DPS » (14 u). États : jaune (payable), gris (pas assez, bord), violet « Éveil II + coût » avec « Niveau bloqué : éveil requis », « Max » (mode Palier après le dernier palier) ; niveau 0 : « Acheter ».
- **« +X DPS »** : calcul d'interface en lecture seule, DPS actuel × (`Companion.damage_at_level` au niveau visé ÷ au niveau actuel) − DPS actuel.
- **Objets** : 4 emplacements équipés (48 u visuels, bord de rareté) + « Sac N / 12 » (`inventory_capacity`) ; lignes 70 u : bande de rareté, nom + rareté en toutes lettres, bonus gras, ligne grise « Équipé : +X % » (pas de niveau d'objet dans les données) ; « Équiper » (vert) équipe depuis la ligne, le reste de la ligne ouvre la comparaison ; « Équipé » grisé avec coche.
- **Talents** : écran de la story 019 conservé (fonctions, tests, noms uniques), mis dans la coquille ; « N points à dépenser » (32 u jaune), Reset sur 2 lignes ; 3 branches aux noms actuels ; tuiles 64 u minimum, extensibles ; coût réel ; coche en plus du mot d'état.
- **Onglets bas 56 u** : Souris / Objets / Talents, icône + libellé, liseré par onglet, actif plus clair, pastille rouge numérotée avec bord clair.
- **Réglages** : « Défi auto », version, et un bouton « Plein écran » (API Fullscreen sur geste).
- **Paysage 1280x720** : en-tête pleine largeur ; à gauche la scène et les compétences (environ 540 u) ; à droite le panneau (environ 720 u) avec ses onglets ; talents en arbre complet.
- **Couleurs** : fond #0F1220, panneau #171B33, ligne #1F2445, jaune #FFC247 (texte #1A1300), bleu #7CC0FF, gris texte #A9B1CC, violet #6E40E8, vert #167A42, rouge boss #B3261E ; texte grisé sur bouton gris ≥ #9AA1BC ; bord « Commun » éclairci à ≥ 3:1.
- **Accessibilité** : cibles visuelles de 44 u et 48 u avec zone tactile invisible de 50 u (44 px CSS au plancher) ; 16 u minimum pour noms, coûts et actions ; 14 u pour le secondaire signalé : « Record N », DPS de l'en-tête, « DPS · part % », « +X DPS », ligne grise des objets, pastille de secondes, « x / y points ». La couleur n'est jamais le seul signal.

## Acceptance Criteria

Cochés au lot 9 (2026-11-12), un par un ; la preuve suit chaque critère.

- [x] Portrait : en-tête, scène, compétences, panneau et onglets aux hauteurs de la spec à 390x742 ; règle de repli testée à 360x640 et 320x568.
  - Preuve : `adaptive_layout_test.gd` (742 → scène 208 / panneau 358 ; 693 → 205 / 312 ; 645 → 178 / 291, lot 2) ; captures `lot9-w390x742`, `-w360x640`, `-w320x568`.
- [x] Aucun débordement horizontal de 320 à 2560 de large, avec « Étage 999 » et « 999,9 Qa ».
  - Preuve : export avec la partie `?seed=max`, largeur de page égale à la largeur de fenêtre à 320, 360, 390, 412, 768, 1024, 1280, 1920 et 2560 de large, plus 844x390 et 915x412 (lot 9) ; audit des 18 tailles, 0 élément hors de l'écran.
- [x] Le DPS total est visible dans l'en-tête sur les 3 onglets.
  - Preuve : captures `lot9-*`, `-objets` et `-talents` aux 8 tailles (« 458,3 M DPS » sous l'or).
- [x] Boss visible seulement si `farming` ; pendant le combat, « Abandonner » et un chrono en bande fine avec les secondes ; rien ne se décale quand il apparaît.
  - Preuve : `game_zone_layout_test.gd` (les rectangles ne dépendent pas de ce qui est visible), `confirm_press_test.gd` ; captures `lot3-*` (combat, « Confirmer ? »).
- [x] Compétences en ronds aux états prêt, recharge, cadenas et passif, nom dans la bulle ; touches 1/2/3 inchangées.
  - Preuve : `skill_bar_rounds_test.gd` (12) ; captures `lot4-*` et `lot4c-*`.
- [x] Poignée qui replie et déploie au toucher et au clavier, état mémorisé ; panneau replié sans contrôle focalisable caché.
  - Preuve : `panel_shell_test.gd` (21), `display_choices_test.gd` ; captures `lot5-*-replie` et `lot5k-*`.
- [x] Un seul bouton d'achat qui cycle ×1, ×10, ×100, Max, Palier ; ancien mode enregistré relu sans décalage.
  - Preuve : `buy_quote_test.gd` (cycle, ×100), `display_choices_test.gd` (mode 4 ajouté à la fin, anciens modes relus) ; captures `lot6-*-x10` à `-palier`.
- [x] « +X DPS » égal au gain réel après achat (test, Champion excepté).
  - Preuve : `companion_gain_test.gd` (12), vu en échec contre deux sabotages (lot 6).
- [x] Lignes Souris, Objets et Talents conformes à la spec ; « Équiper » sur la ligne, comparaison toujours accessible.
  - Preuve : `companion_rows_test.gd`, `inventory_rows_test.gd`, `talent_shell_test.gd` ; captures `lot6-*`, `lot7-*`, `lot8-*`, `lot9-*`. Écart connu : 5 emplacements d'objets (un par type des données), la spec en disait 4.
- [x] Talents : fonctions, noms uniques et tests de la story 019 conservés (adaptés, jamais désactivés).
  - Preuve : `talent_screen_v2_test.gd` et `talent_pane_test.gd` toujours dans la suite, 994/994 ; aucun test désactivé (lot 8).
- [x] « Défi auto », version et « Plein écran » dans Réglages, plus sur l'écran principal.
  - Preuve : `settings_toggles_test.gd` ; captures `lot2-*-reglages`. « Plein écran » sur un vrai téléphone : à la charge d'Amaury (liste ci-dessous).
- [x] Contraste ≥ 4,5:1 pour tout texte et ≥ 3:1 pour les signaux non textuels, couverts par `main_theme_contrast_test.gd`.
  - Preuve : ce test, dans la suite 994/994 ; les styles `ItemRow*` retirés du thème n'y sont plus contrôlés (lot 9), ceux des cartes d'objets le restent.
- [x] Cibles ≥ 44 px CSS, textes ≥ 14 u, contrôlés par la sonde dans l'export.
  - Preuve : `lot9-audit-18-tailles.txt`, 0 problème sur 18 tailles et 3 onglets : cibles de 50 u au moins, soit 44 px CSS au plancher de 0,88 px par u ; boutons en 16 u, textes en 14 u au moins. **Écart** : la sonde tourne sur la vraie scène sans affichage, pas dans l'export ; dans l'export, le plancher de 0,88 est tenu par `adaptive_layout_test.gd` et les tailles se voient sur les captures.
- [x] Captures dans l'export à 390x742, 360x640, 412x915, 1280x720, plus 320x568, et audit des 18 tailles de la story 019.
  - Preuve : captures `lot9-*` à ces 5 tailles, plus 844x390, 915x412 et 853x480 à 1,5 (zoom 150 %) ; `lot9-audit-18-tailles.txt`.
- [x] Essai sur le téléphone d'Amaury après le lot 5, avant les lots 6 à 9.
  - Preuve : retour d'Amaury du 2026-11-04, « lots 6 et 7 : bon » ; lots 8 (talents) et 9 (paysage) essayés par Amaury le 2026-11-12 avec la liste ci-dessous : « tout est bon ».

---

## Out of Scope

- Mode économie (story 022), monstres (021), courbes d'économie (020), contenu de l'arbre de talents (noms et nombre des branches).
- Installation sur l'écran d'accueil (PWA, manifest).
- Vrais dessins des souris : vectoriel simple en attendant.

---

## Lots

0. Fiche et EPIC.
1. Jetons de couleur et test de contraste.
2. Hauteurs en portrait, en-tête (DPS sous l'or), Réglages (Défi auto, version, Plein écran).
3. Scène : souris, Boss conditionnel, Abandonner et chrono.
4. Compétences en ronds.
5. Coquille du panneau (poignée, en-tête par onglet, Achat ×N), onglets du bas. **Essai téléphone.**
6. Lignes Souris et test du « +X DPS ».
7. Objets.
8. Talents dans la coquille, audit des 18 tailles.
9. Paysage, audit final, preuves.

---

## Files

- `src/ui/main_theme.tres`, `adaptive_layout.gd`, `game_zone.gd`, `main_screen.gd`, `main_screen.tscn`, `save_screen.gd`, `save_screen.tscn`, `companion_orbs.gd`, `boss_timer.gd`, `boss_timer.tscn`, `skill_bar.gd`, `skill_bar.tscn`, `management_tabs.gd`, `companion_panel.gd`, `companion_panel.tscn`, `buy_quote.gd`, `inventory_screen.gd`, `inventory_screen.tscn`, `talent_screen.gd`, `talent_screen.tscn`
- Nouveaux : `src/ui/skill_orb.gd` (lot 4), `panel_handle.gd`, `pane_header.gd`, `header_button.gd` (lot 5), `mouse_portrait.gd` (lot 6), `item_icon.gd` (lot 7), `talent_tile.gd` (lot 8) ; lecture pure `FloorManager.companion_dps_at` (lot 6)
- `src/core/display_settings.gd` (repli du panneau, mode ×100)
- Tests à adapter : `tests/unit/ui/main_theme_contrast_test.gd`, `adaptive_layout_test.gd`, `companion_panel_*_test.gd`, `buy_quote*_test.gd`, `inventory_pane_test.gd`, `management_tabs_test.gd`, `talent_screen_v2_test.gd`, `talent_pane_test.gd` ; nouveau `talent_shell_test.gd` (lot 8)

## QA Test Cases

*Panneau replié puis rotation ; boss qui apparaît pendant un tapotage ; glissé dans la liste sans achat ; appui long sur une compétence ; ×100 avec moins de 100 niveaux possibles ; ancien mode d'achat enregistré ; sac plein ; noms les plus longs à 320 px ; zoom Chrome 150 %.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures dans `production/qa/evidence/story-019b-mobile-ui-refonte/`, tests dans `tests/unit/ui/`.

**Status**: [x] Lots 0 à 9 faits ; preuves finales au journal « Lot 9 » ; suite 994/994 ; essai téléphone des lots 8 et 9 fait (Amaury, 2026-11-12). Lot 1 : captures `lot1-*` à 390x742, 360x640, 412x915, 1280x720 et 320x568 (export web, Edge headless, aucune erreur console, scrollWidth = innerWidth), `stamp.txt` ; suite 832/832.

**Journal des lots**

- Lot 1 (2026-11-03) : `src/ui/ui_palette.gd` (jetons), `main_theme.tres` (mêmes types, nouvelles valeurs ; `BuyButton` jaune à texte #1A1300 ; `ToggleButton` et `EquipButton` verts ; `AwakenButton` violet ; pastille rouge à bord blanc ; `TEXT_DISABLED` réservé à l'état désactivé ; anneau de focus blanc à ombre #0F1220), `main_screen.tscn`, `game_zone.gd`. Écart : fond de la jauge des PV #2E0C10 au lieu de #4A1418 (2,67:1 contre la jauge, vu en échec). Inchangés jusqu'à leur lot : branches de talents (8), orange du DPS (2), compétence active (4). Captures sur partie neuve : vert, violet et pastille couverts par les tests seulement.
- Lot 2 (2026-11-03) : `AdaptiveLayout.portrait_scene` / `portrait_panel` (742 → 208 / 358 ; 693 → 205 / 312 ; 645 → 178 / 291 ; 866 → 208 / 482) ; `GameZone` portrait = scène + rangée de compétences 68 u, PV 30 u en bas, chrono en bande de 22 u au-dessus (secondes en chiffres, `BossTimer.set_compact`), coin « Boss » / « Abandonner » en haut à droite (104 x 50 u, au-dessus du monstre dans l'arbre pour rester touchable) ; « Abandonner » demande « Confirmer ? » pendant 3 s (`ConfirmPress`, aucune protection n'existait) ; en-tête d'une ligne : étage 20 + « Record » 14, bouton central (pièce, or 26 contouré, DPS 14, triangle « s'ouvre », nom accessible « Détail du DPS », 50 u de haut), roue de 50 u (nom accessible « Réglages ») ; `UiIcon` (roue, pièce, triangle) ; Réglages : « Défi auto », « Plein écran » (export web et `document.fullscreenEnabled` seulement, état relu à chaque redimensionnement). Écarts : le placement de Boss, Abandonner et du chrono avancé du lot 3 au lot 2 ; coin dessiné à 50 u (44 u visuels au lot 3) ; coin à 104 u au lieu de 112 (chevauchait le monstre à 363 u, vu en échec). Paysage : version et « Défi auto » retirés, compétences sur toute la colonne. Suite 854/854. Captures `lot2-*` aux 5 tailles et `-reglages` à 390x742 et 1280x720. **Pas de capture d'un combat de boss** (partie neuve, étage 1) : couverts par `game_zone_layout_test` et `confirm_press_test`, à capturer au lot 3. Limite connue : à 178 u de scène et moins, les orbes actuelles touchent de quelques unités le bas du coin et la bande du chrono ; les souris du lot 3 seront placées à nouveau.
- Lot 3 (2026-11-03) :
  - **Souris.** `MouseFace` dessine une souris de 11 cercles : tête, oreilles à intérieur rose, yeux, nez, contour. `CompanionOrbs` ne dessine plus ces cercles à chaque image. Chaque souris est peinte une fois dans un atlas, au double des pixels de l'écran. L'atlas n'est repeint que si la taille des souris ou des pixels change. Deux atlas alternent : l'ancien reste affiché, étiré, jusqu'au rendu du nouveau.
  - **Placement.** `GameZone` donne aux souris 38 u, 20 u au minimum, autour du monstre. Elles ne touchent ni le coin, ni les PV, ni le chrono, ni le monstre : c'est testé à 178, 190, 205 et 208 u de scène, à 363 et 390 de large.
  - **Coin Boss / Abandonner.** Il est dessiné à 44 u dans une zone touchable de 50 u (`expand_margin` négatif), avec la flèche `UiIcon.ARROW`. L'état « Confirmer ? » a un bord blanc.
  - **Chrono.** Jaune, rouge à la fin, sur fond `PANEL`.
  - **Outils.** `tools/web/` contient `browser.mjs`, `capture.mjs`, `perf.mjs` et un README. Edge y est toujours fermé, avec un profil temporaire. Variables : `BROWSER_PATH`, `BROWSER_HEADLESS`, `BROWSER_WINDOW_POSITION`, `BROWSER_TIMEOUT_MS`.

  Fluidité, processeur ×4, 5 passages alternés avec la référence (dernier commit), occupation médiane du fil principal (`lot3-fluidite-headless.txt`, `lot3-fluidite-fenetre.txt`) :

  | Mesure | Portrait (réf. / lot 3) | Paysage (réf. / lot 3) |
  |---|---|---|
  | Sans fenêtre | 21,4 / 20,9 % | 20,9 / 20,5 % |
  | Fenêtre visible | 18,8 / 17,6 % | 19,1 / 17,9 % |

  En fenêtre visible, il y a 0 à 2 images de plus de 33 ms par passage dans les deux versions, et l'image médiane est à 16,7 ms. Critère retenu : pas plus de 1,5 point au-dessus de la référence ; il est atteint.

  **Erreur de mesure, corrigée :**
  - Jusqu'ici, la mesure touchait toujours (195, 126). En portrait, ce point est au-dessus du monstre de la référence, qui est vers (195, 197). La référence en portrait ne recevait donc aucun coup et paraissait moins coûteuse.
  - Ces résultats étaient donc faux : l'écart « 1 à 5 contre 18 à 32 images de plus de 33 ms » de la première mesure, et les « +1,5 point des lots 1 et 2 ».
  - Ce qui reste valable : le coût des souris dessinées en cercles, mesuré entre variantes de la même disposition. Il valait environ 1,5 point, et c'est ce qu'enlève l'atlas.
  - L'erreur a été trouvée en comptant les redessins par nœud : le monstre de la référence n'était jamais redessiné.
  - `perf.mjs` accepte maintenant `touch:<version>:<forme>=X,Y`.

  Sans fenêtre, les temps d'image ne montrent rien : on compare sur l'occupation.

  **Écart avec le plan :** le dessin vectoriel reste la source, mais l'affichage passe par l'atlas.

  **Tests :**
  - 5 tests d'atlas dans `visual_feedback_test.gd`. En headless, Godot ne rend rien : le test vérifie la préparation de l'atlas, pas son affichage. Le premier test d'affichage a échoué pour cette raison et a été remplacé.
  - Suite 866/866.

  **Preuves :**
  - Captures `lot3-*`, refaites avec l'atlas : combat, « Confirmer ? » et retour à 390x742, 360x640 et 320x568 ; 412x915 ; 1280x720 combat et « Confirmer ? ». Aucune erreur console, aucun défilement horizontal.
  - `lot3-nettete-souris.png` : souris avant et après, agrandies ×3, aux 3 tailles de portrait. Elles sont aussi nettes, avec des bords plus lisses.
  - Clignotement : 253 images enregistrées pendant 6 redimensionnements, rotation comprise ; les souris ne disparaissent dans aucune.
  - Les captures viennent d'une copie jetable avec une partie préparée : étage 199, mode farm, 8 compagnons niveau 1.
- Lot 4 (2026-11-04) :
  - **Ronds.** `SkillOrb` (bouton sans texte) dessine son état : prête (anneau plein jaune et halo), en cours (arc jaune du temps restant, pastille jaune de secondes), recharge (arc gris de la part faite, pastille sombre), cadenas, passif (icône grise sans anneau). Icônes `UiIcon` : étoile (Gros coup), éclair (Frénésie), pièce (Bonus d'or), cadenas ; `UiIcon.draw_kind` permet de les dessiner depuis un autre contrôle.
  - **Nom.** Le nom n'est plus dessiné : il ouvre la bulle (« Nom » puis l'effet ; « Passif : … » pour une compétence passive) et commence le nom accessible (« Frénésie, Dans 42 s »). Touches 1/2/3 inchangées.
  - **Appui.** Il agit au relâchement. La zone touchable est un disque de 64 u (32 u de rayon, moins dans une cellule étroite), et non toute la cellule : un doigt qui sort du disque annule l'appui. Un appui long ouvre la bulle et le relâchement n'active rien. **Écart avec le plan** (qui prévoyait toute la cellule), pour que « sortir du rond » ait un sens.
  - **Coût.** L'arc avance par pas de 1/120 de tour, et un rond n'est redessiné que quand son pas, ses secondes ou son état changent.
  - **Place.** La rangée tient 5 ronds de 56 u à 320 de large (testé). En paysage, les ronds sont empilés dans la colonne, en attendant le lot 9.
  - **Tests.** `skill_bar_rounds_test.gd` (12) : états, nom accessible, icônes, zone, place pour 5, appui au relâchement, doigt qui sort, appui long. Les appuis passent par le vrai viewport (`push_input`). Le test du doigt qui sort et celui de l'appui long ont été vus en échec contre un sabotage (zone rectangulaire, bulle sans `_forget_button_press`), puis le code a été remis. Contraste : anneaux, icônes et pastille. `talent_screen_v2_test` et `talent_glyphs_test` lisent maintenant le nom accessible au lieu du texte du bouton. Suite 881/881.
  - **Outils.** `capture.mjs` : étapes `+hX,Y,MS:nom` (appui long, capture pendant l'appui) et `+kCode:nom` (touche). `perf.mjs` : `PERF_KEYS` (touches après chargement).
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`36530d8`), occupation médiane du fil principal (`lot4-fluidite-*.txt`) :

    | Mesure | Portrait (réf. / lot 4) | Paysage (réf. / lot 4) |
    |---|---|---|
    | Sans fenêtre | 8,6 / 8,8 % | 8,1 / 8,3 % |
    | Sans fenêtre, Gros coup en recharge (`PERF_KEYS=Digit1`) | 8,1 / 8,9 % | 8,1 / 8,7 % |
    | Fenêtre visible | 8,5 / 8,5 % | 8,6 / 8,9 % |

    Aucune image de plus de 33 ms pour le lot 4. Écart maximal +0,8 point, sous le critère de 1,5 point. Le niveau absolu (≈ 8 % contre ≈ 20 % au lot 3) a changé d'une série à l'autre, pour les deux versions : on ne compare qu'à l'intérieur d'une série. Les touchers tombent bien sur le monstre (PV 22 → 20 après deux touchers, capture de contrôle).
  - **Preuves.** Captures `lot4-*` (partie préparée, Frénésie et Bonus d'or débloqués) : état initial, puis touches 1 et 2 (`-etats` : recharge, en cours, prête), appui long sur Bonus d'or (`-bulle`), après relâchement (`-relache` : toujours prête). Captures `lot4c-*` (Instinct de meute) : prête, passif, cadenas. Aux 5 tailles ; pas d'appui long en paysage. Aucune erreur console, aucun défilement horizontal.
- Lot 5 (2026-11-04) :
  - **Poignée.** `PanelHandle` en haut du panneau, en portrait seulement. Elle replie ou déploie au toucher, et avec Entrée ou Espace quand elle a le focus ; son nom accessible est « Replier le panneau » ou « Déployer le panneau ». Bande de 22 u ; replié, l'en-tête disparaît et la bande passe à 50 u pour rester une cible. Le repli est mémorisé dans `DisplaySettings.panel_collapsed` (non par défaut). Toucher un onglet d'un panneau replié le déploie sur cet onglet. En paysage, pas de poignée et panneau ouvert, mais le choix reste pour le portrait.
  - **Zone étendue de la poignée.** C'est la partie libre de l'en-tête de chaque onglet (`PaneHeader`, bouton plat sans focus), placée entre ce que montre l'en-tête et son action. Elle ne recouvre jamais « DPS des souris » ni « Achat ×N » (testé, demande d'Amaury). **Écart avec le plan** : au lieu d'agrandir la zone de la poignée vers le bas (`_has_point`), l'en-tête porte lui-même cette partie libre. La sélection de Godot s'arrête au premier contrôle qui ne laisse pas passer la souris, si bien qu'un agrandissement aurait été masqué par les conteneurs de l'onglet.
  - **Replié.** Les contenus sont masqués, jamais libérés. L'ordre du clavier devient compétences → poignée → onglet ouvert → suite, sans aucun contrôle caché. La scène prend la hauteur rendue (`AdaptiveLayout.portrait_scene_collapsed`, sans plafond) : 516 u à 390x742.
  - **Monstre d'une scène haute (trouvé par les tests).** En portrait, la largeur du monstre est maintenant limitée pour laisser deux colonnes de souris de chaque côté (`GameZone.portrait_box`). Panneau ouvert, rien ne change : c'est la hauteur qui limite (testé à 178 et 208 u). Sans cette limite, à 419, 516 et 640 u, quatre souris touchaient le monstre (vu en échec).
  - **En-tête Souris** (46 u) : « DPS des souris » (titre 14 u gris, valeur 20 u orange). Il se touche (`HeaderButton`, dessiné à 44 u, touché sur 50 u en montant de 4 u dans la bande de la poignée) et ouvre le même détail que le centre de l'en-tête du haut. Bouton « Achat ×N » avec bord bleu et icône de rotation (`UiIcon.ROTATE`) ; sa largeur est mesurée sur le plus long des 5 textes.
  - **Modes d'achat.** `BuyQuote.Mode.HUNDRED` = 4, ajouté à la fin, donc les modes déjà enregistrés gardent leur valeur ; ×100 suit la règle de ×10 (tout ou rien, jamais au-delà du seuil d'éveil). `BuyQuote.CYCLE` : ×1 → ×10 → ×100 → Max → Palier → ×1. Le sélecteur à 4 segments est retiré.
  - **En-têtes Objets et Talents.** Objets : « Sac N / M », sorti de la liste. Talents : la ligne existante (points et « Réinitialiser »), dont la hauteur reste 50 u à cause du bouton, jusqu'au lot 8. Leur contenu complet est prévu aux lots 7 et 8.
  - **Onglets du bas.** Souris / Objets / Talents, avec icône (`UiIcon.MOUSE`, `SHIELD`, `STAR`) et libellé. Liseré de couleur sur l'onglet ouvert : corail `UiPalette.TAB_MICE`, jaune, violet `VIOLET_EDGE`. Libellé clair sur l'onglet ouvert, gris sur les autres. La pastille de Talents porte le nombre de points (blanc sur rouge), reste visible tant qu'il reste des points (elle remplace « Talents (N) »), et le nom accessible dit « Talents, N points ».
  - **Tests.** Nouveau `panel_shell_test.gd` (21) : repli et déploiement par la poignée, Entrée, l'en-tête et un onglet ; ordre du clavier une fois replié ; paysage ; zones de l'en-tête ; défilement gardé après un repli et après le retour de la barre du navigateur ; onglets, pastille, liserés. Ajouts dans `buy_quote_test` (×100, cycle), `buy_quote_awakening_test` (×100 à moins de 100 niveaux du seuil), `display_choices_test` (×100 relu, mode 4 valide, repli), `adaptive_layout_test` (hauteurs repliées), `game_zone_layout_test` (scènes repliées, monstre), `main_theme_contrast_test` (onglets, pastille, en-tête, poignée). Tests adaptés : les 3 tests des segments deviennent 5 tests du bouton unique ; deux tests de `companion_panel_awakening_test` mesurent maintenant le texte (`get_minimum_size`) et non la hauteur que se partagent les lignes, qui a gagné 2 u. Vus en échec contre un sabotage, puis code remis : l'ordre du clavier une fois replié, la partie libre qui ne recouvre pas les boutons ; les souris d'une scène haute ont échoué contre l'ancien code. Suite 925/925.
  - **Outils.** `perf.mjs` : `tap:<version>:<forme>=X,Y` (un toucher après chargement) et `PERF_FRESH=1` (stockage vidé avant chaque chargement).
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`9c647d2`, lot 4), occupation médiane du fil principal (`lot5-fluidite-*.txt`) :

    | Mesure | Portrait (réf. / lot 5) | Paysage (réf. / lot 5) |
    |---|---|---|
    | Sans fenêtre | 6,7 / 6,7 % | 6,6 / 6,7 % |
    | Sans fenêtre, parties neuves, panneau replié en plus (`PERF_FRESH=1`) | 6,7 / 6,6 / replié 6,2 % | 6,7 / 6,9 / 6,8 % |
    | Fenêtre visible | 6,6 / 6,7 % | 6,7 / 6,7 % |

    Écart maximal +0,2 point ; aucune image de plus de 33 ms. Panneau replié, les touchers visent le monstre déplacé (195, 280) ; contrôle : PV 22 → 20 après deux touchers.
  - **Preuves.** Captures `lot5-*` aux 5 tailles (partie préparée) : état initial, `-x10`, `-x100`, `-detail` (« DPS des souris » touché), `-ferme`, `-replie`, `-objets` (toucher un onglet déploie), `-talents` ; en paysage `-x10`, `-x100`, `-detail`. `lot5k-*` (390x742, clavier) : `-focus-poignee`, `-entree-replie`, `-tab-suivant` (l'onglet ouvert reçoit le focus). Aucune erreur console, aucun défilement horizontal.
- Lot 6 (2026-11-04) :
  - **Carte de 70 u.** Portrait de 52 u (`MousePortrait` : tuile sombre et souris vectorielle dans la couleur du roster, transmise par `CompanionPanel.set_colors`). Nom en gras 16 u et « Niv. N » en bleu ; ils sont dans un `HFlowContainer`, donc « Niv. 1000 » passe sous un nom long au lieu de le couper. « 339,9 M DPS · 2 % » en gris 14 u (part du DPS de toutes les souris, arrondie). Ligne de progression en 14 u : barre et texte court (« Palier 200 », « Éveil 1000 », comme la fiche « barre + Éveil N ») ; la phrase complète (« Palier niv. 200 : ×3 ») reste dans la bulle d'aide du libellé. Sans objectif devant (dernier palier, tous les éveils), la barre disparaît et le texte prend la place.
  - **Bouton 112×56 u** à deux libellés : le coût (gras 16 u) puis « +X DPS » (14 u). Niveau 0 : « Acheter » puis le coût. Éveil : bouton violet « Éveil II » puis le coût, carte bordée de violet, ligne « Niveau bloqué : éveil requis » en violet clair ; le badge du rang actuel s'efface, puisque le bouton dit le rang visé. « Max » seulement en mode Palier après le dernier palier : bouton foncé à bord, désactivé. Pas assez d'or : gris. « ×N · » précède le gain seulement si le nombre réel diffère du mode (Max, Palier, ×10 ou ×100 limités par un seuil) ; seul l'espace après « · » est sécable. Nom accessible : la phrase entière (« Améliorer Lancier ×50 : 17,7 B, +2,7 M DPS » ; pour l'éveil, le gain « Escouade ×2,10 » ou « Ce compagnon ×3,4 », qui ne tient plus sur le bouton).
  - **« +X DPS ».** Nouvelle lecture pure `FloorManager.companion_dps_at(id, niveau)`, exposée par `CompanionManager.damage_per_second_at`, avec les éveils, les talents de souris et Cadence. Le gain vaut `dps_at(niveau visé) − dps actuel` : c'est la formule de la fiche, mais elle vaut aussi au niveau 0. Ne sont pas anticipés : « Champion » (la souris la plus forte peut changer) et le seuil de « Synergie ».
  - **Coût.** Les textes du bouton ne sont recalculés que si le niveau, le nombre, le rang, la puissance des souris ou le mode changent. L'or seul ne change que l'état payable. Styles et couleurs ne sont reposés qu'au changement d'état.
  - **Défaut trouvé et corrigé.** En réécrivant `companion_panel.gd`, `NO_BREAK_SPACE` est devenu un espace ordinaire, ce qui désactivait `keep_together` en silence : les tests comparaient avec la même fonction. `test_keep_together_leaves_no_plain_space` vérifie maintenant le code U+00A0.
  - **Tests.** Nouveaux `companion_gain_test.gd` (12) : gain affiché égal au gain réel après `buy_levels` en ×1, ×10 à travers un palier, ×100, Max, Palier, niveau 0, ×10 limité par un seuil, après un éveil, avec talents et Cadence, talent acheté après un rafraîchissement, autre souris présente ; vu en échec contre deux sabotages (gain d'un seul niveau ; clé de cache sans la puissance des souris). `companion_rows_test.gd` (13) : textes, parts qui font 100 %, « Acheter », règles du « ×N · », couleurs, tailles, passage du glissé, l'or seul. Adaptés sans affaiblissement : `companion_panel_press_test`, `_tier_test`, `_awakening_test`, `companion_cost_text_test`. Contraste : textes de la carte et du bouton dans chaque état, bord violet. Suite 955/955.
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`7a880aa`, lot 5), occupation médiane (`lot6-fluidite-*.txt`) :

    | Mesure | Portrait (réf. / lot 6) | Paysage (réf. / lot 6) |
    |---|---|---|
    | Sans fenêtre | 6,7 / 7,4 % | 6,9 / 7,9 % |
    | Fenêtre visible | 6,7 / 7,4 % | 6,7 / 7,7 % |

    De +0,7 à +1,0 point, sous le critère de 1,5 ; aucune image de plus de 33 ms. Le surcoût suit le nombre de cartes visibles (environ 3 en portrait, 8 en paysage) et n'a pas bougé après le cache des textes : c'est probablement le dessin des cartes et des portraits (11 cercles par souris) à chaque image. Ce n'est pas prouvé. Piste pour le lot 9 : un atlas des portraits, comme pour les souris du lot 3.
  - **Preuves.** Captures `lot6-*` aux 5 tailles (partie préparée `?seed=d` : Éclaireur 300 avec un éveil, Lancier 150, Archer 200 bloqué, Gardien 25, Mage 10, Chevalier 1, Alchimiste et Dragon à 0) : état initial (×1), `-x10`, `-x100`, `-max`, `-palier`. Aucune erreur console, aucun défilement horizontal.
- Lot 7 (2026-11-04) :
  - **En-tête de 56 u.** 5 emplacements, un par type des données (Épée, Casque, Plastron, Aura, Entaille ; la fiche disait 4, les données en ont 5). Chacun est dessiné à 48 u dans une zone de 50 u, avec l'icône du type (`UiIcon` : épée, casque, plastron, aura, entaille) et un bord de la couleur de rareté. **Marque de forme** (demande d'Amaury) : 1, 2 ou 3 points dans le coin pour Commun, Rare, Légendaire (`ItemIcon`, rang de la rareté + 1, 3 au plus). Un emplacement vide est gris, sans point, désactivé. À droite : « Sac » (« Sac plein ») en 14 u, puis « N / M » en jaune gras 20 u (26 u ne tient pas à 320). Le titre « Équipement » disparaît.
  - **Carte du sac** (70 u, davantage si un long bonus passe à la ligne). Bande de 4 u de la couleur de rareté ; tuile de 52 u avec l'icône teintée ; type en gras et rareté en toutes lettres et en couleur (`HFlowContainer`) ; bonus principal en gras ; ligne grise de 14 u. **Ligne grise** (demande d'Amaury) : « Équipé : +5 % » si l'objet porté a le même bonus principal, « Équipé : +5 % Dégâts globaux » s'il en a un autre, « Emplacement vide » sinon (`InventoryScreen.worn_line`).
  - **Deux zones par carte.** « Équiper » (vert, 112×56) émet `equip_requested` tout de suite. Le reste de la carte (`_bag_buttons`, un bouton plat à bascule) ouvre la comparaison et n'équipe jamais : `test_a_touch_never_equips_by_itself` est conservé, inchangé. Les deux laissent passer le glissé. Ordre du clavier : emplacements, puis chaque carte et son « Équiper », puis la barre du détail. Après « Équiper », le focus reste sur la même carte, où l'ancien objet revient.
  - **Détail.** Inchangé, sauf « Équipé » grisé avec une coche dessinée (`UiIcon.CHECK` : la police par défaut n'est pas sûre d'avoir ✓).
  - **Couleurs de rareté** : celles de la palette (`COMMON`, `BLUE`, `YELLOW`). Les variantes `ItemRow*` du thème ne servent plus ; elles restent jusqu'au nettoyage du lot 9.
  - **Tests.** Nouveau `inventory_rows_test.gd` (18) : carte, bande et tuile, les trois formes de la ligne grise, « Équiper » qui équipe sans détail, le corps qui n'équipe pas, « Équiper » désactivé pour un type inconnu, passage du glissé, ordre du clavier, focus après « Équiper », points et bord des emplacements, emplacement vide, coche centrée, « Sac plein », tailles, sac plein de longs bonus à 320. `inventory_pane_test.gd` : 35 tests, dont `test_a_touch_never_equips_by_itself` inchangé ; le test du titre « Équipement » devient « les emplacements restent dans l'en-tête dans les deux largeurs » ; le test de l'emplacement vérifie aussi l'icône sans texte et le nom accessible exact. Vus en échec contre un sabotage, puis code remis : la ligne grise qui compare toujours par un nombre seul ; le corps de carte qui équipe. Contraste : mots de rareté sur la carte, bande, bord et points sur le panneau et la tuile, ligne grise, « Sac », « Équiper ». Suite 974/974.
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`abd2330`, lot 6), occupation médiane (`lot7-fluidite-*.txt`) :

    | Mesure | Portrait (réf. / lot 7) | Paysage (réf. / lot 7) |
    |---|---|---|
    | Sans fenêtre | 7,5 / 7,5 % | 7,8 / 7,9 % |
    | Onglet Objets ouvert, parties neuves (`PERF_FRESH=1`) | 6,6 / 6,7 % | 6,4 / 6,6 % |
    | Fenêtre visible | 7,4 / 7,5 % | 7,9 / 7,9 % |

    Écart maximal +0,2 point ; aucune image de plus de 33 ms. Limite : une partie neuve a un sac vide, donc la série « Objets » mesure l'en-tête, pas des cartes pleines. Elle appuie la piste du lot 6 : sans les cartes Souris à l'écran, l'occupation baisse d'environ 1 point.
  - **Preuves.** Captures aux 5 tailles (partie préparée `?seed=d` : Épée Rare, Casque Commun et Aura Légendaire portés ; 8 objets dans le sac) : `lot7-*-objets` et `-detail` (corps de carte touché : comparaison), `lot7e-*-equipe` (« Équiper » sur le Plastron : il passe en haut avec 3 points, sac 7/12, DPS 462,8 M → 546,1 M), `lot7s-*-emplacement` (Épée portée : « Équipé » grisé avec la coche). Aucune erreur console, aucun défilement horizontal.

- Lot 8 (2026-11-04) :
  - **En-tête de 46 u.** « 23 points à dépenser » : le nombre en jaune 32 u, les mots en 16 u (« point » pour 0 ou 1). Les mots passent sur deux lignes (« points / à dépenser ») quand la largeur qu'ils reçoivent ne suffit pas pour une : à 320 de large, pas à 360 ni au-delà. Le libellé ne demande que la largeur de ses deux lignes et coupe le reste, si bien que la version sur une ligne n'élargit jamais le panneau. Les points et la partie libre se partagent la place selon un rapport de 4 à 1 ; la partie libre fait au moins 43 u (audit). « Réinitialiser » est un `HeaderButton` (dessiné sur 44 u, touchable sur 50 u, fond sombre à bord gris), et garde ses deux lignes pendant l'attente (« Réinitialiser / dans 59:05 »). « Meilleur étage… Prochain point… » reste dans la liste. Le texte « Points disponibles : N » de la bande disparaît : l'en-tête dit la même chose dans toutes les mises en page.
  - **Paliers.** « Palier 2 » à gauche (16 u). À droite, « Ouvert » en jaune, ou un cadenas et « 0 / 2 points » en gris 14 u (« point » si le seuil est 1). `TalentCardText.tier_header` devient « Palier 4 : 4 / 8 points » (au lieu de « 4 points sur 8 »).
  - **Tuiles** (`TalentTile`, un bouton à bascule) : 64 u minimum au lieu de 76, plus hautes si le texte le demande, alignées à gauche. Une tuile achetée a une coche jaune devant son nom (`UiIcon.CHECK`, dans une marge de 22 u ajoutée à ses styles) **et** garde le mot « Acheté ». **Coût réel** (`TalentCardText.tile_state_text`) : « Palier fermé · 2 pts », « Requiert : Frénésie · 2 pts » ; « Exclu » sans coût, puisqu'on ne peut pas l'acheter.
  - **Conservé de la 019.** Sous-onglets, fiche (Retour, Acheter, garde de 250 ms), confirmation et refus de la réinitialisation, décompte, les trois mises en page, focus, glissé, noms des fonctions publiques. La fiche remplace toujours l'arbre et son en-tête sur un téléphone.
  - **Pas fait** : le nom en gras de la maquette (la spec ne le demande pas ; un bouton n'a qu'une police).
  - **Tests.** Nouveau `talent_shell_test.gd` (13) : en-tête de 46 u qui tient à 320 avec un Réinitialiser sur deux lignes, nombre jaune de 32 u, une ou deux lignes selon la largeur, singulier, Réinitialiser touchable sur 50 u, partie libre d'au moins 30 u qui ne recouvre ni les points ni Réinitialiser, cadenas et « Ouvert », cadenas qui part à l'ouverture du palier, tuiles de 64 u alignées à gauche, coche et marge seulement sur une tuile achetée, marge retirée après une réinitialisation, marge gardée sur une tuile achetée sélectionnée, coûts. Adaptés sans les affaiblir : dans `talent_screen_v2_test`, les en-têtes de palier (nom et progression lus séparément, plus la forme jointe), les mots d'état (avec le coût), le texte des points. Contraste : nombre jaune, progression, Réinitialiser et son bord, cadenas, coche sur la tuile achetée normale, survolée et sélectionnée. Deux sabotages vus en échec, puis code remis : les mots toujours sur une ligne ; la coche jamais retirée. Suite 988/988.
  - **Défaut trouvé pendant l'écriture** : avec la phrase sur une ligne, la largeur minimale du panneau montait à 326 u. À 320, le panneau ne pouvait donc jamais devenir assez étroit pour passer sur deux lignes : le test a échoué. D'où le libellé qui demande seulement la largeur de ses deux lignes.
  - **Audit des 18 tailles** (`lot8-audit-18-tailles.txt`, sonde jetable sur la vraie scène, sans affichage) : onglets Souris et Objets, puis Talents (arbre, fiche, confirmation, attente, refus, troisième branche). Contrôles : rien ne sort du panneau ; boutons touchables sur 50 u au moins (zone d'un `HeaderButton` comprise) ; 16 u pour les boutons, 14 u pour les textes ; aucun texte plus grand que sa place, même coupé ; aucun bouton sur un autre. **0 problème aux 18 tailles.** Exclue : la bande de 22 u de la poignée, prolongée par les en-têtes depuis le lot 5. La sonde a d'abord signalé cette bande : c'est la preuve qu'elle détecte une cible trop petite.
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`87c77e6`, lot 7), occupation médiane :

    | Mesure | Portrait (réf. / lot 8) | Paysage (réf. / lot 8) |
    |---|---|---|
    | Sans fenêtre, onglet Souris (`lot8-fluidite-headless.txt`) | 8,1 / 8,0 % | 8,4 / 8,4 % |
    | Sans fenêtre, onglet Talents, parties neuves (`lot8-fluidite-talents.txt`) | 7,4 / 7,4 % | 7,4 / 7,6 % |

    Écart maximal +0,2 point ; aucune image de plus de 33 ms. Pas de série en fenêtre visible pour ce lot.
  - **Preuves.** Captures `lot8-*` aux 5 tailles. Partie préparée `?seed=d`, un lancement par taille : la première série, faite dans un seul navigateur, avait repris la sauvegarde de la taille précédente. Étapes : état initial, `-talents`, `-compagnons` (Frénésie achetée : coche et « Acheté » ; paliers fermés avec cadenas et coûts), `-fiche` et `-retour`, `-confirmer`, `-reinit`, `-fiche-achat` puis `-attente` (Frénésie rachetée : « Réinitialiser / dans 59:5x »), `-replie` (partie libre de l'en-tête touchée ; pas en paysage). Aucune erreur console, aucun défilement horizontal.

- Lot 9 (2026-11-12) :
  - **Paysage.** La colonne de gauche reprend la scène du portrait : monstre au centre, deux grilles de 2 × 2 souris de chaque côté, coin « Boss » en haut à droite, chrono en bande puis PV en bas, et sous la scène la rangée de compétences de 68 u (les ronds ne sont plus empilés). La scène prend toute la hauteur de la colonne moins cette rangée (`GameZone.scene_height`). Scène et panneau se partagent la largeur au rapport 3 : 4, soit 548 et 732 u à 1280 de large (la spec disait environ 540 et 720). En-tête sur une ligne, pas de poignée, onglets en bas du panneau. Mise en page validée par Amaury sur captures le 2026-11-12, avant le commit : elle n'était pas dessinée dans la maquette.
  - **Souris et billes.** Les emplacements et la taille des souris du paysage sont ceux de la règle du portrait (`portrait_mouse_centers`, 38 u à 1280x720). Les billes partent de ces mêmes points : dessin et tirs sont alignés par construction. Les anciennes règles du paysage (`orb_radius`, `orb_pitch`, blocs de colonne) sont retirées.
  - **Talents.** À 1280x720, le panneau de 732 u montre l'arbre complet sur 3 colonnes (il en faut 594). Sur un téléphone en paysage (844x390 : panneau de 548 u), les sous-onglets restent.
  - **Défaut trouvé par un nouveau test, corrigé.** À 844x390, la scène est basse et large (411 × 323 u) et le monstre passait sous le coin « Boss ». `portrait_box` limite maintenant le monstre pour qu'il reste à gauche du coin ou en dessous, selon ce qui le laisse le plus grand. Test vu en échec avant la correction ; rien ne change en portrait.
  - **Thème.** Les 4 types `ItemRow`, `ItemRowCommon`, `ItemRowRare`, `ItemRowLegendary` et leurs 13 styles sont supprimés. Nouveau `theme_unused_styles_test.gd` (2) : le thème n'a plus ces types, et aucun fichier `.gd`, `.tscn` ou `.tres` de `src/` ne contient « ItemRow ». Les deux ont été vus en échec contre `f391648`.
  - **Tests.** Nouveau `landscape_layout_test.gd` (5, vraie scène à 1280x720) : partage 3/7 et 4/7, compétences en rangée sous les PV, billes aux points des souris dessinées, souris qui ne touchent rien, arbre complet des talents. `game_zone_layout_test.gd` : scène du paysage, coin à côté du monstre et hors des PV et du chrono, souris qui ne touchent rien, à 548 × 668 et 411 × 391 u. `adaptive_layout_test.gd` : messages de butin du paysage. Retirés avec le code qu'ils testaient : 2 tests des anciennes orbes du paysage, 2 tests de contraste des `ItemRow*`. Suite 994/994.
  - **Non fait, noté pour plus tard.** Amaury a demandé de centrer verticalement le groupe monstre, souris et sol à 1280x720, seulement si la retouche était petite. Elle ne l'est pas : le groupe est déjà centré dans la place que la scène lui réserve (111 u au-dessus, 106 u en dessous). Le vide visible sous le sol vient de la bande du chrono et de l'indice de boss, réservés pour que rien ne bouge pendant un combat. Centrer par rapport aux PV déplacerait le tout de 12 u seulement, et demande de toucher à la règle commune au portrait. Le vrai levier serait un monstre plus grand en paysage (il est limité à 55 % de la largeur de la colonne, 301 u).
  - **Audit des 18 tailles** (`lot9-audit-18-tailles.txt`, sonde jetable refaite, vraie scène sans affichage, partie préparée) : onglets Souris, Objets et Talents à chaque taille, soit 54 contrôles. Rien ne sort de l'écran ; boutons touchables sur 50 u au moins ; 16 u pour les boutons, 14 u pour les textes ; aucun texte plus large que sa place ; aucun bouton sur un autre. **0 problème.** Exclues, comme au lot 8 : la bande de la poignée et les parties libres des en-têtes qui la prolongent (comptées à part dans le fichier). La sonde signale bien une cible trop petite quand on monte son seuil à 60 u. Limite : les états internes des talents (fiche, confirmation, attente) n'ont pas été reparcourus ; le lot 9 ne les change pas.
  - **Débordement.** Export avec `?seed=max` (« Étage 999 », « 999,9 Qa ») à 320, 360, 390, 412, 768, 1024, 1280, 1920 et 2560 de large, plus 844x390 et 915x412 : largeur de page égale à la largeur de fenêtre partout, aucune erreur console.
  - **Fluidité**, processeur ×4, 5 passages alternés avec la référence (`f391648`, lot 8), partie préparée `?seed=d` rechargée à chaque passage, occupation médiane du fil principal :

    | Mesure | Portrait (réf. / lot 9) | Paysage (réf. / lot 9) |
    |---|---|---|
    | Sans fenêtre, onglet Souris (`lot9-fluidite-headless.txt`) | 20,6 / 20,7 % | 21,7 / 21,7 % |
    | Sans fenêtre, onglet Objets, sac de 8 objets (`lot9-fluidite-objets.txt`) | 20,7 / 20,7 % | 21,5 / 21,3 % |
    | Sans fenêtre, onglet Talents (`lot9-fluidite-talents.txt`) | 19,3 / 19,6 % | 19,8 / 20,6 % |
    | Fenêtre visible, onglet Souris (`lot9-fluidite-fenetre.txt`) | 11,5 / 11,5 % | 17,3 / 17,9 % |
    | Fenêtre visible, onglet Objets (`lot9-fluidite-fenetre-objets.txt`) | 19,7 / 19,6 % | 21,2 / 20,6 % |
    | Fenêtre visible, onglet Talents (`lot9-fluidite-fenetre-talents.txt`) | 18,8 / 19,4 % | 19,5 / 20,0 % |

    Écart maximal +0,8 point (Talents en paysage, sans fenêtre : l'arbre complet montre plus de tuiles que les sous-onglets de la référence), sous le seuil de 1,5 point. **L'atlas des portraits n'est donc pas fait.** Lecture prudente : le niveau absolu (environ 20 %) est plus haut qu'au lot 8 (environ 8 %) parce que la partie préparée a 6 souris qui tirent, et parce que la machine a changé de régime pendant la première série en fenêtre (de 11 à 18 % pour les deux versions en même temps). Les deux versions ont de 0 à 9 images de plus de 33 ms par passage, sans différence nette ; un seul passage du lot 9 en a 14 (Talents en portrait, fenêtre visible), les quatre autres de 0 à 2. En paysage, les touchers visent le monstre de chaque version (384, 380 pour la référence ; 274, 322 pour le lot 9).
  - **Preuves.** Captures `lot9-*` dans l'export, partie préparée `?seed=d`, un lancement par taille : état initial (onglet Souris), `-objets`, `-talents`, à 390x742, 360x640, 412x915, 320x568, 1280x720, 844x390 (×3), 915x412 (×2,6) et 853x480 à 1,5 (zoom 150 % d'une fenêtre de 1280x720). Aucune erreur console, aucun défilement horizontal.

## Vérifications sur téléphone (à la charge d'Amaury)

- Essai prévu après le lot 5 (2026-11-04). Cette liste sera complétée à chaque lot.
- **Plein écran, à vérifier à la main** : Réglages → « Plein écran : NON » → toucher : la barre du navigateur disparaît et le libellé passe à OUI ; quitter par le geste retour : le libellé revient à NON sans toucher le bouton ; aucun décalage de la mise en page après la sortie.
- « Abandonner » pendant un boss : un toucher affiche « Confirmer ? », un second dans les 3 s abandonne, sans second toucher il revient à « Abandonner ».
- En-tête : toucher l'or ouvre le détail du DPS, un second toucher le ferme ; la roue ouvre Réglages ; les deux se touchent au pouce sans viser.
- « Défi auto » dans Réglages garde son état après rechargement de la page.
- Souris à côté du monstre :
  - nettes, sans flou, en portrait et après rotation ;
  - aucune ne disparaît ni ne clignote quand on tourne le téléphone ;
  - aucune ne touche le monstre, le coin Boss, les PV ou le chrono.
- Boss :
  - le coin « Boss » se touche au pouce, sans viser ;
  - pendant le combat, le chrono reste lisible, avec les secondes en chiffres ;
  - « Confirmer ? » se distingue bien d'« Abandonner ».
- Tapoter vite le monstre pendant une dizaine de secondes : pas d'à-coup visible ; les chiffres et les billes restent fluides.
- Compétences en ronds (lot 4) :
  - un toucher bref sur un rond prêt l'active au relâchement ;
  - poser le doigt sur un rond, le glisser hors du rond puis lever : rien ne s'active ;
  - appui long (une demi-seconde) : la bulle montre le nom puis l'effet, et lever le doigt n'active rien ; le toucher suivant ferme la bulle sans rien activer ;
  - les secondes de la pastille se lisent ; on distingue « en cours » (jaune) de « en recharge » (sombre) ;
  - un rond à cadenas ouvre l'onglet Talents sur le talent qui le débloque.
- Coquille du panneau (lot 5) :
  - toucher la poignée (le trait sous les compétences) replie le panneau : la scène grandit, le monstre aussi, les souris restent à côté sans le toucher ; un second toucher le déploie ;
  - toucher l'espace vide de l'en-tête, entre « DPS des souris » et « Achat ×N », fait la même chose ; toucher « DPS des souris » ouvre le détail du DPS (comme le centre de l'en-tête du haut) et ne replie jamais le panneau ; un second toucher ferme le détail ;
  - panneau replié, la poignée seule se touche au pouce sans viser ; toucher un onglet le déploie sur cet onglet ;
  - recharger la page : le panneau revient replié ou déployé comme on l'a laissé ;
  - tourner le téléphone en paysage : pas de poignée, panneau ouvert ; revenir en portrait : l'état d'avant revient ;
  - « Achat ×1 » : chaque toucher passe à ×10, ×100, Max, Palier, puis ×1 ; les boutons des lignes suivent ; après rechargement, le mode reste ;
  - faire défiler la liste Souris, replier puis déployer : la liste est au même endroit ; même chose quand la barre d'adresse du navigateur apparaît ou disparaît en faisant défiler ;
  - glisser dans la liste en partant d'un bouton d'achat : la liste défile, rien ne s'achète ;
  - onglets du bas : icône et nom (Souris, Objets, Talents), liseré de couleur sur l'onglet ouvert, pastille rouge avec le nombre de points sur Talents, lisible.
- Lignes Souris (lot 6) :
  - chaque souris a son portrait de couleur ; nom et « Niv. N » lisibles d'un coup d'œil ; « DPS · % » se lit ;
  - le bouton dit le coût puis « +X DPS » ; après un achat, le DPS de la souris a bien augmenté d'environ ce montant (comparer « DPS des souris » avant et après) ;
  - niveau 0 : « Acheter » ; seuil d'éveil : bouton violet « Éveil N » et la ligne « Niveau bloqué : éveil requis », la carte bordée de violet ;
  - en Max ou Palier, « ×N · » devant le gain ; « Max » seulement en Palier après le dernier palier ;
  - glisser dans la liste en partant d'un bouton : rien ne s'achète ;
  - rien ne déborde à droite sur le téléphone, même avec un nom long.
- Objets (lot 7) :
  - en haut, les 5 emplacements : icône du type, bord et 1, 2 ou 3 points de la rareté ; un emplacement vide est gris et ne réagit pas ; à droite « Sac N / 12 » (« Sac plein » quand il l'est) ;
  - toucher un emplacement porté ouvre son détail ; le bouton dit « Équipé », grisé, avec une coche ;
  - chaque carte du sac : type et rareté en toutes lettres et en couleur, le bonus en gras, la ligne grise « Équipé : +X % » (même bonus) ou « Équipé : +X % <bonus> » (bonus différent) ou « Emplacement vide » ;
  - « Équiper » sur une carte équipe tout de suite : l'objet passe en haut, l'ancien revient à sa place dans le sac ;
  - toucher le reste de la carte ouvre la comparaison et n'équipe jamais ; « Retour » revient à la liste au même endroit ;
  - glisser dans la liste en partant d'une carte ou de son « Équiper » : la liste défile, rien ne s'équipe ;
  - lisibilité générale de l'onglet, le point que tu trouvais le moins lisible.
- Talents (lot 8) :
  - en haut, « N points à dépenser », le nombre en gros et en jaune ; sur ton téléphone, sur une ligne ou deux, sans rien de coupé ;
  - « Réinitialiser » se touche au pouce ; après une réinitialisation puis un achat, il dit « Réinitialiser / dans mm:ss » sur deux lignes, et le décompte avance ;
  - toucher l'espace vide entre les points et « Réinitialiser » replie le panneau ; toucher les points ne fait rien ;
  - chaque palier : « Palier N » à gauche ; à droite « Ouvert » en jaune, ou un cadenas et « x / y points » ;
  - une tuile achetée : coche jaune devant le nom, et « Acheté » ; une tuile d'un palier fermé ou qui requiert un autre talent montre son coût (« · 2 pts ») ;
  - toucher une tuile ouvre sa fiche ; « Acheter » juste après l'ouverture (double toucher) n'achète pas ; « Retour » revient à la même tuile ;
  - réinitialiser : la question, puis « Oui, réinitialiser » ; pendant un boss ou l'attente, la fiche dit pourquoi c'est impossible ;
  - les trois sous-onglets (Clic, Compagnons, Économie) et le glissé dans la liste : rien ne s'achète en glissant ;
  - lisibilité des tuiles : rien ne déborde à droite.
- Paysage (lot 9), téléphone tourné sur le côté :
  - l'en-tête tient sur une ligne : étage et record à gauche, or et DPS au centre, roue à droite ;
  - à gauche la scène : le monstre au centre, les souris des deux côtés, le coin « Boss » en haut à droite, les PV puis les 3 compétences en rangée tout en bas ;
  - à droite le panneau, avec les 3 onglets en bas ; pas de poignée, et le panneau ne se replie pas ;
  - le coin « Boss » ne touche pas le monstre, et se touche au pouce ; aucune souris ne touche le monstre, le coin, les PV ou le chrono pendant un boss ;
  - les billes partent bien des souris dessinées ;
  - les compétences se touchent au pouce de la main gauche ; tapoter le monstre reste fluide ;
  - onglet Objets : la liste défile, « Équiper » se touche ; onglet Talents : les sous-onglets Clic, Compagnons, Économie (l'arbre complet sur 3 colonnes n'apparaît que sur un écran large, tablette ou ordinateur) ;
  - tourner le téléphone dans les deux sens plusieurs fois : rien ne clignote, rien ne reste décalé, et en revenant en portrait le panneau est replié ou déployé comme avant ;
  - si la barre d'adresse du navigateur mange la hauteur : dire ce qui devient trop serré.

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-019-talent-tree-content.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-11-12
**Criteria**: 15/15 passing (none deferred)
**Deviations**: advisory only: la sonde des cibles et des tailles tourne sur la vraie scène sans affichage, pas dans l'export web ; 5 emplacements d'objets au lieu de 4 (un par type des données). `stamp.txt` des preuves date du lot 3 (information).
**Test Evidence**: `production/qa/evidence/story-019b-mobile-ui-refonte/` (captures `lot1-*` à `lot9-*`, audit `lot9-audit-18-tailles.txt`, fluidité `lot*-fluidite-*.txt`) ; tests dans `tests/unit/ui/`, suite 994/994, CI verte sur `a3eb6a1`
**Reviewed by**: self, no independent review
