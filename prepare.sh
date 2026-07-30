#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Health check for the template files.
#
#   ./prepare.sh [github-user/repo]
#
# Run this before every push. It verifies the things that silently break an
# AMP template - the kind of breakage that produces no error anywhere, just a
# template that never appears, or settings that never apply:
#
#   - the trailing space on App.CommandLineParameterDelimiter
#   - every cross-reference between the files actually resolving
#   - the fetch URLs pointing at this repository
#   - manifest.json present (without it AMP clones the repo and ignores it)
#   - JSON syntax
#
# Exits non-zero on the first real problem.
# ---------------------------------------------------------------------------

set -uo pipefail

cd "$(dirname "$(realpath "$0")")"

REPO="${1:-arnhotv/amp-tmodloader-plus}"
PREFIX="tmodloader14ws"
FAILED=0

function ok   { echo "OK   - $1"; }
function fail { echo "FAIL - $1"; FAILED=1; }
function warn { echo "WARN - $1"; }

echo "--- files ---"
for f in "$PREFIX.kvp" "${PREFIX}config.json" "${PREFIX}metaconfig.json" \
	"${PREFIX}ports.json" "${PREFIX}updates.json" "${PREFIX}serverconfig.txt" \
	"${PREFIX}modsync.sh" "manifest.json"; do
	[[ -f "$f" ]] && ok "$f present" || fail "$f is missing"
done

echo
echo "--- the trailing space ---"
# Written by hand because most editors strip it and no tool warns you.
if grep -q "^App\.CommandLineParameterDelimiter= $" "$PREFIX.kvp"; then
	ok "App.CommandLineParameterDelimiter ends with a space"
else
	fail "App.CommandLineParameterDelimiter lost its trailing space - fix with:"
	echo "       sed -i 's#^App\\.CommandLineParameterDelimiter=.*#App.CommandLineParameterDelimiter= #' $PREFIX.kvp"
fi

echo
echo "--- cross-references ---"
# Every file the .kvp points at must exist under the current prefix.
while read -r ref; do
	[[ -z "$ref" ]] && continue
	if [[ -f "$ref" ]]; then
		ok "$ref referenced and present"
	else
		fail "$PREFIX.kvp references $ref, which does not exist"
	fi
done < <(grep -oE "tmodloader14[a-z]*\.(kvp|json|txt|sh)" "$PREFIX.kvp" | sort -u)

# Stale references to the pre-rename names, anywhere.
STALE=$(grep -rn "tmodloader14[^w]" --include='*.kvp' --include='*.json' \
	--include='*.txt' --include='*.sh' \
	--exclude='prepare.sh' --exclude='rename-unique.sh' . 2>/dev/null \
	| grep -v '^\./\.git')
if [[ -z "$STALE" ]]; then
	ok "no leftover references to the old file names"
else
	fail "stale references to the old names:"
	echo "$STALE" | sed 's/^/       /'
fi

echo
echo "--- update URLs ---"
BADURL=$(grep -oE 'raw\.githubusercontent\.com/[^"]+' "${PREFIX}updates.json" \
	| grep -v "$REPO/" || true)
if [[ -z "$BADURL" ]]; then
	ok "fetch URLs point at $REPO"
else
	fail "fetch URLs pointing elsewhere:"
	echo "$BADURL" | sed 's/^/       /'
fi

if grep -q 'REPLACE_WITH' "${PREFIX}updates.json"; then
	fail "a REPLACE_WITH placeholder is still in ${PREFIX}updates.json"
fi

echo
echo "--- manifest ---"
if grep -q '"repotype"' manifest.json 2>/dev/null; then
	ok "manifest.json declares a repotype"
	if grep -q 'ec280171-c67b-4cf8-923f-dc27fea91ee1' manifest.json; then
		fail "manifest id is CubeCoders' own - AMP will treat this as their repo"
	fi
else
	fail "manifest.json is missing or has no repotype - AMP will ignore this repo"
fi

echo
echo "--- JSON syntax ---"
# On Windows "python3" is often a Microsoft Store alias stub that exits
# non-zero without running anything, so test each candidate first.
JSON_CHECK=""
for py in python3 python py; do
	if command -v "$py" >/dev/null 2>&1 && "$py" -c "pass" >/dev/null 2>&1; then
		JSON_CHECK="$py"; JSON_KIND="python"; break
	fi
done
if [[ -z "$JSON_CHECK" ]] && command -v node >/dev/null 2>&1; then
	JSON_CHECK="node"; JSON_KIND="node"
fi

if [[ -n "$JSON_CHECK" ]]; then
	for f in *.json; do
		if [[ "$JSON_KIND" == "python" ]]; then
			"$JSON_CHECK" -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" >/dev/null 2>&1
		else
			"$JSON_CHECK" -e 'JSON.parse(require("fs").readFileSync(process.argv[1]))' "$f" >/dev/null 2>&1
		fi
		[[ $? -eq 0 ]] && ok "$f is valid JSON" || fail "$f is not valid JSON"
	done
else
	warn "no Python or Node found, skipping JSON validation"
fi

echo
echo "--- shell syntax ---"
bash -n "${PREFIX}modsync.sh" && ok "${PREFIX}modsync.sh parses" || fail "${PREFIX}modsync.sh has a syntax error"

echo
if [[ $FAILED -eq 0 ]]; then
	echo "All checks passed. Safe to commit and push."
else
	echo "Some checks failed - fix them before pushing."
	exit 1
fi
