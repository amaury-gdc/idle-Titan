# tools/web

Captures et mesures de fluidité de l'export web, pilotées par le protocole DevTools (Node 22 ou plus, sans dépendance).

| Script | Rôle |
|---|---|
| `browser.mjs` | Lance le navigateur et le ferme toujours. Utilisé par les deux autres. |
| `capture.mjs` | Captures à plusieurs tailles, avec des touchers et des attentes. Rendu logiciel. |
| `perf.mjs` | Fluidité : médiane, 95e centile, pire image, images de plus de 33 ms, en processeur normal et ralenti. Rendu matériel. |

## Servir l'export

```
python -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

## Exemples

```
node tools/web/capture.mjs http://127.0.0.1:8765/index.html production/qa/evidence/<story> lot1 390x742@2m 1280x720@1
node tools/web/capture.mjs <url> <dossier> lot3 "390x742@2m+330,85:combat+330,85:confirmer+w3000:retour"
node tools/web/perf.mjs reference=http://127.0.0.1:8767/index.html apres=http://127.0.0.1:8766/index.html touch:reference:portrait=195,197
```

## Variables d'environnement

| Variable | Effet |
|---|---|
| `BROWSER_PATH` | Navigateur à utiliser, prioritaire. N'importe quel Chromium, par exemple Opéra : `%LOCALAPPDATA%\Programs\Opera\opera.exe`. Sans elle, Edge est cherché dans `Program Files`, puis dans `Program Files (x86)`. |
| `BROWSER_HEADLESS` | `0` ouvre une fenêtre visible. Par défaut, il n'y a aucune fenêtre. |
| `BROWSER_WINDOW_POSITION` | `x,y` en pixels d'écran : où s'ouvre la fenêtre visible, par exemple sur l'écran de VS Code. Coordonnées négatives acceptées (écran à gauche du principal). Par défaut, Windows choisit. |
| `BROWSER_TIMEOUT_MS` | Durée maximale d'un lancement : 600000 (10 min) par défaut. Au-delà, le navigateur est fermé et le script sort en erreur. |
| `PERF_PASSES`, `PERF_RATES`, `PERF_MEASURE_MS` | Pour `perf.mjs` : passages (5), ralentissements du processeur (`1,4`), durée d'un passage (10000 ms). |

## Lire une mesure de `perf.mjs`

- **Comparer sur l'occupation du fil principal** (colonne « busy % median »). Sans fenêtre, les temps d'image ne montrent pas un dessin plus coûteux.
- **Les touchers doivent tomber sur le monstre de chaque version.** Sinon, une version ne frappe pas et paraît moins coûteuse. Si la disposition déplace le monstre, donner son point avec `touch:<version>:<forme>=X,Y`. Par exemple, `touch:reference:portrait=195,197` pour la disposition d'avant la story 019b.
- **Comparer des versions d'une même série uniquement.** La machine dérive d'une série à l'autre. Les versions passent donc à tour de rôle, passage par passage, pour que la dérive les touche toutes pareil.

## Ce qui est garanti

- **Jamais le profil de l'utilisateur.** Chaque lancement crée un profil temporaire `%TEMP%\catitans-browser-*` et le supprime à la fin.
- **Le navigateur est toujours fermé** : en fin normale, en cas d'erreur, de dépassement de délai ou de Ctrl+C. Le script demande d'abord `Browser.close`, puis arrête l'arbre de processus (`taskkill /T /F`), puis tout processus dont la ligne de commande contient son propre profil.
  - Pourquoi cette dernière étape : Edge se relance lui-même sous un autre PID, et arrêter le seul processus lancé par Node laissait le navigateur ouvert.
- **Le port est choisi par le navigateur** (`--remote-debugging-port=0`) : deux lancements ne se gênent pas.

## Limites

- Opéra n'est pas garanti en mode headless. S'il refuse de démarrer sans fenêtre, utiliser `BROWSER_HEADLESS=0` : la fenêtre se ferme quand même à la fin.
- `perf.mjs` affiche le moteur de rendu utilisé. Avec un rendu logiciel (SwiftShader), il affiche aussi un avertissement : cette mesure ne dit rien d'une vraie machine.
