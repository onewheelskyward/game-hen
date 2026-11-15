extends Node2D
## Arcade top-down RC car. Steering only bites while moving, and the
## back end slides a little before grip pulls it back in line.

const ENGINE_ACCEL := 700.0
const REVERSE_ACCEL := 420.0
const BRAKE_DECEL := 1100.0
const ROLL_DECEL := 250.0
const MAX_SPEED := 560.0
const MAX_REVERSE := 180.0
const STEER_RATE := 3.2          # radians/sec at full steering speed
const FULL_STEER_SPEED := 120.0  # speed at which steering reaches full strength
const GRIP := 6.0                # how quickly sideways sliding dies out
const GRASS_MAX_SPEED := 200.0
const GRASS_DECEL := 900.0
const GRASS_GRIP := 3.0

const BODY_COLOR := Color(0.85, 0.15, 0.1)
const GLASS_COLOR := Color(0.6, 0.85, 1.0)
const TIRE_COLOR := Color(0.08, 0.08, 0.08)

var velocity := Vector2.ZERO
var controls_enabled := false
var on_grass := false


func _process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if controls_enabled:
		throttle = Input.get_axis("brake", "accelerate")
		steer = Input.get_axis("steer_left", "steer_right")

	# Turn first; steering strength scales with speed and flips in reverse.
	var speed := velocity.dot(Vector2.RIGHT.rotated(rotation))
	var steer_factor := clampf(absf(speed) / FULL_STEER_SPEED, 0.0, 1.0) * signf(speed)
	rotation += steer * STEER_RATE * steer_factor * delta

	# Split velocity into the car's new forward and sideways directions.
	var forward := Vector2.RIGHT.rotated(rotation)
	var side := forward.orthogonal()
	speed = velocity.dot(forward)
	var slide := velocity.dot(side)

	if throttle > 0.0:
		speed += throttle * ENGINE_ACCEL * delta
	elif throttle < 0.0:
		if speed > 0.0:
			speed = maxf(speed + throttle * BRAKE_DECEL * delta, 0.0)
		else:
			speed += throttle * REVERSE_ACCEL * delta
	else:
		speed = move_toward(speed, 0.0, ROLL_DECEL * delta)

	var top_speed := GRASS_MAX_SPEED if on_grass else MAX_SPEED
	if speed > top_speed:
		speed = move_toward(speed, top_speed, GRASS_DECEL * delta)
	speed = maxf(speed, -MAX_REVERSE)

	var grip := GRASS_GRIP if on_grass else GRIP
	slide = lerpf(slide, 0.0, 1.0 - exp(-grip * delta))

	velocity = forward * speed + side * slide
	position += velocity * delta


func _draw() -> void:
	# Car faces +X.
	for wheel: Vector2 in [Vector2(10, -11), Vector2(10, 11), Vector2(-10, -11), Vector2(-10, 11)]:
		draw_rect(Rect2(wheel - Vector2(6, 3), Vector2(12, 6)), TIRE_COLOR)
	draw_rect(Rect2(-17, -9, 34, 18), BODY_COLOR)
	draw_rect(Rect2(3, -7, 7, 14), GLASS_COLOR)
	draw_rect(Rect2(-17, -9, 4, 18), BODY_COLOR.darkened(0.3))
