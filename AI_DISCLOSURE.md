# AI disclosure — FNaF: Security Breach Archipelago

*(Version française plus bas)*

## Was AI used?

Yes. This project was developed with the help of an AI assistant.

## Which tools?

- **Claude** (Anthropic), through **Claude Code**, for code and documentation.
- An AI image generator for the **menu logo**, the **loading icon** and the **launcher logo and emblem**
  (`mod/ArchipelagoSB/images/logo_menu.png`, `mod/ArchipelagoSB/images/chargement/`, `launcher/assets/`).
- The **concert music** (`mod/ArchipelagoSB/musique/showtime.mp3`) is AI-generated music.

## For what, and how much?

- **Code**: the code (UE4SS Lua mod, Archipelago bridge, apworld, launcher, PopTracker pack and build scripts) is
  written by Claude, following my instructions and design decisions.
- **Research**: how the game works (inventory, doors and security levels, missions, story order) was found
  together during play sessions: I play and test, Claude writes the scripts that read the game data and analyses
  the results.
- **Documentation**: README, setup guide and release notes were drafted by Claude and reviewed by me.
- **Texts**: the rewritten in-game messages and trap texts (FNaF community references) were written by Claude
  from my ideas.

## How I check the code

The code is written by Claude, and I check it before every release:

- **in game**: every version is played and tested before it is published;
- **in the code itself**: I read the actual code to make sure it is not corrupted and has no security holes;
- when a part really needs to be changed because it is unstable, not optimized or not secure, **I modify it
  myself, by hand**.

## What I do myself

- Design choices: what is shuffled, options, logic, goal, what goes in each version.
- Testing, bug reports, releases and support on the Discord.

I am responsible for everything published here, AI-assisted parts included. If something is wrong or unclear,
please open an issue or ask on the [Discord](https://discord.gg/yqKUMMkWhr).

## Other people's work

Built on [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT license, shipped unchanged with its license). No code
was copied from other Archipelago worlds. See the [README](README.md) for credits and the [MIT license](LICENSE).

---

# Déclaration IA

## IA utilisée ?

Oui. Ce projet a été développé avec l'aide d'un assistant IA.

## Quels outils ?

- **Claude** (Anthropic), via **Claude Code**, pour le code et la documentation.
- Un générateur d'images IA pour le **logo du menu**, l'**icône de chargement** et le **logo et l'emblème du
  launcher**.
- La **musique du concert** (`mod/ArchipelagoSB/musique/showtime.mp3`) est une musique générée par IA.

## Pour quoi, et à quel point ?

- **Code** : le code (mod Lua UE4SS, pont Archipelago, apworld, launcher, pack PopTracker et scripts de build)
  est écrit par Claude, selon mes instructions et mes choix.
- **Recherche** : le fonctionnement du jeu (inventaire, portes et niveaux de sécurité, missions, ordre de
  l'histoire) a été trouvé ensemble pendant des sessions de jeu : je joue et je teste, Claude écrit les scripts
  qui lisent les données du jeu et analyse les résultats.
- **Documentation** : README, guide d'installation et notes de version rédigés par Claude et relus par moi.
- **Textes** : les messages réécrits du jeu et les textes des pièges (références de la commu FNaF) ont été
  écrits par Claude à partir de mes idées.

## Comment je vérifie le code

Le code est écrit par Claude, et je le vérifie avant chaque publication :

- **en jeu** : chaque version est jouée et testée avant d'être publiée ;
- **dans le code lui-même** : je lis le vrai code pour m'assurer qu'il n'est pas corrompu et qu'il n'y a pas
  de failles de sécurité ;
- quand une partie a vraiment besoin d'être modifiée parce qu'elle est instable, pas optimisée ou pas sécurisée,
  **je la modifie moi-même, à la main**.

## Ce que je fais moi-même

- Les choix : ce qui est mélangé, les options, la logique, l'objectif, le contenu de chaque version.
- Les tests, les signalements de bugs, les publications et le support sur le Discord.

Je suis responsable de tout ce qui est publié ici, parties faites avec l'IA comprises. Une erreur ou une
question : ouvrez une issue ou passez sur le [Discord](https://discord.gg/yqKUMMkWhr).

## Le travail des autres

Basé sur [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (licence MIT, fourni sans modification avec sa licence).
Aucun code n'a été copié d'autres mondes Archipelago. Crédits dans le [README](README.md),
[licence MIT](LICENSE).
