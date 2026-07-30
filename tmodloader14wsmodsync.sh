#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tModLoader 1.4+ Workshop mod sync for the AMP Generic module
#
# Called from tmodloader14wsupdates.json as:
#   /bin/bash <script> <BaseDir> <WorkshopMods> <ModPath> <AutoEnableMods>
#
# 1. Extracts Workshop item IDs from the "Workshop Mods" setting
#    (raw IDs, item URLs and collection URLs are all accepted)
# 2. Expands collections via the public Steam Web API (no API key needed)
# 3. Writes <ModPath>/install.txt (the format used by tModLoader's own
#    manage-tModLoaderServer.sh, so the file stays portable)
# 4. Downloads with SteamCMD, verifying what actually landed and retrying
#    the items it silently skipped
# 5. Removes mods that are no longer in the list
# 6. Normalises anything AMP's built-in Workshop store dropped in flat, so
#    the layout always matches <workshop>/content/1281930/<id>/<ver>/*.tmod
# 7. Optionally regenerates <ModPath>/enabled.json from every .tmod found
#
# The script is idempotent: running it again only downloads what changed.
# ---------------------------------------------------------------------------

set -uo pipefail

APPID=1281930

BASEDIR="${1:-}"
MODLIST_RAW="${2:-}"
MODPATH="${3:-ModLoader/Mods}"
AUTOENABLE="${4:-True}"

if [[ -z "$BASEDIR" ]]; then
	echo "[mod-sync] No base directory supplied, aborting"
	exit 1
fi

BASEDIR="${BASEDIR%/}"
WORKSHOPDIR="$BASEDIR/steamapps/workshop"
CONTENTDIR="$WORKSHOPDIR/content/$APPID"
MODSDIR="$BASEDIR/$MODPATH"

mkdir -p "$MODSDIR" "$CONTENTDIR"

# Does a Workshop item have at least one .tmod on disk?
function item_present {
	local id="$1"
	compgen -G "$CONTENTDIR/$id/*.tmod" >/dev/null 2>&1 && return 0
	compgen -G "$CONTENTDIR/$id/*/*.tmod" >/dev/null 2>&1 && return 0
	compgen -G "$CONTENTDIR/$id/*/*/*.tmod" >/dev/null 2>&1 && return 0
	return 1
}

# --- 1. Collect IDs -------------------------------------------------------
# Any 6+ digit number in the setting is treated as a published file ID, which
# covers "123456789", "https://steamcommunity.com/sharedfiles/filedetails/?id=123456789"
# and comma/space/newline separated lists alike.
mapfile -t RAW_IDS < <(echo "$MODLIST_RAW" | grep -oE '[0-9]{6,}' | sort -u)

if [[ ${#RAW_IDS[@]} -eq 0 ]]; then
	echo "[mod-sync] No Workshop mods configured"
else
	echo "[mod-sync] ${#RAW_IDS[@]} Workshop ID(s) found in settings"
fi

# --- 2. Expand collections ------------------------------------------------
IDS=()
for id in "${RAW_IDS[@]:-}"; do
	[[ -z "$id" ]] && continue
	children=""
	if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
		children=$(curl -s --max-time 20 \
			-d "collectioncount=1" -d "publishedfileids[0]=$id" \
			https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/ \
			| jq -r '.response.collectiondetails[0].children[]?.publishedfileid' 2>/dev/null)
	fi
	if [[ -n "$children" ]]; then
		echo "[mod-sync] $id is a collection, adding $(echo "$children" | wc -l) mod(s)"
		while read -r child; do
			[[ -n "$child" ]] && IDS+=("$child")
		done <<<"$children"
	else
		IDS+=("$id")
	fi
done

# De-duplicate
if [[ ${#IDS[@]} -gt 0 ]]; then
	mapfile -t IDS < <(printf '%s\n' "${IDS[@]}" | sort -u)
fi

# --- 3. install.txt -------------------------------------------------------
: >"$MODSDIR/install.txt"
for id in "${IDS[@]:-}"; do
	[[ -n "$id" ]] && echo "$id" >>"$MODSDIR/install.txt"
done

# --- 4. SteamCMD download, with verification and retries ------------------
if [[ ${#IDS[@]} -gt 0 ]]; then
	STEAMCMD=""
	for candidate in \
		"$(command -v steamcmd 2>/dev/null)" \
		"$HOME/steamcmd/steamcmd.sh" \
		"$HOME/.steam/steamcmd/steamcmd.sh" \
		"$BASEDIR/../steamcmd/steamcmd.sh"; do
		[[ -n "$candidate" && -f "$candidate" ]] && STEAMCMD="$candidate" && break
	done

	if [[ -z "$STEAMCMD" ]]; then
		STEAMCMD=$(find "$HOME" -maxdepth 5 -name 'steamcmd.sh' -type f 2>/dev/null | head -n1)
	fi

	if [[ -z "$STEAMCMD" ]]; then
		echo "[mod-sync] SteamCMD not found, installing a local copy"
		mkdir -p "$BASEDIR/steamcmd"
		if curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
			| tar zxf - -C "$BASEDIR/steamcmd"; then
			STEAMCMD="$BASEDIR/steamcmd/steamcmd.sh"
			chmod +x "$STEAMCMD"
		else
			echo "[mod-sync] ERROR: could not obtain SteamCMD, skipping mod download"
			STEAMCMD=""
		fi
	fi

	if [[ -n "$STEAMCMD" ]]; then
		# SteamCMD silently drops items on large collections when logged in
		# anonymously, and still exits 0. An incomplete mod set is worse than an
		# obvious failure: the server starts, then crashes much later during
		# world generation with an error that points at the mods rather than at
		# the download. So trust the filesystem, not the exit code.
		MAX_ATTEMPTS=5
		attempt=1
		missing=("${IDS[@]}")

		while [[ ${#missing[@]} -gt 0 && $attempt -le $MAX_ATTEMPTS ]]; do
			if [[ $attempt -eq 1 ]]; then
				echo "[mod-sync] Downloading ${#IDS[@]} mod(s) with SteamCMD"
			else
				echo "[mod-sync] Attempt $attempt: ${#missing[@]} mod(s) still missing, retrying"
			fi

			CMD=("$STEAMCMD" +force_install_dir "$BASEDIR" +login anonymous)
			for id in "${missing[@]}"; do
				CMD+=(+workshop_download_item "$APPID" "$id")
			done
			CMD+=(+quit)
			"${CMD[@]}" || echo "[mod-sync] SteamCMD exited non-zero, checking what landed anyway"

			still_missing=()
			for id in "${missing[@]}"; do
				item_present "$id" || still_missing+=("$id")
			done
			missing=("${still_missing[@]}")
			attempt=$((attempt + 1))
		done

		if [[ ${#missing[@]} -gt 0 ]]; then
			echo "[mod-sync] ============================================================"
			echo "[mod-sync] WARNING: ${#missing[@]} mod(s) could not be downloaded after"
			echo "[mod-sync] $MAX_ATTEMPTS attempts: ${missing[*]}"
			echo "[mod-sync] The server will run with an INCOMPLETE mod set. For mod packs"
			echo "[mod-sync] this usually surfaces later as a world generation crash."
			echo "[mod-sync] Run Update again to retry the missing items."
			echo "[mod-sync] ============================================================"
		else
			echo "[mod-sync] All ${#IDS[@]} mod(s) present on disk"
		fi
	fi
fi

# --- 5. Prune mods that are no longer in the list --------------------------
# Without this, mods installed during earlier attempts stay on disk and get
# re-enabled by the auto-enable step, silently turning the server into a
# superset of what was asked for - fatal for finely balanced mod packs. Only
# runs when a list is configured, so an empty field never wipes anything.
if [[ ${#IDS[@]} -gt 0 ]]; then
	declare -A WANTED=()
	for id in "${IDS[@]}"; do WANTED[$id]=1; done

	for iddir in "$CONTENTDIR"/*; do
		[[ -d "$iddir" ]] || continue
		id="$(basename "$iddir")"
		[[ "$id" =~ ^[0-9]+$ ]] || continue
		if [[ -z "${WANTED[$id]:-}" ]]; then
			echo "[mod-sync] Removing Workshop item $id (no longer in the mod list)"
			rm -rf "$iddir"
		fi
	done
fi

# --- 6. Normalise the AMP mod-store layout --------------------------------
# AMP's Workshop store may drop items directly into the download location.
# tModLoader expects <steamworkshopfolder>/content/<appid>/<id>/...
shopt -s nullglob
for dir in "$WORKSHOPDIR"/[0-9]*; do
	[[ -d "$dir" ]] || continue
	id="$(basename "$dir")"
	[[ "$id" =~ ^[0-9]+$ ]] || continue
	if [[ ! -e "$CONTENTDIR/$id" ]]; then
		echo "[mod-sync] Relocating Workshop item $id into content/$APPID/"
		mv "$dir" "$CONTENTDIR/$id"
	fi
done

# --- 7. enabled.json ------------------------------------------------------
if [[ "${AUTOENABLE,,}" == "true" || "$AUTOENABLE" == "1" ]]; then
	declare -A SEEN=()
	NAMES=()

	# Workshop mods: <id>/<version>/<ModName>.tmod - keep the newest version
	for iddir in "$CONTENTDIR"/*; do
		[[ -d "$iddir" ]] || continue
		newest=$(find "$iddir" -name '*.tmod' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
		[[ -z "$newest" ]] && continue
		name="$(basename "$newest" .tmod)"
		[[ -n "${SEEN[$name]:-}" ]] && continue
		SEEN[$name]=1
		NAMES+=("$name")
	done

	# Manually uploaded mods in the Mods folder
	for tmod in "$MODSDIR"/*.tmod; do
		[[ -f "$tmod" ]] || continue
		name="$(basename "$tmod" .tmod)"
		[[ -n "${SEEN[$name]:-}" ]] && continue
		SEEN[$name]=1
		NAMES+=("$name")
	done

	if [[ ${#NAMES[@]} -gt 0 ]]; then
		{
			echo "["
			for i in "${!NAMES[@]}"; do
				sep=","
				[[ $i -eq $((${#NAMES[@]} - 1)) ]] && sep=""
				printf '  "%s"%s\n' "${NAMES[$i]}" "$sep"
			done
			echo "]"
		} >"$MODSDIR/enabled.json"
		echo "[mod-sync] enabled.json regenerated with ${#NAMES[@]} mod(s)"
	else
		echo "[]" >"$MODSDIR/enabled.json"
		echo "[mod-sync] No mods found, enabled.json emptied"
	fi
else
	echo "[mod-sync] Auto-enable disabled, leaving enabled.json untouched"
fi

echo "[mod-sync] Done"
exit 0
