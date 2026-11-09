#!/bin/bash
# Standard QA suite in a slot. Usage: [PREV_BASE=DIR] [ALLOW_MOVE=step,...] suite.sh SLOT TAG [quick]
#  full : tutorial --auto + 600 s free play EN seeds 1-4, Hindi seed 1, tap-check, zoom-test, sdk-test
#  quick: EN seeds 1-2, tap-check, zoom-test
# After the jobs: tutcheck.py (per-beat tutorial bars against $Q/logs/baseline and PREV_BASE, default the
# same baseline) -> $L/tutcheck.txt, then parse.py -> $L/summary.txt (RESULT: PASS needs TUTCHECK fails=0).
Q="$(cd "$(dirname "$0")" && pwd)"
SLOT="$1"; TAG="$2"; MODE="${3:-full}"
L="$Q/logs/$TAG"; mkdir -p "$L"
"$Q/savecheck.sh" || exit 1
# drop this suite's own results from an earlier run with the same TAG (other logs in $L are kept)
rm -f "$L"/tut_en_s[0-9].log "$L"/tut_hi_s1.log "$L"/tapcheck.log "$L"/zoomtest.log "$L"/sdktest.log "$L"/packcheck.log "$L"/themewords.log \
  "$L"/tutcheck.txt "$L"/summary.txt "$L"/savecheck.txt
SEEDS="1 2 3 4"; [ "$MODE" = quick ] && SEEDS="1 2"
# each job gets its own slot copy so saves never collide
jobs_list=()
for s in $SEEDS; do jobs_list+=("tut_en_s$s|1200|--fresh --auto --seed=$s --window=600 --stats=120 --quit-at=820"); done
[ "$MODE" = full ] && jobs_list+=("tut_hi_s1|600|--lang=hi --fresh --auto --seed=1 --quit-at=260")
jobs_list+=("tapcheck|600|--fresh --skip-tutorial --money=1e12 --tap-check")
jobs_list+=("zoomtest|300|--fresh --skip-tutorial --zoom-test")
jobs_list+=("packcheck|180|--check-pack")
[ "$MODE" = full ] && jobs_list+=("sdktest|600|--fresh --sdk-test")
i=0
for j in "${jobs_list[@]}"; do
  name="${j%%|*}"; rest="${j#*|}"; lim="${rest%%|*}"; args="${rest#*|}"
  sub="${SLOT}__$name"
  "$Q/mkslot.sh" "$sub" "$Q/slots/$SLOT/proj" > /dev/null
  if [ "$name" = sdktest ]; then ( FIXED= "$Q/run.sh" "$sub" "$L/$name.log" "$lim" -- $args ) &
  else ( "$Q/run.sh" "$sub" "$L/$name.log" "$lim" -- $args ) & fi
  i=$((i+1)); if [ $((i % 3)) -eq 0 ]; then wait; fi
done
wait
"$Q/savecheck.sh" > "$L/savecheck.txt" 2>&1
# Idle Business Kit: no engine file may gain theme words (tools/kit/theme_words.py)
TW="$Q/slots/$SLOT/proj/tools/kit/theme_words.py"
if [ -f "$TW" ]; then
  python3 -I "$TW" --root "$Q/slots/$SLOT/proj" --check > "$L/themewords.log" 2>&1; echo "rc=$?" >> "$L/themewords.log"
fi
python3 -I "$Q/tutcheck.py" "$L" --base "$Q/logs/baseline" --prev "${PREV_BASE:-$Q/logs/baseline}" \
  --allow-move "${ALLOW_MOVE:-}" > "$L/tutcheck.txt" 2>&1
python3 -I "$Q/parse.py" "$L" | tee "$L/summary.txt"
