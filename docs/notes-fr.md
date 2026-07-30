# Notes de travail (FR)

Journal des problèmes rencontrés et de leurs causes réelles, pour ne pas les
remordre en montant le même genre de template pour d'autres jeux.

## Les pièges AMP

### `manifest.json` est obligatoire

Sans ce fichier à la racine du dépôt, AMP clone le repo, écrit les fichiers dans
`~/.ampdata/instances/ADS01/Plugins/ADSModule/DeploymentTemplates/<repo>/`,
ne journalise **aucune erreur**, et ignore purement et simplement les templates.
On peut cliquer sur Fetch indéfiniment sans jamais rien voir apparaître.

L'`id` doit être différent de celui de CubeCoders, sinon AMP considère qu'il
s'agit du même dépôt.

### La liste des templates est construite au démarrage de l'ADS

Un Fetch met à jour les fichiers sur le disque, pas la liste proposée à la
création d'instance. Il faut `ampinstmgr restart ADS01` puis Ctrl+Shift+R.

### L'espace en fin de ligne du délimiteur

`App.CommandLineParameterDelimiter= ` doit se terminer par une espace. Les
éditeurs, les diffs et l'éditeur web de GitHub la suppriment sans prévenir, et
rien ne signale l'erreur — la ligne de commande est simplement mal découpée.
Ne jamais retaper le `.kvp` à la main. `prepare.sh` vérifie cette ligne.

### Ne pas donner à un template le nom d'un template officiel

Un fichier homonyme d'un template livré avec AMP se fait masquer. D'où le
préfixe `tmodloader14ws` et un `Meta.AppConfigId` distinct.

### Le metaconfig contient une référence, lui aussi

En renommant les fichiers, `Meta.ConfigManifest`, `Meta.MetaConfigManifest`,
`Meta.ConfigRoot`, `App.Ports`, `App.UpdateSources`, l'argument `-config` **et**
le champ `ConfigFile` du metaconfig doivent tous suivre. En oublier un ne
produit aucune erreur : AMP écrit les réglages dans un fichier que le serveur ne
lit pas, et le serveur démarre avec ses placeholders bruts. Symptôme : le mot de
passe du serveur est littéralement `{{Password}}`, et des dossiers nommés
`{{ModPath}}` et `{{WorldPath}}` apparaissent.

### `sed` et le délimiteur

`s|motif\|alternative|remplacement|` ne fait pas ce qu'on croit : quand `|` est
le délimiteur, `\|` désigne un pipe **littéral**, pas une alternation. Utiliser
`#` ou `/` comme délimiteur dès qu'il y a une alternation.

## Le bug d'état « Starting » infini

```
Console.AppReadyRegex=^(Listening on port|Escuchando en puerto) (\d+)$
```

Deux problèmes cumulés : le premier groupe capturant contient du texte au lieu du
port, et seules deux langues sont couvertes. Un serveur en `fr-FR` ne matche
jamais — il tourne, les joueurs se connectent, AMP reste en *Starting*.

Correctif, un seul groupe capturant et un match sur le mot « port » dans les dix
langues du serveur, sans dépendre de la formulation exacte des traductions :

```
Console.AppReadyRegex=^[^\d]*?(?:[Pp]ort|porta|puerto|porcie|порт\w*|端口|ポート)[^\d]*(\d{2,5})\.?$
```

Le `^[^\d]*?` initial empêche de matcher les lignes horodatées, ce qui limite les
faux positifs.

## SteamCMD abandonne des mods en silence

En `+login anonymous`, sur une grosse collection, SteamCMD saute des items **et
sort quand même en 0**. Rien ne le signale au moment du téléchargement.

Le symptôme apparaît bien plus tard : le serveur démarre, puis plante pendant la
génération du monde avec une stack trace qui accuse les mods. Sur le pack
*Infernal Eclipse of Ragnarok*, il manquait un mod de compatibilité croisée
Thorium/SOTS, et le conflit que ce mod neutralise ressortait :

```
SOTS.AbandonedVillageWorldgenHelper → WorldGen.KillTile
  → Thorium.BirdFeederGlobalItem → Player.GetModPlayer<T>
  → IndexOutOfRangeException
```

Plusieurs Update successifs finissaient par compléter le pack, et la génération
passait. D'où la vérification sur le système de fichiers plutôt que sur le code
de retour, avec cinq tentatives et un avertissement bien visible.

## Les mods restaient installés après avoir été retirés

Le script n'ajoutait que des mods, sans jamais en retirer. Combiné à
*Auto-enable*, qui active tout ce qu'il trouve, le serveur tournait sur la
collection **plus** tous les mods des essais précédents — fatal pour un pack
équilibré. Corrigé par l'étape de nettoyage, qui ne s'exécute que si une liste
est configurée, pour qu'un champ vide n'efface jamais rien.

## Le seed par défaut

Le template upstream livrait `PoweredByAMP` comme seed par défaut. La génération
Terraria étant déterministe, tous les utilisateurs génèrent le même monde — et si
un mod plante sur cette configuration de terrain, il plante chez tout le monde, à
chaque tentative. Le champ est désormais vide par défaut, et `IncludeInCommandLine`
est passé à `false` : un `-seed` vide sur la ligne de commande aurait fait avaler
l'argument suivant.

## Modpacks et `enabled.json`

- `enabled.json` est un tableau JSON de **noms internes** de mods. Son ordre n'a
  aucun effet : tModLoader calcule l'ordre de chargement par tri topologique à
  partir des `sortAfter` / `sortBefore` déclarés par les auteurs.
- Un modpack tModLoader est un **dossier** `ModPacks/<nom>/Mods/` contenant
  `enabled.json` et `install.txt`. Le champ *Mod Pack* attend le chemin vers ce
  `enabled.json`, pas un nom.
- Le `install.txt` produit par le client se colle tel quel dans le champ
  *Workshop Mods*.

## Suite : la base générique

Briques réutilisables pour d'autres jeux Steam moddés :

- le **bloc store** (`StoresSupported` / `StoreDownloadLocations` /
  `SteamWorkshopDownloadLocation`), paramétré par AppID et chemin des mods ;
- le **script de synchro** — seuls `APPID` et le format de la liste d'activation
  changent (`enabled.json` ici, `modlist.txt` chez Conan Exiles) ;
- le **duo de champs** *Workshop Mods* / *Auto-enable* ;
- la vérification des téléchargements, qui vaut pour tous les jeux à Workshop.

La forme la plus propre est un `workshop-sync.sh` unique paramétré
(`--appid`, `--mods-dir`, `--enable-format`), inclus par chaque template.

## Sources

- [Wiki AMP — Configuring the 'Generic' AMP module](https://github.com/CubeCoders/AMP/wiki/Configuring-the-'Generic'-AMP-module)
- [CubeCoders/AMPTemplates](https://github.com/CubeCoders/AMPTemplates)
- [tModLoader — manage-tModLoaderServer.sh](https://github.com/tModLoader/tModLoader/blob/1.4.4/patches/tModLoader/Terraria/release_extras/DedicatedServerUtils/manage-tModLoaderServer.sh)
- [tModLoader — Starting a modded server](https://github.com/tModLoader/tModLoader/wiki/Starting-a-modded-server)
- [tModLoader — ModOrganizer.cs](https://github.com/tModLoader/tModLoader/blob/master/patches/tModLoader/Terraria.ModLoader.Core/ModOrganizer.cs)
