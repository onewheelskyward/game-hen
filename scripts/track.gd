extends Node2D
## A closed-loop race track drawn from a smoothed centerline.

const WIDTH := 170.0
const CURB := 10.0
const SMOOTH_STEPS := 12

const ROAD_COLOR := Color(0.32, 0.32, 0.35)
const CURB_RED := Color(0.8, 0.15, 0.15)
const CURB_WHITE := Color(0.95, 0.95, 0.95)
const LANE_COLOR := Color(1, 1, 1, 0.45)

# Rough shape of the loop, clockwise. Point 0 is the start/finish line.
var control_points: Array[Vector2] = [
	Vector2(700, 280),
	Vector2(1100, 250),
	Vector2(1500, 450),
	Vector2(1900, 250),
	Vector2(2200, 500),
	Vector2(2150, 1000),
	Vector2(1700, 1100),
	Vector2(1350, 900),
	Vector2(1000, 1150),
	Vector2(1200, 1400),
	Vector2(700, 1450),
	Vector2(300, 1250),
	Vector2(200, 800),
	Vector2(300, 350),
]

## Dense, smoothed centerline. points[0] sits on the start/finish line.
var points := PackedVector2Array()


func _init() -> void:
	points = _catmull_rom(control_points, SMOOTH_STEPS)


## Returns {"index": nearest centerline segment, "distance": px from centerline}.
func nearest(pos: Vector2) -> Dictionary:
	var best_index := 0
	var best_distance := INF
	var n := points.size()
	for i in n:
		var closest := Geometry2D.get_closest_point_to_segment(pos, points[i], points[(i + 1) % n])
		var d := pos.distance_to(closest)
		if d < best_distance:
			best_distance = d
			best_index = i
	return {"index": best_index, "distance": best_distance}


func _draw() -> void:
	var n := points.size()
	var closed := points.duplicate()
	closed.append(points[0])

	# Red/white curbs, then the road surface on top.
	for i in n:
		draw_circle(points[i], WIDTH * 0.5 + CURB, CURB_RED if i % 6 < 3 else CURB_WHITE)
	for i in n:
		draw_circle(points[i], WIDTH * 0.5, ROAD_COLOR)
	draw_polyline(closed, ROAD_COLOR, WIDTH)

	# Dashed center line.
	for i in range(0, n, 2):
		draw_line(points[i], points[(i + 1) % n], LANE_COLOR, 4.0)

	_draw_start_line()


func _draw_start_line() -> void:
	var origin := points[0]
	var dir := (points[1] - points[0]).normalized()
	var across := dir.orthogonal()
	var size := 14.0
	var count := int(WIDTH / size)
	for row in 2:
		for col in count:
			var center := origin + across * (-WIDTH * 0.5 + size * (col + 0.5)) + dir * (size * (row - 0.5))
			var hx := dir * size * 0.5
			var hy := across * size * 0.5
			var color := Color.WHITE if (row + col) % 2 == 0 else Color.BLACK
			draw_colored_polygon(PackedVector2Array([
				center - hx - hy, center + hx - hy, center + hx + hy, center - hx + hy,
			]), color)


static func _catmull_rom(ctrl: Array[Vector2], steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (
				2.0 * p1
				+ (p2 - p0) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
			))
	return out
