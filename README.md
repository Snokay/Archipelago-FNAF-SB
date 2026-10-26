# Five Nights at Freddy's: Security Breach Archipelago — alpha 0.9.1.2

### 📖 [Setup guide / Guide d'installation](SETUP_GUIDE.md) · ⬇️ [Download / Télécharger](../../releases) · 💬 [Discord](https://discord.gg/yqKUMMkWhr)

*(Version française plus bas)*

[Archipelago](https://archipelago.gg) world for **Five Nights at Freddy's: Security Breach** (PC, Steam): badges,
passes, Freddy's upgrades and more are shuffled with the other players of a multiworld. The mod runs on
[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) and comes with a launcher that installs everything.

> **Alpha**: a full game was played from start to goal, but expect bugs. Please report them on the Discord.

## Features

- **About 200 checks**: presents, messages, retro CDs, badge holders, story items and the 35 missions
  (messages, CDs and missions can be turned off).
- **Items**: a **progressive security badge** (each copy = one more security level), the passes (Daycare,
  Complimentary, Party Pass, Dance Pass, Mazercise and bowling tickets...), Freddy's upgrades (Monty's claws,
  Chica's voice box, Roxy's eyes), the flashlight, the Faz Camera, the Fazerblaster, Gregory's upgrades.
- **Bonuses** stored in a wheel (key **G**): flashlight, Freddy and Faz Camera refills, unlimited stamina, and a
  shock that stuns the animatronics around you.
- **Traps**: a StaffBot alert that sends the animatronics after you, a (harmless) jumpscare, broken save
  stations for a few minutes, an empty flashlight.
- **Goal**: an ending of your choice (any, Loading Dock, Fazer Blast, VIP, Burntrap, Alley, or all of them),
  plus, if you want, a number of presents, messages and retro CDs to collect.
- **Multiworld friendly**: the items that open the start of the Pizzaplex stay close to you (quick start), your
  progression items are balanced towards the start of the other games, missable locations never hold anything
  important, and Roxy's eyes (which skip to 6 AM) only come after Roxy. The Photo Pass (exit of the starting
  area) is shuffled between the starting areas of every FNaF SB in the multiworld.
- **DeathLink**, classic or "jumpscare" mode.
- In game: an Archipelago welcome card (key **H**) with your goal, a goal card at the end, the game's own pickup
  window showing what you found and for whom, and a lot of FNaF community references (rewritten messages,
  posters, a concert surprise, trap texts).
- A **PopTracker** pack (`FNaF_SB_AP_<version>.zip`) with every floor of the Pizzaplex.

Some story items always stay at their place and are never shuffled, because the game needs you to pick them up
yourself: the FazWatch, the screwdriver, the Backstage Pass, the Party Pass in Chica's green room and the Monty
Mystery Mix.

## Requirements

- **Your own** copy of the game on Steam (Windows). The Ruin DLC is not part of the randomizer.
- [Archipelago 0.6](https://github.com/ArchipelagoMW/Archipelago/releases) or newer.

Install: see the **[setup guide](SETUP_GUIDE.md)** (launcher, apworld, YAML, connection).

## Not tested in game yet

These changes are new in this version and were only checked on generated seeds, not in a real game. If one of
them goes wrong, please tell us on the Discord:

- the security level kept while you leave a badge holder's room (and level 1 kept in the Daycare until you
  escape it);
- the Daycare badge being shuffled in solo games;
- the Party Pass of Chica's green room and the Monty Mystery Mix staying in your inventory;
- the Mazercise and bowling tickets being shuffled;
- the quick start in multiworld games;
- (0.9.1.1) missions that end without the game's usual signal are now caught up within a few seconds;
- (0.9.1.1) the Photo Pass landing in the starting area of another FNaF SB player;
- (0.9.1.2) the security level capped at 10 (the endo area badge holder could push it to 11 and crash the game).

## Known limitations (alpha)

- If a scene gets stuck (an animatronic or a door that does not move), press **F10**.
- Close the game before installing an update with the launcher.

## Credits and license

- Code: Snokayy, MIT license (see [LICENSE](LICENSE)).
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT license) is shipped with the mod, unchanged.
- No game file is distributed, except images made from the game's textures: the wall posters (the game's
  poster sheets with our own pictures pasted on them, in `mod/ArchipelagoSB/images`) and the item icons and
  floor maps of the PopTracker pack (`poptracker/`, also attached to each release).
- **AI disclosure**: the code is written with an AI assistant (Claude, Anthropic) and reviewed by me before each
  release; the menu logo, loading icon, launcher logo and the concert music are AI-generated. Details in
  🤖 [AI disclosure / Déclaration IA](AI_DISCLOSURE.md)
- Five Nights at Freddy's is a trademark of Scott Cawthon; Security Breach is developed by Steel Wool Studios.
  This fan project is not affiliated with them.

---

# Version française

Monde [Archipelago](https://archipelago.gg) pour **Five Nights at Freddy's: Security Breach** (PC, Steam) :
badges, passes, améliorations de Freddy et plus sont mélangés avec les autres joueurs d'un multiworld. Le mod
tourne sur [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) et un launcher installe tout.

> **Alpha** : une partie complète a été jouée jusqu'au goal, mais il reste des bugs. Signalez-les sur le Discord.

## Contenu

- **Environ 200 checks** : cadeaux, messages, CD rétro, porte-badges, objets de l'histoire et les 35 missions
  (messages, CD et missions désactivables).
- **Objets** : un **badge de sécurité progressif** (chaque exemplaire = un niveau de plus), les passes
  (garderie, Bon d'entrée gratuit, billets d'entrée, piste de danse, billets du Mazercise et du bowling...), les
  améliorations de Freddy (griffes de Monty, boîte vocale de Chica, yeux de Roxy), la lampe torche, la Faz
  Camera, le Fazerblaster, les améliorations de Gregory.
- **Bonus** rangés dans une roue (touche **G**) : recharges de la lampe, de Freddy et de la Faz Camera,
  endurance illimitée, et un choc qui assomme les animatroniques autour de toi.
- **Pièges** : une alerte du StaffBot qui envoie les animatroniques sur toi, un screamer (sans danger), des
  bornes de sauvegarde en panne quelques minutes, une lampe à plat.
- **Objectif** : la fin de ton choix (n'importe laquelle, quai de chargement, Fazer Blast, VIP, Burntrap,
  ruelle, ou toutes), plus, si tu veux, un nombre de cadeaux, de messages et de CD rétro à ramasser.
- **Pensé pour le multiworld** : les objets qui ouvrent le début du Pizzaplex restent près de toi (début rapide),
  tes objets de progression sont ramenés vers le début des autres jeux, les emplacements ratables ne contiennent
  jamais rien d'important, et les yeux de Roxy (qui font passer à 6 h) n'arrivent qu'après Roxy. Le pass photo
  (sortie de la zone de départ) est mélangé entre les zones de départ de tous les FNaF SB du multiworld.
- **DeathLink**, classique ou en mode « screamer ».
- En jeu : une carte de bienvenue Archipelago (touche **H**) avec ton objectif, une carte de fin au goal, la
  fenêtre de ramassage du jeu qui affiche ce que tu as trouvé et pour qui, et plein de références de la commu
  FNaF (messages réécrits, affiches, une surprise au concert, textes des pièges).
- Un pack **PopTracker** (`FNaF_SB_AP_<version>.zip`) avec tous les étages du Pizzaplex.

Quelques objets de l'histoire restent toujours à leur place et ne sont jamais mélangés, parce que le jeu a
besoin que tu les ramasses toi-même : la FazWatch, le tournevis, le Backstage Pass, le billet d'entrée de la
loge de Chica et le Mystery Mix de Monty.

## Prérequis

- **Ta propre** copie du jeu sur Steam (Windows). Le DLC Ruin ne fait pas partie du randomizer.
- [Archipelago 0.6](https://github.com/ArchipelagoMW/Archipelago/releases) ou plus récent.

Installation : voir le **[guide d'installation](SETUP_GUIDE.md)** (launcher, apworld, YAML, connexion).

## Pas encore testé en jeu

Ces changements sont nouveaux dans cette version et n'ont été vérifiés que sur des seeds générées, pas dans
une vraie partie. Si l'un d'eux pose problème, dites-le sur le Discord :

- le niveau de sécurité gardé le temps de sortir de la salle d'un porte-badge (et le niveau 1 gardé dans la
  garderie jusqu'à ce que tu t'en échappes) ;
- le badge de la garderie mélangé en partie solo ;
- le billet d'entrée de la loge de Chica et le Mystery Mix de Monty qui restent dans ton inventaire ;
- les billets du Mazercise et du bowling mélangés ;
- le début rapide en multiworld ;
- (0.9.1.1) les missions qui se terminent sans le signal habituel du jeu, maintenant rattrapées en quelques
  secondes ;
- (0.9.1.1) le pass photo qui tombe dans la zone de départ d'un autre joueur FNaF SB ;
- (0.9.1.2) le niveau de sécurité plafonné à 10 (le porte-badge des endos pouvait le mettre à 11 et faire planter le jeu).

## Limites connues (alpha)

- Si une scène reste coincée (un animatronique ou une porte qui ne bouge plus), appuie sur **F10**.
- Ferme le jeu avant d'installer une mise à jour avec le launcher.

## Crédits et licence

- Code : Snokayy, licence MIT (voir [LICENSE](LICENSE)).
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (licence MIT) est fourni avec le mod, sans modification.
- Aucun fichier du jeu n'est distribué, sauf des images faites à partir des textures du jeu : les affiches
  murales (les planches d'affiches du jeu avec nos images collées dessus, dans `mod/ArchipelagoSB/images`) et les
  icônes et plans d'étage du pack PopTracker (`poptracker/`, aussi joint à chaque release).
- **Déclaration IA** : le code est écrit avec un assistant IA (Claude, Anthropic) et vérifié par moi avant
  chaque publication ; le logo du menu, l'icône de chargement, le logo du launcher et la musique du concert sont
  🤖 [AI disclosure / Déclaration IA](AI_DISCLOSURE.md)
- Five Nights at Freddy's est une marque de Scott Cawthon ; Security Breach est développé par Steel Wool
  Studios. Ce projet de fan n'est pas affilié à eux.
