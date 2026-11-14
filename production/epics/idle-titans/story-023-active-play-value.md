# Story 023: Valeur du jeu actif

> **Epic**: Idle Titans (MVP)
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-14

## Context

**GDD**: `design/economy-rework.md`
**Requirement**: hors brief MVP, demandé par Amaury à la clôture des mesures de la story 020

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Problème mesuré (story 020, `assets/data/balance_notes.md`, section « Economy calibration »)

Jouer activement pèse peu sur la progression, de deux façons.

**1. La part du clic est sous les cibles de `design/economy-rework.md`.**

| Mesure (profil de référence, graine 1) | Mesuré | Cible |
|---|---|---|
| Sans talents, 3 clics/s, au milieu (étages 50 à 150) | 24 % | environ 40 % |
| Sans talents, 3 clics/s, à l'étage 200 | 22 % | 10 à 20 % |
| Build Clic, 3 clics/s, à l'étage 200 | 32 % | 40 à 60 % |
| Build Compagnons (référence), à l'étage 200, 3 clics/s | 17 % | — |
| Build Compagnons (référence), à l'étage 200, 1 clic/s | 7 % | — |

Les courbes de PV ne changent pas la part du clic. Les leviers sont les talents de la branche Clic et `click_companion_power_factor` ; la story 020 n'y a pas touché.

**2. L'étage 200 est toujours payé par l'or du retour.**

Les temps d'arrivée aux étages hauts se calent sur les retours d'absence : étage 200 à 8,0 h actives pile dans cinq mesures sur six, étage 210 à 12,0 h, étage 220 juste après un retour. Entre deux retours, la session active n'avance presque plus : le joueur attend 8 à 12 jours devant le boss de l'étage 210, puis passe les étages 211 à 220 en une minute. Passer de 1 à 3 clics/s ne fait gagner qu'un jour sur l'étage 200 (jour 6 contre jour 5).

---

## Acceptance Criteria

*À préciser avec Amaury au démarrage : les cibles ci-dessous reprennent celles de `design/economy-rework.md`.*

- [ ] Part du clic sans talents à 3 clics/s : environ 40 % au milieu, 10 à 20 % à l'étage 200.
- [ ] Un build Clic atteint 40 à 60 % à l'étage 200.
- [ ] Poids de l'or d'absence mesuré et noté : part de l'or du retour dans l'or total dépensé entre les étages 150 et 210, avant et après.
- [ ] Une session active de 2 h fait avancer le joueur de façon visible après l'étage 190, sans attendre le retour suivant (seuil à fixer avec Amaury).
- [ ] La mesure de référence est relancée après chaque famille de valeurs changée (règle ci-dessous) : étage 200 aux jours 4 à 6, étage 230 non atteint à 40 h actives, pour les deux acheteurs.
- [ ] Sensibilité et builds de sommet remesurés ; `balance_notes.md` et `real_data_test.gd` à jour ; tous les tests verts.

---

## Règle des notes d'équilibrage (rappel)

Toute story qui ajoute de la puissance au joueur (objets, compétences, talents, éveil) relance la mesure de référence : profil 2 h par jour, 2 acheteurs, 40 h actives. Elle vérifie : étage 200 aux jours 4 à 6, étage 230 non atteint. La commande exacte et le tableau de sensibilité de la story 020 sont dans `assets/data/balance_notes.md`, section « Economy calibration (story 020) ».

Cette story change la puissance du clic et le poids de l'or : la règle s'applique à chaque famille de valeurs changée.

---

## Out of Scope

- Toute nouvelle mécanique, sauf décision d'Amaury au démarrage.
- Les courbes de PV de la story 020, sauf si la mesure de référence sort de sa cible.

---

## Files

- À remplir à la fin.

## QA Test Cases

*Sans talents à 1 et 3 clics/s ; build tout Clic avec chaque sommet ; build Économie (Rentes, Rentier, Longue veille) ; 1 h et 4 h par jour ; joueur qui ne revient qu'un jour sur deux.*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`, `assets/data/balance_notes.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/idle-titans/story-020-economy-calibration.md`
- Unlocks: None

---
