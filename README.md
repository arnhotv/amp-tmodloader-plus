# amp-tmodloader-plus

An AMP Generic module template for **tModLoader 1.4+** with first-class Steam Workshop
support, based on the `tmodloader14` template from
[CubeCoders/AMPTemplates](https://github.com/CubeCoders/AMPTemplates).

## What it adds over the stock template

| | Stock `tmodloader14` | This template |
|---|---|---|
| Server reaches "Running" in AMP | English/Spanish servers only | **all 10 supported languages** |
| Install Workshop mods | not supported | AMP mod store **+** ID / link / **collection** field |
| Enable installed mods | edit `enabled.json` by hand | generated automatically |
| Mod pack | one cryptic line of help | documented, with its relationship to `enabled.json` |

### The startup bug

The stock template uses:

```
Console.AppReadyRegex=^(Listening on port|Escuchando en puerto) (\d+)$
```

The first capture group holds text rather than the port number, and only two
languages are covered. On a server running in any other language the instance
stays stuck in *Starting* forever even though the server is up and players can
join. This template uses a single capture group and matches the word "port" in
every language the server ships with:

```
Console.AppReadyRegex=^[^\d]*?(?:[Pp]ort|porta|puerto|porcie|порт\w*|端口|ポート)[^\d]*(\d{2,5})\.?$
```

### Workshop mods

Two complementary mechanisms:

1. **AMP's built-in mod store** — `App.StoresSupported=SteamWorkshop` enables the
   Mods tab with Workshop search and one-click install.
2. **The "Workshop Mods" setting** — paste item IDs, item links or **collection
   links**, separated by commas, spaces or new lines. On update,
   `tmodloader14modsync.sh` expands collections through the public Steam Web API,
   downloads everything with SteamCMD, writes `install.txt` in tModLoader's own
   format, and regenerates `enabled.json`.

The server is launched with `-steamworkshopfolder`, exactly like tModLoader's
official `manage-tModLoaderServer.sh`, so no manual copying is ever needed.

## Setup

```bash
git clone https://github.com/<you>/amp-tmodloader-plus.git
cd amp-tmodloader-plus
./prepare.sh <you>/amp-tmodloader-plus
git commit -am "Prepare template" && git push
```

`prepare.sh` does two things and validates the result:

- restores the trailing space on `App.CommandLineParameterDelimiter`
  (stored as the `@@SPACE@@` placeholder in git, because editors and diff tools
  strip trailing whitespace silently — a broken delimiter mangles the command line)
- points the update stages at your repository so AMP can fetch
  `tmodloader14modsync.sh` and `tmodloader14serverconfig.txt`

Then, in AMP: **Configuration → Instance Deployment → Custom template repository**,
enter your repository, click **Fetch latest**, and create an instance from the
*tModLoader 1.4+ (Workshop)* template.

## Requirements

- AMP **2.6.5.2** or later (needed for the mod store fields)
- Linux, ideally containerised (`cubecoders/ampbase:debian`)
- Windows works, but the Workshop sync stage is Linux-only for now — see below

## Known limitations

- The mod sync stage is `UpdateSourcePlatform: Linux`. A PowerShell equivalent is
  needed before this could be proposed upstream.
- `App.SteamUpdateAnonymousLogin=NotMods` is inherited from `palworld-modded.kvp`.
  If AMP asks for Steam credentials while *Update Source* is **GitHub**, set it
  back to `False`; the sync script uses its own anonymous SteamCMD session anyway.
- Mods are synchronised on **update**, not on every start. Press *Update* after
  changing the mod list.

## Credits

Original template by **JasperFirecai2**, **EnderWolf** and **IceOfWraith**
(CubeCoders/AMPTemplates, GPL-3.0). Workshop support, startup fix and tooling
added here.
