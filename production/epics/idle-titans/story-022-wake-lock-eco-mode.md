# Story 022: Écran allumé et mode économie

> **Epic**: Idle Titans (MVP)
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-02

## Context

**GDD**: N/A — analyse UX validée par Amaury le 2026-11-02, décisions reprises ci-dessous
**Requirement**: hors brief MVP, demandé par Amaury

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Consulter `docs/engine-reference/godot/` avant tout appel d'API. Verrou d'écran par `JavaScriptBridge` (`navigator.wakeLock`), uniquement sur l'export web ; ailleurs, « indisponible ». Le calcul du jeu avance déjà sur le temps écoulé (pas de 5 s au plus), la cadence réduite n'y change rien.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Decisions

1. Le bouton s'appelle « Économie ».
2. Le mode économie demande lui-même le verrou d'écran pendant sa durée, sans changer le réglage enregistré, et le relâche en sortant si « Écran allumé » est sur NON.
3. L'or par seconde est la moyenne de l'or réellement gagné sur 30 s, mesure d'affichage seule ; « calcul… » pendant les 5 premières secondes.
4. Fond noir pur `#000000`.
5. Cacher l'onglet fait sortir du mode ; au retour, écran normal et message de retour habituel.
6. Pas de chrono de boss : un mot « Boss » discret sous l'étage pendant un combat de boss, absent sinon.
7. « v0.2.1 » quitte l'écran principal ; la version reste dans Réglages, et le bouton prend sa place.
8. Pas d'entrée automatique après inactivité.

## Textes

| Élément | Texte |
|---|---|
| Interrupteur | `Écran allumé : NON` / `Écran allumé : OUI` / `Écran allumé : indisponible` |
| Aide, NON | `L'écran du téléphone ne se met pas en veille pendant le jeu.` |
| Aide, OUI | `L'écran reste allumé tant que le jeu est affiché.` |
| Aide, refusé | `Le téléphone a refusé. Vérifie l'économiseur de batterie, puis réessaie.` |
| Aide, non pris en charge | `Ce navigateur ne permet pas de garder l'écran allumé.` |
| Bouton | `Économie` |
| Écran économie | `Étage`, valeur ; `Boss` pendant un combat de boss ; `Or par seconde`, `+1,2 M` ; `Touche l'écran pour revenir` |

Couleurs de l'écran économie : valeurs `#8C8C8C`, or `#A08A3C`, libellés, « Boss » et consigne `#808080` (au moins 5:1 sur noir). Tailles : valeurs 40 u, libellés 20 u, consigne 18 u, aide de Réglages 16 u.

---

## Acceptance Criteria

- [ ] Réglages : « Écran allumé » sous « Effets visuels », 50 u, aide selon l'état ; refus sur appui : retour à NON avec l'aide « refusé » ; `navigator.wakeLock` absent ou hors web : « indisponible », désactivé, sans erreur console. Pont JavaScript remplaçable par un faux dans les tests.
- [ ] Le choix est retenu dans `settings.cfg`, absent de « Copier ma sauvegarde », non effacé par la réinitialisation ; avec OUI, le verrou est redemandé au lancement (au premier appui si un geste est exigé) et au retour de l'onglet, en silence en cas d'échec.
- [ ] Le bouton « Économie » remplace « v0.2.1 » en portrait et en paysage, cible ≥ 50 u, sur les 18 tailles sans chevauchement.
- [ ] Un appui ouvre l'écran noir : « Étage », « Or par seconde », « Touche l'écran pour revenir » ; effets visuels coupés sans changer le réglage enregistré ; `Engine.max_fps` à 10, valeur d'avant restaurée en sortant ; le jeu ne s'arrête pas.
- [ ] « Boss » s'affiche sous l'étage pendant un combat de boss et disparaît ensuite ; perdre un boss en mode économie ramène simplement au farm, sans fenêtre, le mode restant actif (test).
- [ ] Même calcul : sur une même partie, or et étage en mode économie à 10 i/s égaux à ceux à 60 i/s, à 1 % près (test à pas fixe).
- [ ] Sortie par n'importe quel toucher, clic, touche ou bouton de manette ; le toucher de réveil ne frappe pas et n'achète rien ; 300 ms de garde après la sortie.
- [ ] Butin et points restent en pastilles ; la phrase du premier éveil attend la sortie et n'est marquée « vue » qu'une fois affichée.
- [ ] Valeurs rafraîchies une fois par seconde, sans animation ; le bloc saute toutes les 60 s vers une des 9 positions de ±24 u, jamais deux fois la même ; aucun clignotement.
- [ ] Onglet caché : sortie du mode ; mode jamais retenu entre deux sessions.
- [ ] Validé avec Amaury sur son téléphone : écran qui ne s'éteint pas (OUI et mode économie), retour d'application, refus par l'économiseur de batterie, réveil sans frappe, rotation, lisibilité.

---

## Out of Scope

- Entrée automatique après inactivité.
- Chrono de boss, barre de progression, statistiques de session dans le mode économie.
- Toute modification du calcul du jeu.

---

## Files

- À remplir à la fin.

## QA Test Cases

*Refus, non pris en charge, retour d'onglet avec OUI, boss gagné et perdu en mode économie, premier éveil pendant le mode, double appui rapide sur un bouton « Acheter » au réveil, rotation, rechargement de la page en mode économie, clavier seul.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: captures dans `production/qa/evidence/story-022-wake-lock-eco-mode/` (Réglages dans les 4 états, bouton en portrait et paysage, écran économie avec et sans « Boss ») ; tests unitaires dans `tests/unit/ui/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-017-awakening-ui.md`
- Unlocks: `production/epics/idle-titans/story-021-monster-variety.md`

---
