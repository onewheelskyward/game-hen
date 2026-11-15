# game-hen

A Godot 4 game for macOS and Windows.

## Getting started

1. Install Godot 4 (`brew install --cask godot`, or download from godotengine.org).
2. In the Godot Project Manager, choose **Import** and select this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to race.

## How to play

A top-down RC car time trial around a scaled-down Monza: three laps, beat your best lap.

| Key | Action |
| --- | --- |
| W / ↑ | Accelerate |
| S / ↓ | Brake, then reverse |
| A / ← and D / → | Steer |
| R | Restart |

Driving on the grass slows you down. The yellow S2 and S3 lines split the lap into Monza's three F1 timing sectors, and you have to cross them in order, so you can't cut across the infield.

The sector table in the top-right corner shows each sector's time and its delta to your all-time best, colored like F1 timing:

- **Purple**: a new all-time best for that sector
- **Green**: your best so far in this race
- **Yellow**: slower than both

Sectors you haven't reached yet show last lap's time, dimmed. Your best lap is saved between sessions. The radar in the bottom-right corner turns with the car, so the corners coming up appear above the yellow arrow.

## Layout

- `main.tscn` — entry scene
- `scripts/main.gd` — race flow: countdown, laps, sector timing, HUD, input bindings
- `scripts/track.gd` — track shape (`control_points`), sector lines (`SECTOR_CONTROL_POINTS`) and drawing
- `tools/make_track_points.py` — regenerates `control_points` from a circuit GeoJSON file
- `scripts/car.gd` — car handling; tune the constants at the top
- `scripts/radar.gd` — heading-up radar minimap (`RANGE` sets how far it sees)

## Track data

The Monza layout comes from [bacinger/f1-circuits](https://github.com/bacinger/f1-circuits) (MIT license), converted at 4 px per meter and lightly smoothed:

```bash
curl -sLO https://raw.githubusercontent.com/bacinger/f1-circuits/master/circuits/it-1922.geojson
python3 tools/make_track_points.py it-1922.geojson
```

Paste the output into `control_points` in `scripts/track.gd`. Other circuits in that repo work the same way.
