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

Driving on the grass slows you down. Every lap has hidden checkpoints, so you can't cut across the infield. Your best lap is saved between sessions.

## Layout

- `main.tscn` — entry scene
- `scripts/main.gd` — race flow: countdown, laps, checkpoints, HUD, input bindings
- `scripts/track.gd` — track shape (`control_points`) and drawing
- `tools/make_track_points.py` — regenerates `control_points` from a circuit GeoJSON file
- `scripts/car.gd` — car handling; tune the constants at the top

## Track data

The Monza layout comes from [bacinger/f1-circuits](https://github.com/bacinger/f1-circuits) (MIT license), converted at 4 px per meter and lightly smoothed:

```bash
curl -sLO https://raw.githubusercontent.com/bacinger/f1-circuits/master/circuits/it-1922.geojson
python3 tools/make_track_points.py it-1922.geojson
```

Paste the output into `control_points` in `scripts/track.gd`. Other circuits in that repo work the same way.
