# Setup guide — FNaF: Security Breach Archipelago

*(Version française plus bas)*

## 1. Download

- [Archipelago 0.6](https://github.com/ArchipelagoMW/Archipelago/releases) or newer (Windows installer).
- From the [releases](../../releases) of this project: `FNaF_SB_Archipelago_<version>_launcher.zip` and, if you
  want a tracker, `FNaF_SB_AP_<version>.zip` (PopTracker pack).

Unzip the launcher zip anywhere (keep the `files` folder next to `FNaF_SB_AP_Launcher.exe`).

## 2. Install the mod

1. Close the game.
2. Start `FNaF_SB_AP_Launcher.exe` and open **Setup**.
3. **Game folder**: the `Quarters` folder of the game (for example
   `C:\Program Files (x86)\Steam\steamapps\common\Quarters`). **Archipelago folder**: where Archipelago is
   installed (for example `C:\ProgramData\Archipelago`).
4. Choose the **apworld language** (French or English item and location names), then click
   **Install / update**.

This installs UE4SS and the mod into the game, and the apworld into Archipelago's `custom_worlds` folder.
**Uninstall** removes all of it. Later versions: the launcher tells you when an update is out and installs it.

## 3. Your options (YAML)

Open **My options (YAML)** in the launcher, set your slot name and options, then **Save YAML…** and send it to
the host (or **Put in Archipelago/Players** if you host).

## 4. Hosting (if you are the host)

The **Host** screen walks you through it: put the YAMLs in `Archipelago/Players`, **Generate**, then start the
server with the generated game. Send the room address to the other players. Everyone who generates or hosts needs
the apworld in `custom_worlds` (the Setup button does it; you can also send them `fnafsb.apworld`).

## 5. Play

1. Open **Play** in the launcher, enter the **room address** (for example `archipelago.gg:38281`), your **slot
   name** (exactly as in your YAML) and the password if there is one.
2. **Test connection** if you want, then **Play**: the game starts and connects by itself (an Archipelago card
   appears in game; key **H** shows it again).
3. Start a **new game** for each new Archipelago game.

In game: **G** = bonus wheel, **H** = Archipelago card, **F10** = unstick a stuck scene.

## 6. PopTracker (optional)

Put `FNaF_SB_AP_<version>.zip` in PopTracker's `packs` folder, open **FNaF Security Breach Archipelago**, click
**AP** and enter the room address and your slot.

## Manual install (without the launcher)

Everything is in the `files` folder of the launcher zip. `<Win64>` = `Quarters\fnaf9\Binaries\Win64` in the game
folder.

1. Close the game. Copy the **content** of `files\ue4ss\` into `<Win64>` (you get `<Win64>\dwmapi.dll` and the
   `<Win64>\ue4ss\` folder).
2. Copy the folder `files\mod\ArchipelagoSB` into `<Win64>\ue4ss\Mods\`.
3. Open `<Win64>\ue4ss\Mods\mods.txt` and add the line `ArchipelagoSB : 1` **above** the `Keybinds : 1` line. If
   the file does not exist, create it with these two lines: `ArchipelagoSB : 1` then `Keybinds : 1`.
4. Copy `files\apworld\en\fnafsb.apworld` (or `fr` for French names) into Archipelago's `custom_worlds` folder.
   For your YAML, use **Generate Template Options** in the Archipelago Launcher.
5. To connect, create `<Win64>\ue4ss\ArchipelagoSB\connection.json`:

   ```json
   {"uri": "archipelago.gg:38281", "slot": "YourSlotName", "password": ""}
   ```

   Then start the game from Steam: the mod starts the Archipelago bridge by itself. Change the file for each new
   room.

Uninstall: delete `<Win64>\ue4ss\Mods\ArchipelagoSB` and its line in `mods.txt` (and `dwmapi.dll` plus the `ue4ss`
folder if you have no other UE4SS mod).

## Problems

- **Bug report** in the launcher gathers the logs; **Open logs** shows them.
- Ask on the [Discord](https://discord.gg/yqKUMMkWhr).

---

# Guide d'installation

## 1. Télécharger

- [Archipelago 0.6](https://github.com/ArchipelagoMW/Archipelago/releases) ou plus récent (installateur Windows).
- Dans les [releases](../../releases) de ce projet : `FNaF_SB_Archipelago_<version>_launcher.zip` et, pour un
  tracker, `FNaF_SB_AP_<version>.zip` (pack PopTracker).

Dézippe le launcher où tu veux (garde le dossier `files` à côté de `FNaF_SB_AP_Launcher.exe`).

## 2. Installer le mod

1. Ferme le jeu.
2. Lance `FNaF_SB_AP_Launcher.exe` et ouvre **Installation**.
3. **Dossier du jeu** : le dossier `Quarters` du jeu (par exemple
   `C:\Program Files (x86)\Steam\steamapps\common\Quarters`). **Dossier d'Archipelago** : là où Archipelago est
   installé (par exemple `C:\ProgramData\Archipelago`).
4. Choisis la **langue de l'apworld** (noms des objets et emplacements en français ou en anglais), puis clique
   sur **Installer / mettre à jour**.

Ça installe UE4SS et le mod dans le jeu, et l'apworld dans le dossier `custom_worlds` d'Archipelago.
**Désinstaller** retire tout. Versions suivantes : le launcher te prévient quand une mise à jour sort et
l'installe.

## 3. Tes options (YAML)

Ouvre **Mes options (YAML)** dans le launcher, mets ton nom de slot et tes options, puis **Enregistrer le
YAML…** et envoie-le à l'hôte (ou **Mettre dans Archipelago/Players** si c'est toi qui héberges).

## 4. Héberger (si tu es l'hôte)

L'écran **Héberger** te guide : mets les YAML dans `Archipelago/Players`, **Générer**, puis lance le serveur avec
la partie générée. Envoie l'adresse de la room aux autres joueurs. Tous ceux qui génèrent ou hébergent ont
besoin de l'apworld dans `custom_worlds` (le bouton d'installation le fait ; tu peux aussi leur envoyer
`fnafsb.apworld`).

## 5. Jouer

1. Ouvre **Jouer** dans le launcher, entre l'**adresse de la room** (par exemple `archipelago.gg:38281`), ton
   **nom de slot** (exactement celui de ton YAML) et le mot de passe s'il y en a un.
2. **Tester la connexion** si tu veux, puis **Jouer** : le jeu démarre et se connecte tout seul (une carte
   Archipelago s'affiche en jeu ; la touche **H** la réaffiche).
3. Commence une **nouvelle partie** pour chaque nouvelle partie Archipelago.

En jeu : **G** = roue des bonus, **H** = carte Archipelago, **F10** = débloquer une scène coincée.

## 6. PopTracker (facultatif)

Mets `FNaF_SB_AP_<version>.zip` dans le dossier `packs` de PopTracker, ouvre **FNaF Security Breach
Archipelago**, clique sur **AP** et entre l'adresse de la room et ton slot.

## Installation manuelle (sans le launcher)

Tout est dans le dossier `files` du zip du launcher. `<Win64>` = `Quarters\fnaf9\Binaries\Win64` dans le dossier
du jeu.

1. Ferme le jeu. Copie le **contenu** de `files\ue4ss\` dans `<Win64>` (tu obtiens `<Win64>\dwmapi.dll` et le
   dossier `<Win64>\ue4ss\`).
2. Copie le dossier `files\mod\ArchipelagoSB` dans `<Win64>\ue4ss\Mods\`.
3. Ouvre `<Win64>\ue4ss\Mods\mods.txt` et ajoute la ligne `ArchipelagoSB : 1` **au-dessus** de la ligne
   `Keybinds : 1`. Si le fichier n'existe pas, crée-le avec ces deux lignes : `ArchipelagoSB : 1` puis
   `Keybinds : 1`.
4. Copie `files\apworld\fr\fnafsb.apworld` (ou `en` pour les noms en anglais) dans le dossier `custom_worlds`
   d'Archipelago. Pour ton YAML, utilise **Generate Template Options** dans le launcher d'Archipelago.
5. Pour te connecter, crée `<Win64>\ue4ss\ArchipelagoSB\connection.json` :

   ```json
   {"uri": "archipelago.gg:38281", "slot": "TonNomDeSlot", "password": ""}
   ```

   Puis lance le jeu depuis Steam : le mod démarre le pont Archipelago tout seul. Change le fichier à chaque
   nouvelle room.

Désinstaller : supprime `<Win64>\ue4ss\Mods\ArchipelagoSB` et sa ligne dans `mods.txt` (et `dwmapi.dll` plus le
dossier `ue4ss` si tu n'as pas d'autre mod UE4SS).

## Problèmes

- **Rapport de bug** dans le launcher rassemble les journaux ; **Ouvrir les journaux** les affiche.
- Demande sur le [Discord](https://discord.gg/yqKUMMkWhr).
