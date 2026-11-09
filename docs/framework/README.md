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
| 2 | Pack loader and checker | Done (see below) |
| 3 | Names out of the code | Done (see below) |
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

## Phase 2: theme packs

The game runs a **theme pack**: `themes/<id>/`. The dhaba is `themes/dhaba/`.

```
themes/dhaba/
  theme.json      the game (name, package, version), systems on/off, business words
  economy.json    prices, levels, staff, seats, checkout, pacing (was data/economy_v3.json)
  models/         .glb models + their palettes (was assets/models)
  audio/          sounds, file name = sound id (was assets/audio)
  textures/       narrator sprites, previews (was assets/textures)
```

- **Picking a pack:** `--theme=<id>` after `--`, else the project setting
  `idle_business_kit/theme` (`dhaba`), else `dhaba`.
- **Code never builds a pack path itself:** `ThemePack` (`scripts/kit/theme_pack.gd`) serves
  them; `Models.path_of(id)` / `Models.exists(id)` look in the pack, then the kit's own
  `res://kit/models/`; `Sfx` likewise for sounds. A pack-relative path in the economy
  (e.g. a location's `palette`) resolves inside the pack.
- **Checker:** `--check-pack` runs `PackCheck` (`scripts/kit/pack_check.gd`): theme.json schema,
  economy sections and stations, every model loads, every known sound exists. Prints
  `PACKCHECK fails=N` and quits with N; the suite runs it as the `packcheck` job.
- **While playing**, a model or sound the game asks for but the pack lacks prints
  `[pack] missing model|sound '<id>'`; the suite fails on a missing model.
- The tools (Blender builder, pacing simulator, sound scripts) write to and read from the pack.
- Known gap for phase 3: the checker's sound list is still the dhaba's (chai pour, tandoor
  slap...); it becomes per pack when names move out of the code.

## Phase 3: names out of the code

Five steps, each tested and committed on its own:

1. **Counters as data (done).** Each station's economy entry carries what the engine used to
   know by its id: `role` (`core` = always built, the tutorial starts on it; `first_build` = the
   tutorial's build, locked until then; `first_pad` = the first ghost-pad build of free play;
   `reveal_stats` = brings STATS and opens the signboard), `short_name`, `unit` / `units`,
   `next_chip_skip`, `ui` {icon, menu_icon, doodles, info} and `fx` {cook_sound, dish_sounds,
   cook_pose, steam_local, parts {spin, stir, heap, lid}, board_text, fires}. `Game.core_station()`
   and `Game.station_with_role()` replace the names. The old-save migration (bhurji/dal -> kadai)
   is pack data (`legacy`); growth stage titles are `growth.stages[n].title`; a growth build's
   `core_level` replaces `chai_level` (still read for older packs).
2. **Sounds and words per pack (done).** The per-file sound numbers (loudness, pitch,
   cooldown, bus, variants, horns) moved from `Sfx` into the pack's `audio/sounds.json`; the
   checker wants every sound in it and every sound a station's `fx` names. A pack renames any
   on-screen English with `text/<locale>.json` (`{"messages": {"STAFF": "TEAM"}}`), installed
   as translations by `ThemePack.install_text()`.
3. **Money style per pack (done).** `theme.json` `money` = `symbol` and `number_style`
   (`auto` = lakh/crore on Indian devices, `indian`, `intl`); the display scale is the
   economy's `money_display_scale`; in-app products are `store.products`.
4. **The checkout (decided: no code rename).** "galla" stays the engine's internal word for
   the checkout: its ~600 uses mix code names, method and signal names called by string,
   and save, analytics and tap ids that must not change, so a rename is risky and buys
   nothing for pack authors, who never read engine code. A pack may name the economy section
   `checkout` (or `galla`); what players read comes from the pack's words and text.
5. **Theme-word ratchet (done).** `tools/kit/theme_words.py` counts the pack's own words
   (station ids, staff names, the business word) in engine code per file; the suite's
   `themewords` job fails if any file gains one. Baseline 702 (9 Nov), mostly in files later
   phases own (main3 test drivers 184, layout 124, tutorial 113, dish art 69). Run `--write`
   after a phase removes words to lower the bar.

Layout (phase 4), the tutorial and story (phase 6) and the test drivers keep their dhaba names
until their own phases.

## Ported fixes (Dhaba Rush <-> Idle Business Kit)

| Date | Fix | From | Ported to |
|---|---|---|---|
