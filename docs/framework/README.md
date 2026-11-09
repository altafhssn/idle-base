# Idle Business Kit

A framework for idle service-business games (a dhaba, a car wash, a salon, a hotel...),
made from Dhaba Rush. The goal: a new game is a **theme pack** of data and art only,
with no code edits. The engine keeps the gameplay in generic parts (service points,
staff, seats or bays, checkout, customers); the pack names and draws them.

- Plan (owner's decisions, architecture, theme-pack format, phases, risks):
  [Idle Business Kit: Framework Plan](https://claude.ai/artifact/TxmvhhpDuZAM7QqhmY5A5Y)
- Started from Dhaba Rush commit `05c7825` (9 Nov 2026). Dhaba Rush keeps its own repo;
  fixes do not flow between the two automatically, so note ported fixes below.

## Phases

| # | Phase | State |
|---|---|---|
| 1 | Template repo and test harness | Done (see below) |
| 2 | Pack loader and checker | Not started |
| 3 | Names out of the code | Not started |
| 4 | Layouts from markers | Not started |
| 5 | Switchable systems | Not started |
| 6 | Tutorial and story as data | Not started |
| 7 | UI skins | Not started |
| 8 | Characters (part rig + skinned) | Not started |
| 9 | Non-food sample pack and the "make a new game" guide | Not started |

Every phase ends with the dhaba still passing the full suite against the dhaba baseline.

## Phase 1: the test harness

- The autopilot (`scripts/v3/main3.gd`, `--auto`) no longer names the dhaba's counters:
  it taps what the tutorial's marker stands over (`Director.marker_tap_id()`), follows the
  hand and the dialogue, and its scripted free-play steps say `open_core` / `open_checkout`.
  `Director.core_station()` = the first id in the economy's station order.
- Invariant checks in every run (failing the suite in `tools/testkit/qa/parse.py`):
  - **No stall:** before the tutorial is done, the step, line, panel or sales must move at
    least every 90 s of game time, else `[check] STALL ...` is printed.
  - **Conservation:** at exit, `arrived = paid + inside + left_unpaid`.
- `tutcheck.py` reads `done state: <core station> L<n>`.
- `mkslot.sh` copies the repo it lives in by default.

Run the suite (slots and logs go in a scratch folder outside the repo):
```bash
Q=/path/to/scratch/qa; mkdir -p $Q; cp tools/testkit/qa/*.sh tools/testkit/qa/*.py $Q/
cp -R tools/testkit/qa/logs/baseline_cart $Q/logs/baseline
bash $Q/mkslot.sh main "$(pwd)" && bash $Q/import.sh main && bash $Q/suite.sh main main
```

## Ported fixes (Dhaba Rush <-> Idle Business Kit)

| Date | Fix | From | Ported to |
|---|---|---|---|
