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

if command -v python3 >/dev/null 2>&1; then
	for f in *.json; do
		python3 -c "import json,sys; json.load(open('$f'))" \
			&& echo "OK  - $f is valid JSON" \
			|| { echo "FAIL - $f is not valid JSON"; exit 1; }
	done
fi

bash -n tmodloader14modsync.sh && echo "OK  - tmodloader14modsync.sh syntax is valid"

echo
echo "Done. Commit and push, then point AMP at your repository."
