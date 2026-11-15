# game-hen

A Godot 4 game for macOS and Windows.

## Getting started

1. Install Godot 4 (`brew install --cask godot`, or download from godotengine.org).
2. In the Godot Project Manager, choose **Import** and select this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to race.

## How to play

A top-down RC car time trial: three laps, beat your best lap.

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
- `scripts/track.gd` — track shape (edit `control_points` to redesign it) and drawing
- `scripts/car.gd` — car handling; tune the constants at the top
