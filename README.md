# rudeclaude

**Un outil [RudeOps](https://www.rudeops.com), la newsletter DevOps à lire
avant de déployer.** [S'abonner →](https://www.rudeops.com)

Un tableau de bord épuré, en direct dans le terminal, pour suivre son usage de
[Claude Code](https://claude.com/claude-code) : les limites d'usage de
l'abonnement, l'activité du jour et ce que fait Claude dans chaque session.

![rudeclaude en mode image (démo)](docs/capture-image.png)

> **Projet non officiel.** rudeclaude n'est ni affilié à Anthropic, ni
> approuvé par Anthropic. « Claude » et « Claude Code » sont des marques
> d'Anthropic.

> **Portage macOS.** Ce dépôt est un fork de
> [rudeops/rudeclaude](https://github.com/rudeops/rudeclaude), qui ne
> fonctionnait que sous Linux. Il ajoute la prise en charge de macOS sous deux
> formes :
>
> - **dans le terminal**, le même tableau de bord que l'original : le jeton de
>   Claude Code est lu dans le trousseau macOS ;
> - **en widget de barre des menus**, une app native qui affiche la limite de
>   5 heures en permanence et le tableau de bord complet au clic, et peut
>   aussi l'épingler sur le bureau
>   ([voir plus bas](#widget-de-barre-des-menus-macos)).
>
> Le fonctionnement sous Linux est inchangé.

## Ce qu'il affiche

- **Limites** : le pourcentage consommé sur la fenêtre de 5 heures et sur la
  semaine, et le temps restant avant chaque remise à zéro. L'anneau passe du
  jaune à l'orange à partir de 70 %, puis au rouge à partir de 90 %. Le petit
  point indique le temps écoulé dans la fenêtre : si l'arc le dépasse, la
  consommation va plus vite que le temps.
- **Semaine par produit** : la répartition de la consommation de la semaine
  entre Claude Code, les conversations (claude.ai, application de bureau),
  Cowork et le reste, telle que la renvoie l'API d'usage.
- **Aujourd'hui** : le nombre de réponses de Claude, les tokens générés et la
  part des tokens d'entrée servis par le cache.
- **Activité** : les tokens générés minute par minute sur la dernière heure.
- **Sessions** : chaque session active dans l'heure, avec son projet, sa
  branche git, son modèle, la taille de son contexte et ce que fait Claude :
  - vert : il travaille (« exécute une commande », « modifie un fichier »…) ;
  - jaune : il vous pose une question et attend votre réponse ;
  - gris : il a terminé, ou la session est inactive.
- **Outils** les plus utilisés dans l'heure, et **crédits extra** consommés
  dans le mois.

## Prérequis

- **Linux ou macOS.**
- **Claude Code**, connecté avec un abonnement Claude (Pro ou Max).
- **Go 1.27** ou plus récent, pour compiler (sous macOS : `brew install go`).
- Pour le widget macOS : macOS 14 ou plus récent et les outils en ligne de
  commande de Xcode (`xcode-select --install`). Xcode lui-même n'est pas
  nécessaire.
- Un terminal en couleurs 24 bits. Pour le rendu en images : un terminal qui
  supporte le [protocole graphique de kitty](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
  (Ghostty, kitty, WezTerm, Konsole…).

## Installation

Depuis les sources de ce fork :

```bash
git clone -b macos https://github.com/swannrobbes-oss/rudeclaude.git
cd rudeclaude
go build -o rudeclaude .
```

`go install github.com/rudeops/rudeclaude@latest` installe la version
d'origine, sans le portage macOS.

## Utilisation

```bash
rudeclaude
```

| Option | Effet |
|---|---|
| `--interval 2m` | délai entre deux appels à l'API d'usage (1 min par défaut, 30 s minimum) |
| `--render auto\|image\|text` | force le rendu (détecté automatiquement par défaut) |
| `--demo` | données fictives, sans appel réseau ni lecture des journaux |
| `--snapshot fichier.png` | exporte une image du tableau de bord, puis quitte |
| `--json` | écrit le tableau de bord en JSON, puis quitte |
| `--version` | affiche la version, puis quitte |

Touches : `r` pour rafraîchir, `q` pour quitter.

### Rendus

- **Images** : dans les terminaux compatibles, le tableau de bord est dessiné
  en vraies images lissées (police Inter), avec un fond transparent.
- **Texte** : partout ailleurs (y compris dans tmux), la même vue en caractères.

![rudeclaude en mode texte (démo)](docs/capture-texte.png)

### Dans le terminal, sous macOS

- **Rendu en images** dans Ghostty, kitty et WezTerm. Terminal.app, iTerm2 et
  le terminal de VS Code passent automatiquement en rendu texte.
- **Trousseau** : au premier lancement, macOS demande l'autorisation de lire
  les identifiants de Claude Code. Choisissez « Toujours autoriser » pour ne
  plus la voir.
- Pour lancer `rudeclaude` depuis n'importe quel dossier : `go install .`, puis
  ajoutez `~/go/bin` à votre `PATH`.

## Widget de barre des menus (macOS)

Une app native affiche dans la barre des menus le pourcentage consommé sur la
fenêtre de 5 heures (`42 %`), précédé d'une bulle quand Claude vous pose une
question et attend votre réponse. Un clic ouvre le tableau de bord complet, en mode sombre
comme dans le terminal : anneaux, activité du jour, sessions, outils.

Chaque session suit le code couleur du terminal : point vert qui pulse quand
Claude travaille, ligne jaune encadrée quand il attend votre réponse, grisée
une fois inactive. La jauge de contexte reste grise jusqu'à 70 % puis passe à
l'orange et au rouge ; le survol affiche le détail complet.

Le menu **⋯** en haut du panneau regroupe « Rafraîchir » (⌘R), « Widget sur le
bureau », « Ouvrir au démarrage » et « Quitter » (⌘Q).

« Widget sur le bureau » épingle le tableau de bord sur le bureau, en format
paysage, en bandes : les anneaux face à la journée et à la répartition par
produit, l'activité face à RTK, puis les sessions sur deux colonnes. Il reste au-dessus du fond d'écran et des icônes, sous toutes les autres
fenêtres, sur tous les bureaux. Faites-le glisser où vous voulez ; sa position
est retenue. Pour le voir quand des fenêtres le recouvrent, affichez le bureau
(fn + F11).

Si rtk (Rust Token Killer) est installé, une section **RTK**
affiche les tokens économisés aujourd'hui et au total, la moyenne économisée et
un histogramme des 7 derniers jours (lus avec `rtk gain --daily --format json`).
Sans rtk, la section n'apparaît pas.

L'app embarque le binaire rudeclaude et l'appelle toutes les 30 secondes avec
`--json`. Le cache partagé limite toujours l'API à un appel par minute, même
avec le terminal ouvert en parallèle.

Compilation et installation :

```bash
macos/build.sh
cp -R macos/build/RudeClaude.app /Applications/
open /Applications/RudeClaude.app
```

Cochez « Ouvrir au démarrage » depuis la copie installée dans `/Applications`,
pas depuis `macos/build/`. Après une mise à jour du code, relancez
`macos/build.sh` et recopiez l'app.

## Confidentialité et sécurité

rudeclaude ne lit que deux choses :

1. **Les identifiants de Claude Code**, pour les limites d'usage : le fichier
   `.credentials.json` de `~/.claude` (ou de `$CLAUDE_CONFIG_DIR`) sous Linux,
   l'entrée `Claude Code-credentials` du trousseau sous macOS. Le jeton OAuth
   y est lu à chaque appel et envoyé **uniquement** à `api.anthropic.com`. Il
   n'est jamais affiché, copié ni rafraîchi : s'il a expiré, relancez
   `claude`.

   Sous macOS, le trousseau demande l'autorisation au premier lancement
   (l'accès passe par l'outil `security` du système) : choisissez
   « Toujours autoriser » pour ne plus la voir.
2. **`projects/**/*.jsonl`** dans `~/.claude`, les journaux de Claude Code,
   pour l'activité et les sessions. Seules les métadonnées sont exploitées : horodatage, projet,
   branche, modèle, compteurs de tokens et noms des outils. Le contenu des
   conversations n'est jamais interprété, stocké ni transmis.

La dernière réponse de l'API d'usage est mise en cache, sans le jeton, dans
`~/.cache/rudeclaude/usage.json` sous Linux et
`~/Library/Caches/rudeclaude/usage.json` sous macOS. Plusieurs fenêtres ou le
widget ouverts en même temps n'appellent ainsi pas l'API plus d'une fois par
minute au total.

Attention : les sorties `--snapshot` et `--json` montrent les noms de vos
projets et de vos branches.

## Limites connues

- L'API d'usage (`/api/oauth/usage`) n'est **pas documentée** par Anthropic et
  peut changer ou disparaître sans préavis.
- Seule l'activité de Claude Code sur la machine locale est détaillée. Les
  conversations sur claude.ai ou dans l'application de bureau comptent dans
  les limites et apparaissent dans la répartition de la semaine, mais pas
  dans l'activité ni les sessions. La fenêtre de 5 heures n'est pas répartie
  par produit.
- Une demande d'autorisation en attente (avant de lancer une commande) ne
  laisse pas de trace dans les journaux : la session reste affichée comme
  « exécute une commande », avec la durée écoulée au-delà de 2 minutes.
- L'interface est en français.
- Le widget macOS est signé localement (sans compte développeur Apple) : il
  est prévu pour être compilé sur la machine où il tourne, pas distribué.

## Structure du code

```
main.go                 options et choix du rendu
internal/usage/         appel à l'API d'usage, jeton (fichier ou trousseau), cache partagé
internal/activity/      suivi des sessions dans les journaux de Claude Code
internal/rtk/           tokens économisés par rtk (rtk gain), pour le widget
internal/gfx/           dessin en images de la vue d'ensemble, police Inter
internal/kitty/         protocole graphique de kitty
internal/ui/            boucle du mode image, repli texte (Bubble Tea)
internal/theme/         couleurs du mode texte
macos/                  widget de barre des menus et de bureau (SwiftUI) et son script de build
```

Les tests se lancent avec `go test ./...`.

## La newsletter RudeOps

rudeclaude est né dans l'atelier de [RudeOps](https://www.rudeops.com), une
newsletter de veille tech et DevOps indépendante, pour celles et ceux qui font
tourner des systèmes en production.

À l'origine, RudeOps, c'était juste l'envie d'arrêter d'envoyer des liens en
vrac sur Slack et de perdre des ressources intéressantes dans des discussions
qui disparaissent deux jours plus tard. Alors j'en ai fait une newsletter.
Sans plan, sans tunnel de conversion, sans bruit inutile : de la veille tech,
du DevOps, de l'open source, des outils utiles, et parfois quelques
réflexions au passage.

**+2 000 abonnés** · **58,7 %** de taux d'ouverture moyen · depuis 2023, et
toujours vivant.

Sur le site, en plus de la newsletter : des [guides](https://www.rudeops.com/guides)
(le DevOps, le modèle CAMS, les trois chemins…), un
[glossaire de la tech](https://www.rudeops.com/rudefinitions) et des quiz pour
préparer les certifications Kubernetes KCNA et KCSA.

**→ [S'abonner sur rudeops.com](https://www.rudeops.com)** ·
[Archives](https://www.rudeops.com/newsletters) ·
[RSS](https://www.rudeops.com/feed.xml)

## Licence

[GPL v3](LICENSE). La police [Inter](https://rsms.me/inter/) est incluse sous
licence [OFL](internal/gfx/fonts/LICENSE.txt).
