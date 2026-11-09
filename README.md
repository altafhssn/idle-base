# Idle Business Kit

A framework for idle service-business games, built from Dhaba Rush. Start here:
[docs/framework/README.md](docs/framework/README.md). The dhaba is its first theme; the notes
below are Dhaba Rush's own and still apply to it.

## Dhaba Rush: Highway Idle Tycoon

Godot 4.7.2 (GDScript, Compatibility renderer) · Blender 5.2.2 · Android + iOS.
Plan: [PLAN.md](PLAN.md) · Design: [docs/GDD.md](docs/GDD.md) · Store listings / ASO: [docs/aso.md](docs/aso.md)

## Layout
- `scripts/autoload/` — `Game` (state, economy, save/offline), `Ads` (stub until AdMob in W3), `Analytics` (stub until GameAnalytics in W2)
- `scripts/world/` — vehicles, customers, stations, unlock pads, cash tray, layout, model loader
- `scripts/ui/hud.gd` — money bar, rush button, upgrades sheet, offline popup
- `data/economy.json` — all tuning numbers
- `tools/sim/pacing.py` — economy pacing simulator (reads economy.json)
- `tools/blender/build_assets.py` — builds every model + palette into `assets/models/*.glb`

## Common commands
Rebuild all models (and a review sheet):
```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/build_assets.py -- assets/models --sheet docs/art/asset_sheet.png
```
Check pacing after editing economy.json:
```bash
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 -I tools/sim/pacing.py --hours 3
```
Run the game (debug flags after `--`: `--fresh`, `--unlock=N`, `--money=N`, `--speed=N`, `--autoplay`, `--night`, `--cam=x,z`, `--shot=path --shot-after=sec`):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --fresh
```
Build the Android debug APK:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug "Android" export/android/DhabaRush-debug.apk
```
Install on a phone connected by USB (USB debugging on):
```bash
~/Library/Android/sdk/platform-tools/adb install -r export/android/DhabaRush-debug.apk
```
