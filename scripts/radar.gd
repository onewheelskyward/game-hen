extends Control
## Circular, heading-up radar in the HUD corner. The car sits in the middle
## pointing up, so upcoming corners appear above it in the direction you'll
## turn. A sweep line circles for flavor.

const TrackScript := preload("res://scripts/track.gd")

const RANGE := 2500.0        # world px from the car to the radar's edge
const SWEEP_SECONDS := 2.0   # time for one full sweep
const SWEEP_TRAIL := 14      # lines in the fading sweep trail

const BG_COLOR := Color(0.02, 0.12, 0.05, 0.8)
const RING_COLOR := Color(0.35, 1.0, 0.45, 0.18)
const EDGE_COLOR := Color(0.35, 1.0, 0.45, 0.7)
const ROAD_EDGE_COLOR := Color(0.1, 0.45, 0.15)
const ROAD_COLOR := Color(0.45, 1.0, 0.55)
const START_COLOR := Color.WHITE
const CAR_COLOR := Color(1.0, 0.85, 0.2)

var track: TrackScript
var car: Node2D

var _sweep_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_sweep_time = fmod(_sweep_time + delta, SWEEP_SECONDS)
	queue_redraw()


func _draw() -> void:
	if track == null or car == null:
		return
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	var world_to_radar := radius / RANGE
	draw_set_transform(size * 0.5)

	draw_circle(Vector2.ZERO, radius, BG_COLOR)
	draw_arc(Vector2.ZERO, radius / 3.0, 0.0, TAU, 48, RING_COLOR, 1.0, true)
	draw_arc(Vector2.ZERO, radius * 2.0 / 3.0, 0.0, TAU, 48, RING_COLOR, 1.0, true)
	draw_line(Vector2(0, -radius), Vector2(0, radius), RING_COLOR, 1.0)
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), RING_COLOR, 1.0)

	# World -> radar: center on the car, rotate so its heading points up, scale down.
	var turn := -car.rotation - PI * 0.5
	var pts := PackedVector2Array()
	pts.resize(track.points.size())
	for i in track.points.size():
		pts[i] = (track.points[i] - car.position).rotated(turn) * world_to_radar

	var road_width := maxf(TrackScript.WIDTH * world_to_radar, 3.0)
	for run in _clip_loop(pts, radius):
		draw_polyline(run, ROAD_EDGE_COLOR, road_width + 3.0)
	for run in _clip_loop(pts, radius):
		draw_polyline(run, ROAD_COLOR, road_width)

	# Start/finish tick, if it's in range.
	var start := pts[0]
	if start.length() < radius - road_width:
		var across := (pts[1] - pts[0]).normalized().orthogonal() * (road_width + 3.0)
		draw_line(start - across, start + across, START_COLOR, 2.0)

	# Sector timing lines.
	for k in range(1, TrackScript.SECTOR_COUNT):
		var i := track.sector_start(k)
		var p := pts[i]
		if p.length() < radius - road_width:
			var across_s := (pts[i + 1] - p).normalized().orthogonal() * (road_width + 3.0)
			draw_line(p - across_s, p + across_s, TrackScript.SECTOR_LINE_COLOR, 2.0)

	_draw_sweep(radius)

	# The car: an arrow pointing up.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -8), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6),
	]), CAR_COLOR)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, EDGE_COLOR, 2.0, true)


func _draw_sweep(radius: float) -> void:
	var angle := _sweep_time / SWEEP_SECONDS * TAU
	for k in SWEEP_TRAIL:
		var fade := 1.0 - float(k) / SWEEP_TRAIL
		var color := Color(EDGE_COLOR, 0.35 * fade)
		draw_line(Vector2.ZERO, Vector2.from_angle(angle - k * 0.035) * radius, color, 2.0)


## Splits the closed polyline into runs that lie inside the circle.
func _clip_loop(pts: PackedVector2Array, radius: float) -> Array[PackedVector2Array]:
	var runs: Array[PackedVector2Array] = []
	var run := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var seg := _clip_segment(pts[i], pts[(i + 1) % n], radius)
		if seg.is_empty():
			if run.size() >= 2:
				runs.append(run)
			run = PackedVector2Array()
			continue
		if run.is_empty() or not run[run.size() - 1].is_equal_approx(seg[0]):
			if run.size() >= 2:
				runs.append(run)
			run = PackedVector2Array([seg[0]])
		run.append(seg[1])
	if run.size() >= 2:
		runs.append(run)
	return runs


## Clips segment a-b to a circle at the origin. Returns [] or [start, end].
func _clip_segment(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var d := b - a
	var qa := d.dot(d)
	if qa == 0.0:
		return PackedVector2Array()
	var qb := 2.0 * a.dot(d)
	var qc := a.dot(a) - radius * radius
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return PackedVector2Array()
	var root := sqrt(disc)
	var t0 := maxf((-qb - root) / (2.0 * qa), 0.0)
	var t1 := minf((-qb + root) / (2.0 * qa), 1.0)
	if t0 >= t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])
