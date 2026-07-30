#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time preparation of the template files.
#
#   ./prepare.sh [github-user/repo]
#
# 1. Restores the trailing space on App.CommandLineParameterDelimiter
#    (it is stored as the @@SPACE@@ placeholder in git because most editors
#    and diff tools silently strip trailing whitespace)
# 2. Points the update stages at your own repository so AMP can fetch
#    tmodloader14modsync.sh and tmodloader14serverconfig.txt
#
# Run it once after cloning, then commit the result.
# ---------------------------------------------------------------------------

set -euo pipefail

cd "$(dirname "$(realpath "$0")")"

REPO="${1:-arnhotv/amp-tmodloader-plus}"

if grep -q '@@SPACE@@' tmodloader14.kvp; then
	sed -i 's/^App\.CommandLineParameterDelimiter=@@SPACE@@$/App.CommandLineParameterDelimiter= /' tmodloader14.kvp
	echo "OK  - restored the trailing space on App.CommandLineParameterDelimiter"
else
	echo "--  - delimiter placeholder already replaced, skipping"
fi

if grep -q 'REPLACE_WITH_YOUR_REPO' tmodloader14updates.json; then
	sed -i "s|REPLACE_WITH_YOUR_REPO|$REPO|g" tmodloader14updates.json
	echo "OK  - update stages now point at $REPO"
else
	echo "--  - repository already set in tmodloader14updates.json"
fi

# Sanity checks
grep -q '^App\.CommandLineParameterDelimiter= $' tmodloader14.kvp \
	&& echo "OK  - delimiter verified" \
	|| { echo "FAIL - the delimiter line is still wrong, fix it by hand"; exit 1; }

# Find a JSON validator. On Windows, "python3" is often a Microsoft Store alias
# stub that exits non-zero without running anything, so each candidate is tested
# on a trivial program before being trusted.
JSON_CHECK=""
for py in python3 python py; do
	if command -v "$py" >/dev/null 2>&1 && "$py" -c "pass" >/dev/null 2>&1; then
		JSON_CHECK="$py -c"
		JSON_PROG='import json,sys; json.load(open(sys.argv[1]))'
		break
	fi
done
if [[ -z "$JSON_CHECK" ]] && command -v node >/dev/null 2>&1; then
	JSON_CHECK="node -e"
	JSON_PROG='JSON.parse(require("fs").readFileSync(process.argv[1]))'
fi

if [[ -n "$JSON_CHECK" ]]; then
	for f in *.json; do
		if $JSON_CHECK "$JSON_PROG" "$f" >/dev/null 2>&1; then
			echo "OK  - $f is valid JSON"
		else
			echo "FAIL - $f is not valid JSON"
			exit 1
		fi
	done
else
	echo "WARN- no Python or Node found, skipping JSON validation (not fatal)"
fi

bash -n tmodloader14modsync.sh && echo "OK  - tmodloader14modsync.sh syntax is valid"

echo
echo "Done. Commit and push, then point AMP at your repository."
