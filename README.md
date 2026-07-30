# amp-tmodloader-plus

An AMP Generic module template for **tModLoader 1.4+** with first-class Steam
Workshop support, based on the `tmodloader14` template from
[CubeCoders/AMPTemplates](https://github.com/CubeCoders/AMPTemplates).

## What it adds over the stock template

| | Stock `tmodloader14` | This template |
|---|---|---|
| Server reaches "Running" in AMP | English/Spanish servers only | all 10 supported languages |
| Install Workshop mods | not supported | AMP mod store **+** ID / link / **collection** field |
| Incomplete downloads | — | detected and retried |
| Removing a mod | leaves it installed and enabled | pruned from disk |
| Enable installed mods | edit `enabled.json` by hand | generated automatically |
| Default world seed | fixed (`PoweredByAMP`) | random |
| Pin a tModLoader version | Steam branch only | GitHub release tag too |

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
   `tmodloader14wsmodsync.sh` expands collections through the public Steam Web
   API, downloads everything with SteamCMD, writes `install.txt` in tModLoader's
   own format, prunes what is no longer listed, and regenerates `enabled.json`.

The server is launched with `-steamworkshopfolder`, exactly like tModLoader's
official `manage-tModLoaderServer.sh`, so no manual copying is ever needed.

**Downloads are verified against the filesystem, not against SteamCMD's exit
code.** Logged in anonymously, SteamCMD silently skips items on large
collections and still reports success. A mod pack missing one compatibility
patch does not fail at download time — it fails much later, during world
generation, with a stack trace pointing at the mods. The sync step retries up to
five times and prints a loud warning if anything is still missing.

## Setup

```bash
git clone https://github.com/<you>/amp-tmodloader-plus.git
cd amp-tmodloader-plus
./prepare.sh <you>/amp-tmodloader-plus     # health check, run before every push
```

Then, in AMP: **Configuration → Instance Deployment → Add a Configuration
Repository**, entered as `user/repo:branch`:

```
arnhotv/amp-tmodloader-plus:main
```

Click **Fetch**, then restart the ADS (`ampinstmgr restart ADS01`) and reload the
browser with Ctrl+Shift+R. The template list is built when the ADS starts, so a
Fetch alone will not make a new template appear.

### Two things that break silently

- **`manifest.json` is mandatory.** Without it AMP clones the repository, writes
  the files to disk, logs no error, and ignores every template inside.
- **`App.CommandLineParameterDelimiter` must end with a space.** Editors, diff
  tools and web editors strip trailing whitespace without telling you. Never
  retype the `.kvp` by hand; `prepare.sh` checks this line.

## Requirements

- AMP **2.6.5.2** or later (needed for the mod store fields)
- Linux, ideally containerised (`cubecoders/ampbase:debian`)
- Windows works, but the Workshop sync stage is Linux-only for now

## Notes for mod packs

- Put the **collection ID** in *Workshop Mods* rather than individual IDs. You
  get exactly the pack's contents, at the pack's versions.
- Keep the seed empty. A fixed seed means that if a mod crashes during world
  generation on that layout, it crashes identically on every retry.
- Some mods call client-only code during world generation and crash on a
  dedicated server. When that happens, generate the world in the client with the
  same mod list and upload the `.wld` **and** `.twld` files.

## Credits

Original template by **JasperFirecai2**, **EnderWolf** and **IceOfWraith**
(CubeCoders/AMPTemplates, GPL-3.0). Workshop support, startup fix and tooling
added here.
