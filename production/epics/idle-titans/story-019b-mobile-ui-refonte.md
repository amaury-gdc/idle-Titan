# Story 019b: Refonte UI/UX mobile

> **Epic**: Idle Titans (MVP)
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: XL
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-03

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

- [ ] Portrait : en-tête, scène, compétences, panneau et onglets aux hauteurs de la spec à 390x742 ; règle de repli testée à 360x640 et 320x568.
- [ ] Aucun débordement horizontal de 320 à 2560 de large, avec « Étage 999 » et « 999,9 Qa ».
- [ ] Le DPS total est visible dans l'en-tête sur les 3 onglets.
- [ ] Boss visible seulement si `farming` ; pendant le combat, « Abandonner » et un chrono en bande fine avec les secondes ; rien ne se décale quand il apparaît.
- [ ] Compétences en ronds aux états prêt, recharge, cadenas et passif, nom dans la bulle ; touches 1/2/3 inchangées.
- [ ] Poignée qui replie et déploie au toucher et au clavier, état mémorisé ; panneau replié sans contrôle focalisable caché.
- [ ] Un seul bouton d'achat qui cycle ×1, ×10, ×100, Max, Palier ; ancien mode enregistré relu sans décalage.
- [ ] « +X DPS » égal au gain réel après achat (test, Champion excepté).
- [ ] Lignes Souris, Objets et Talents conformes à la spec ; « Équiper » sur la ligne, comparaison toujours accessible.
- [ ] Talents : fonctions, noms uniques et tests de la story 019 conservés (adaptés, jamais désactivés).
- [ ] « Défi auto », version et « Plein écran » dans Réglages, plus sur l'écran principal.
- [ ] Contraste ≥ 4,5:1 pour tout texte et ≥ 3:1 pour les signaux non textuels, couverts par `main_theme_contrast_test.gd`.
- [ ] Cibles ≥ 44 px CSS, textes ≥ 14 u, contrôlés par la sonde dans l'export.
- [ ] Captures dans l'export à 390x742, 360x640, 412x915, 1280x720, plus 320x568, et audit des 18 tailles de la story 019.
- [ ] Essai sur le téléphone d'Amaury après le lot 5, avant les lots 6 à 9.

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
- Nouveaux : `src/ui/skill_orb.gd` (lot 4), `panel_handle.gd`, `pane_header.gd`, `header_button.gd` (lot 5)
- `src/core/display_settings.gd` (repli du panneau, mode ×100)
- Tests à adapter : `tests/unit/ui/main_theme_contrast_test.gd`, `adaptive_layout_test.gd`, `companion_panel_*_test.gd`, `buy_quote*_test.gd`, `inventory_pane_test.gd`, `management_tabs_test.gd`, `talent_screen_v2_test.gd`, `talent_pane_test.gd`

## QA Test Cases

*Panneau replié puis rotation ; boss qui apparaît pendant un tapotage ; glissé dans la liste sans achat ; appui long sur une compétence ; ×100 avec moins de 100 niveaux possibles ; ancien mode d'achat enregistré ; sac plein ; noms les plus longs à 320 px ; zoom Chrome 150 %.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures dans `production/qa/evidence/story-019b-mobile-ui-refonte/`, tests dans `tests/unit/ui/`.

**Status**: [ ] En cours. Lot 1 fait : captures `lot1-*` à 390x742, 360x640, 412x915, 1280x720 et 320x568 (export web, Edge headless, aucune erreur console, scrollWidth = innerWidth), `stamp.txt` ; suite 832/832.

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

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-019-talent-tree-content.md`
- Unlocks: None
