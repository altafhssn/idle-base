#!/bin/bash
# Make (or refresh) a scratch slot from the real project or a snapshot. Usage: mkslot.sh SLOT [SRC]
# New slots are APFS clones (cp -c: copy-on-write, nearly free on disk). Refreshes use rsync and keep the
# slot's own import results (.godot/ and *.import). Each slot has its own HOME, so the save stays inside it.
set -e
Q="$(cd "$(dirname "$0")" && pwd)"
# Default source: the repo these scripts live in (tools/testkit/qa -> repo root).
SLOT="$1"; SRC="${2:-$(cd "$Q/../../.." && pwd)}"; SRC="${SRC%/}"
[ -n "$SLOT" ] || { echo "usage: mkslot.sh SLOT [SRC]"; exit 2; }
DST="$Q/slots/$SLOT/proj"
mkdir -p "$Q/slots/$SLOT/home"
if [ ! -d "$DST" ]; then
  TMP="$DST.tmp$$"; rm -rf "$TMP"
  cp -cRp "$SRC" "$TMP"
  find "$TMP" -type d \( -name export -o -name android -o -name docs -o -name keystore -o -name prototypes \) -prune -exec rm -rf {} + 2>/dev/null || true
  find "$TMP" -name .DS_Store -delete 2>/dev/null || true
  rm -f "$TMP/.done"
  mv "$TMP" "$DST"
else
  rsync -a --delete --exclude export/ --exclude android/ --exclude docs/ --exclude keystore/ --exclude prototypes/ \
    --exclude '.DS_Store' --exclude '/.done' --filter='P /.godot/***' --filter='P *.import' "$SRC/" "$DST/"
fi
python3 -I - "$DST/project.godot" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
if "config/use_custom_user_dir" not in s:
    s = s.replace("[application]\n", "[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"DhabaRushQA\"\n", 1)
    open(p, "w", encoding="utf-8").write(s)
PY
echo "slot $SLOT ready: $DST"
