extends Node2D
## Race controller: builds the track, car, camera and HUD, then runs a
## countdown and a 3-lap time trial with lap checkpoints.

const TrackScript := preload("res://scripts/track.gd")
const CarScript := preload("res://scripts/car.gd")
const RadarScript := preload("res://scripts/radar.gd")

const TOTAL_LAPS := 3
const SAVE_PATH := "user://best_lap.cfg"
const BANNER_SECONDS := 1.2

enum State { COUNTDOWN, RACING, FINISHED }

var track: TrackScript
var car: CarScript
var camera: Camera2D
var info_label: Label
var banner_label: Label

var state := State.COUNTDOWN
var countdown := 3.0
var race_time := 0.0
var lap := 1
var lap_start := 0.0
var last_lap := -1.0
var best_lap := -1.0
var checkpoints: Array[int] = []
var next_checkpoint := 0
var banner_timer := 0.0


func _ready() -> void:
	_setup_input()
	_load_best()

	track = TrackScript.new()
	add_child(track)

	var n := track.points.size()
	# Each checkpoint is the first centerline segment of a quarter of the loop.
	checkpoints.assign([int(n * 0.25), int(n * 0.5), int(n * 0.75)])

	car = CarScript.new()
	car.position = track.points[n - 3]
	car.rotation = (track.points[0] - track.points[n - 3]).angle()
	add_child(car)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	car.add_child(camera)
	camera.make_current()

	_build_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	var hit := track.nearest(car.position)
	var index: int = hit["index"]
	var distance: float = hit["distance"]
	car.on_grass = distance > TrackScript.WIDTH * 0.5

	# Look ahead in the direction of travel.
	camera.offset = camera.offset.lerp(car.velocity * 0.3, 1.0 - exp(-3.0 * delta))

	match state:
		State.COUNTDOWN:
			countdown -= delta
			if countdown > 0.0:
				banner_label.text = str(int(ceilf(countdown)))
			else:
				state = State.RACING
				car.controls_enabled = true
				_flash("GO!")
		State.RACING:
			race_time += delta
			_update_progress(index)

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_label.text = ""

	_update_info()


func _update_progress(index: int) -> void:
	var n := track.points.size()
	var window := int(n * 0.125)
	if next_checkpoint < checkpoints.size():
		var cp := checkpoints[next_checkpoint]
		if index >= cp and index < cp + window:
			next_checkpoint += 1
	elif index < window:
		_complete_lap()


func _complete_lap() -> void:
	var lap_time := race_time - lap_start
	last_lap = lap_time
	lap_start = race_time
	next_checkpoint = 0

	var new_best := best_lap < 0.0 or lap_time < best_lap
	if new_best:
		best_lap = lap_time
		_save_best()

	if lap >= TOTAL_LAPS:
		state = State.FINISHED
		car.controls_enabled = false
		banner_timer = 0.0
		banner_label.text = "Finished!  %s\nPress R to race again" % _fmt(race_time)
	else:
		lap += 1
		_flash("New best lap!" if new_best else "Lap %d" % lap)


func _flash(text: String) -> void:
	banner_label.text = text
	banner_timer = BANNER_SECONDS


func _update_info() -> void:
	var text := "Lap %d/%d    Time %s" % [lap, TOTAL_LAPS, _fmt(race_time)]
	text += "\nLast %s    Best %s" % [_fmt(last_lap), _fmt(best_lap)]
	if car.on_grass and state == State.RACING:
		text += "\nOff track!"
	info_label.text = text


func _fmt(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60.0]


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	info_label = Label.new()
	info_label.position = Vector2(20, 16)
	_style_label(info_label, 24)
	hud.add_child(info_label)

	banner_label = Label.new()
	_style_label(banner_label, 64)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(banner_label)
	banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var radar := RadarScript.new()
	radar.track = track
	radar.car = car
	hud.add_child(radar)
	radar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	radar.offset_left = -240.0
	radar.offset_top = -240.0
	radar.offset_right = -20.0
	radar.offset_bottom = -20.0


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)


func _setup_input() -> void:
	var bindings := {
		"accelerate": [KEY_UP, KEY_W],
		"brake": [KEY_DOWN, KEY_S],
		"steer_left": [KEY_LEFT, KEY_A],
		"steer_right": [KEY_RIGHT, KEY_D],
		"restart": [KEY_R],
	}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_lap = float(cfg.get_value("times", "best_lap", -1.0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("times", "best_lap", best_lap)
	cfg.save(SAVE_PATH)
