extends Node2D
## Race controller: builds the track, car, camera and HUD, then runs a
## countdown and a 3-lap time trial with F1-style sector timing.
##
## Sector colors follow F1 conventions: purple beats your all-time best
## for that sector, green beats your best earlier in this race, yellow
## is slower than both.

const TrackScript := preload("res://scripts/track.gd")
const CarScript := preload("res://scripts/car.gd")
const RadarScript := preload("res://scripts/radar.gd")

const TOTAL_LAPS := 3
const SECTORS := TrackScript.SECTOR_COUNT
const SAVE_PATH := "user://best_lap.cfg"
const BANNER_SECONDS := 1.2
const SECTOR_FLASH_SECONDS := 2.5

const PURPLE := Color(0.78, 0.4, 1.0)
const GREEN := Color(0.25, 0.95, 0.35)
const YELLOW := Color(1.0, 0.85, 0.1)
const RUNNING := Color.WHITE
const DIM := Color(1, 1, 1, 0.35)

enum State { COUNTDOWN, RACING, FINISHED }

var track: TrackScript
var car: CarScript
var camera: Camera2D
var info_label: Label
var banner_label: Label
var sector_flash_label: Label
var sector_rows: Array[Array] = []  # per sector: [name Label, time Label, delta Label]

var state := State.COUNTDOWN
var countdown := 3.0
var race_time := 0.0
var lap := 1
var lap_start := 0.0
var last_lap := -1.0
var last_lap_delta := NAN
var best_lap := -1.0
var banner_timer := 0.0
var sector_flash_timer := 0.0

var sector := 0                 # sector the car is currently in
var sector_start_time := 0.0
var current_sectors: Array[float] = []   # this lap; -1 = not done yet
var current_colors: Array[Color] = []
var current_deltas: Array[float] = []
var last_sectors: Array[float] = []      # previous lap, shown dimmed
var race_best_sectors: Array[float] = [] # best in this race
var best_sectors: Array[float] = []      # all-time, saved


func _ready() -> void:
	_setup_input()
	for k in SECTORS:
		current_sectors.append(-1.0)
		current_colors.append(RUNNING)
		current_deltas.append(NAN)
		last_sectors.append(-1.0)
		race_best_sectors.append(-1.0)
		best_sectors.append(-1.0)
	_load_best()

	track = TrackScript.new()
	add_child(track)

	var n := track.points.size()
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
	if sector_flash_timer > 0.0:
		sector_flash_timer -= delta
		if sector_flash_timer <= 0.0:
			sector_flash_label.text = ""

	_update_info()
	_update_sector_rows()


## The sector lines double as lap checkpoints: they must be crossed in order.
func _update_progress(index: int) -> void:
	var window := int(track.points.size() * 0.125)
	var next := sector + 1
	var line := track.sector_start(next) if next < SECTORS else 0
	if index >= line and index < line + window:
		_complete_sector()


func _complete_sector() -> void:
	var t := race_time - sector_start_time
	sector_start_time = race_time

	var all_time := best_sectors[sector]
	var race_best := race_best_sectors[sector]
	var color := YELLOW
	if all_time < 0.0 or t < all_time:
		color = PURPLE
		best_sectors[sector] = t
	elif race_best < 0.0 or t < race_best:
		color = GREEN
	if race_best < 0.0 or t < race_best:
		race_best_sectors[sector] = t

	var delta := t - all_time if all_time >= 0.0 else NAN
	current_sectors[sector] = t
	current_colors[sector] = color
	current_deltas[sector] = delta

	var text := "S%d  %s" % [sector + 1, _fmt_sector(t)]
	if not is_nan(delta):
		text += "   %s" % _fmt_delta(delta)
	sector_flash_label.text = text
	sector_flash_label.add_theme_color_override("font_color", color)
	sector_flash_timer = SECTOR_FLASH_SECONDS

	if sector == SECTORS - 1:
		_complete_lap()
	else:
		sector += 1


func _complete_lap() -> void:
	var lap_time := race_time - lap_start
	last_lap_delta = lap_time - best_lap if best_lap >= 0.0 else NAN
	last_lap = lap_time
	lap_start = race_time

	var new_best := best_lap < 0.0 or lap_time < best_lap
	if new_best:
		best_lap = lap_time
	_save_best()

	last_sectors.assign(current_sectors)
	sector = 0
	for k in SECTORS:
		current_sectors[k] = -1.0
		current_deltas[k] = NAN

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
	text += "\nLast %s" % _fmt(last_lap)
	if not is_nan(last_lap_delta):
		text += " (%s)" % _fmt_delta(last_lap_delta)
	text += "    Best %s" % _fmt(best_lap)
	if car.on_grass and state == State.RACING:
		text += "\nOff track!"
	info_label.text = text


func _update_sector_rows() -> void:
	for k in SECTORS:
		var time_label: Label = sector_rows[k][1]
		var delta_label: Label = sector_rows[k][2]
		var color := DIM
		var time_text := "--.---"
		var delta_text := ""
		if current_sectors[k] >= 0.0:
			color = current_colors[k]
			time_text = _fmt_sector(current_sectors[k])
			if not is_nan(current_deltas[k]):
				delta_text = _fmt_delta(current_deltas[k])
		elif k == sector and state == State.RACING:
			color = RUNNING
			time_text = _fmt_sector(race_time - sector_start_time)
		elif last_sectors[k] >= 0.0:
			time_text = _fmt_sector(last_sectors[k])
		time_label.text = time_text
		time_label.add_theme_color_override("font_color", color)
		delta_label.text = delta_text
		delta_label.add_theme_color_override("font_color", color)


func _fmt(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60.0]


func _fmt_sector(seconds: float) -> String:
	if seconds >= 60.0:
		var minutes := int(seconds / 60.0)
		return "%d:%06.3f" % [minutes, seconds - minutes * 60.0]
	return "%.3f" % seconds


func _fmt_delta(seconds: float) -> String:
	return "%+.3f" % seconds


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

	# Flash of the sector just completed, top center.
	sector_flash_label = Label.new()
	_style_label(sector_flash_label, 34)
	sector_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(sector_flash_label)
	sector_flash_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sector_flash_label.offset_top = 90.0

	# Sector table, top right: name, time, delta.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	hud.add_child(grid)
	for k in SECTORS:
		var row: Array = []
		for col in 3:
			var label := Label.new()
			_style_label(label, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.custom_minimum_size.x = [36.0, 90.0, 90.0][col]
			grid.add_child(label)
			row.append(label)
		(row[0] as Label).text = "S%d" % (k + 1)
		sector_rows.append(row)
	# Anchor once the rows exist, so the grid knows its size.
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)

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
	if cfg.load(SAVE_PATH) != OK:
		return
	best_lap = float(cfg.get_value("times", "best_lap", -1.0))
	for k in SECTORS:
		best_sectors[k] = float(cfg.get_value("times", "best_s%d" % (k + 1), -1.0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("times", "best_lap", best_lap)
	for k in SECTORS:
		cfg.set_value("times", "best_s%d" % (k + 1), best_sectors[k])
	cfg.save(SAVE_PATH)
