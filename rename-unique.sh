#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Give the template a file name that cannot collide with the official
# tmodloader14 template shipped with AMP.
#
#   ./rename-unique.sh [github-user/repo] [new-prefix]
#
# Defaults: arnhotv/amp-tmodloader-plus, prefix "tmodloader14ws"
#
# AMP merges custom repositories with its built-in template set. A file named
# exactly like an official one gets shadowed, and the template silently never
# appears in the instance creation list. Renaming removes that whole class of
# problem.
#
# Run once, then commit and push.
# ---------------------------------------------------------------------------

set -euo pipefail

cd "$(dirname "$(realpath "$0")")"

REPO="${1:-arnhotv/amp-tmodloader-plus}"
NEW="${2:-tmodloader14ws}"
OLD="tmodloader14"

if [[ ! -f "$OLD.kvp" ]]; then
	echo "Nothing to do: $OLD.kvp not found (already renamed?)"
	exit 0
fi

# 1. Rename the files
for ext in kvp config.json metaconfig.json ports.json updates.json serverconfig.txt modsync.sh; do
	if [[ -f "$OLD$ext" ]]; then
		git mv "$OLD$ext" "$NEW$ext" 2>/dev/null || mv "$OLD$ext" "$NEW$ext"
		echo "OK  - $OLD$ext -> $NEW$ext"
	fi
done

# 2. Rewrite every internal reference (Meta.ConfigManifest, App.Ports,
#    App.UpdateSources, the -config launch argument, the fetch URLs...)
for f in "$NEW.kvp" "$NEW"updates.json; do
	[[ -f "$f" ]] || continue
	sed -i "s|$OLD\(config\.json\|metaconfig\.json\|ports\.json\|updates\.json\|serverconfig\.txt\|modsync\.sh\|\.kvp\)|$NEW\1|g" "$f"
	echo "OK  - references rewritten in $f"
done

# 3. Make sure the fetch URLs point at the right repository
sed -i "s|raw.githubusercontent.com/[^/]*/[^/]*/main/|raw.githubusercontent.com/$REPO/main/|g" "$NEW"updates.json
echo "OK  - fetch URLs point at $REPO"

# 4. A distinct AppConfigId so AMP never confuses this with the official one
NEWID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python -c "import uuid;print(uuid.uuid4())" 2>/dev/null || echo "b7e41f92-8c3a-4d16-a5e8-3f9c2d7b1a04")
sed -i "s|^Meta.AppConfigId=.*|Meta.AppConfigId=$NEWID|" "$NEW.kvp"
echo "OK  - new AppConfigId: $NEWID"

# 5. Verify nothing got lost
echo
echo "--- checks ---"
grep -q "^App\.CommandLineParameterDelimiter= $" "$NEW.kvp" \
	&& echo "OK  - trailing space on the delimiter is intact" \
	|| { echo "FAIL - the delimiter lost its trailing space"; exit 1; }

grep -q "Meta.ConfigManifest=${NEW}config.json" "$NEW.kvp" \
	&& echo "OK  - ConfigManifest points at ${NEW}config.json" \
	|| { echo "FAIL - ConfigManifest was not rewritten"; exit 1; }

grep -q "Meta.ConfigRoot=$NEW.kvp" "$NEW.kvp" \
	&& echo "OK  - ConfigRoot points at $NEW.kvp" \
	|| { echo "FAIL - ConfigRoot was not rewritten"; exit 1; }

echo
echo "Remaining references to the old name (should be empty):"
grep -n "$OLD[a-z]" "$NEW.kvp" "$NEW"updates.json | grep -v "$NEW" || echo "  (none)"

echo
echo "Done. git add -A && git commit -m 'Rename to avoid clashing with the official template' && git push"
echo "Then hit Fetch in AMP again and refresh the browser."
