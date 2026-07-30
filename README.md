# tModLoader 1.4+ for AMP, with working Workshop mods

An [AMP](https://cubecoders.com/AMP) template that lets you run a modded
Terraria server and install mods by pasting a Steam Workshop link — no SSH, no
`.tmod` files to copy around, no `enabled.json` to edit by hand.

Built on the official [CubeCoders](https://github.com/CubeCoders/AMPTemplates)
`tmodloader14` template, with the Workshop plumbing it was missing and a fix for
the bug that leaves the instance stuck on *Starting*.

---

## What you get

**Install mods from a link.** Paste a mod ID, a mod URL, or a whole **collection
URL** into one field and press Update. Collections are expanded automatically, so
a 50-mod pack is a single paste.

**Mods that actually all arrive.** Steam's downloader quietly gives up on some
items in large collections and reports success anyway. This template checks what
really landed on disk and retries, because a mod pack missing one file doesn't
fail at download time — it fails an hour later, mid world generation, with an
error blaming the mods.

**A server that reports itself as running.** The stock template only recognises
the startup message in English and Spanish. Run your server in French, German or
Chinese and AMP waits forever on *Starting* while players are already connected.
Fixed for all ten supported languages.

**Mods enabled for you.** Everything installed gets written into `enabled.json`
automatically. Remove a mod from the list and it's removed from the server too,
instead of lingering and quietly staying active.

---

## Getting started

**1. Add the repository to AMP.**
Go to **Configuration → Instance Deployment → Add a Configuration Repository**
and enter:

```
arnhotv/amp-tmodloader-plus:main
```

Click **Fetch**.

**2. Restart the ADS.**

```bash
ampinstmgr restart ADS01
```

This step is not optional. AMP builds its template list when the ADS starts, so
after a Fetch alone the new template simply won't be there. Reload the browser
with Ctrl+Shift+R afterwards.

**3. Create your instance.**
**Create Instance → tModLoader 1.4+ (Workshop)**. Leave *Update Source* on
**GitHub** — no Steam account needed. Press **Update**, then **Start**.

Requires AMP 2.6.5.2 or later, on Linux (a container is fine). Windows runs the
server, but the mod sync step is Linux-only for now.

---

## Adding mods

Open your instance's settings, find **Workshop Mods** under the ModLoader
section, and paste whatever you have:

```
3456508757
```

```
https://steamcommunity.com/sharedfiles/filedetails/?id=2824688072
2909886416, 2824688804
```

Both work. IDs, full URLs, collections, separated by commas, spaces or line
breaks — it sorts itself out. Press **Update** and watch the console: lines
starting with `[mod-sync]` tell you what's being downloaded.

**Using a mod pack?** Paste the collection ID rather than the individual mods.
You get exactly the pack's contents at the pack's versions, which matters — these
packs rely on cross-compatibility mods that break the game when one is missing.

**Already have a pack set up in the game?** In tModLoader, go to
**Workshop → Mod Packs → Save Enabled as New Mod Pack → Open Mod Pack Folder**.
The `install.txt` inside contains your mod IDs, one per line. Paste its contents
straight into the field.

---

## Settings worth knowing

| Setting | What it does |
|---|---|
| **Workshop Mods** | Your mod list. IDs, links, collections. |
| **Auto-enable Installed Mods** | On by default. Turn it off to manage `enabled.json` yourself — useful for disabling a mod without uninstalling it. |
| **World Seed** | Leave empty for a random world. See the warning below. |
| **tModLoader Version (GitHub)** | Pin a specific release, e.g. `v2024.10.3.0`. Leave empty for the latest. Useful when a pack targets an older build. |
| **Mod Pack** | Path to a pack's `enabled.json`. Only needed if you juggle several mod sets on one instance. |

---

## If something goes wrong

**The template doesn't show up in Create Instance.**
Nine times out of ten the ADS wasn't restarted — see step 2. AMP logs nothing
when it ignores a template, so there's no error to look for.

**Mods are installed but the server crashes generating the world.**
First, run **Update** again and check the console. If you see a warning about
missing mods, some downloads failed and the pack is incomplete; repeat until the
sync reports everything present.

If the mod set is complete and it still crashes, some mods call client-only code
during world generation and simply cannot generate on a dedicated server.
Generate the world in the game instead, then upload both the `.wld` **and**
`.twld` files to your instance and point *World Name* at it.

**A world that crashes keeps crashing.**
Terraria's generation is deterministic: the same seed always builds the same
world, so a mod that crashes on it crashes every single time. Clear the **World
Seed** field to get a fresh layout. This is why the field is empty by default.

**Settings in AMP have no effect, and your server password is literally
`{{Password}}`.**
That's a broken config mapping. Make sure you're on the current version of the
template — this was a bug in an early release.

---

## Contributing

Run the health check before every push:

```bash
./prepare.sh <you>/amp-tmodloader-plus
```

It catches the failures that produce no error message anywhere: a missing
`manifest.json` (AMP silently ignores the whole repository without it), a
cross-reference pointing at a renamed file, and the trailing space on
`App.CommandLineParameterDelimiter` that every editor strips without asking.

Never retype the `.kvp` by hand — copy the file.

A French write-up of every trap hit while building this, and why each one is
invisible, is in [`docs/notes-fr.md`](docs/notes-fr.md).

---

## Credits

Original template by **JasperFirecai2**, **EnderWolf** and **IceOfWraith** for
[CubeCoders/AMPTemplates](https://github.com/CubeCoders/AMPTemplates), GPL-3.0.
Workshop support, the startup fix and the tooling were added here.
