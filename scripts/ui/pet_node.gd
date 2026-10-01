extends Control
## 펫집 안에서 실제로 생활하는 펫 (기획안 7, 8).
## PetManager 가 고른 행동(activity)에 맞춰 가구로 걸어가고 애니메이션한다.

signal clicked(uid: int)

const BASE_RADIUS := 24.0
const WALK_SPEED := 80.0
const NODE_SIZE := Vector2(80, 80)

var pet: PetData
var house_view: Control
var feet := Vector2.ZERO
var facing := 1.0

var _target := Vector2.ZERO
var _last_activity := ""
var _last_target := -2
var _time := 0.0
var _hearts: Array = [] # [pos, age]


func setup(p: PetData, view: Control, start: Vector2) -> void:
	pet = p
	house_view = view
	feet = start
	_target = start
	size = NODE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_position()


func _process(delta: float) -> void:
	if pet == null:
		return
	_time += delta
	if pet.activity != _last_activity or pet.activity_target != _last_target:
		_last_activity = pet.activity
		_last_target = pet.activity_target
		_retarget()
	if pet.activity == "play_pet":
		var other: Control = house_view.get_pet_node(pet.activity_target)
		if other:
			_target = other.feet + Vector2(34 * (1.0 if feet.x >= other.feet.x else -1.0), 0)
	_move(delta)
	if is_at_target() and pet.activity == "heart" and fmod(_time, 0.6) < delta:
		_hearts.append([feet + Vector2(randf_range(-10, 10), -50), 0.0])
	for h in _hearts:
		h[1] += delta
	_hearts = _hearts.filter(func(h): return h[1] < 1.5)
	queue_redraw()


func is_at_target() -> bool:
	return feet.distance_to(_target) < 2.0


func _retarget() -> void:
	match pet.activity:
		"wander":
			_target = HouseManager.random_floor_point()
		"cheer":
			var r: Rect2 = HouseManager.AREA_RECTS["room1"]
			_target = Vector2(r.get_center().x + randf_range(-60, 60), r.end.y - HouseManager.FLOOR_MARGIN)
		"play_pet":
			pass
		_:
			var f: Control = house_view.get_furniture_node(pet.activity_target)
			if f and String(ActivityDB.get_def(pet.activity)["furniture"]) != "":
				# 같은 가구를 여러 펫이 쓰면 조금씩 비켜 선다
				_target = f.use_point(pet.activity) + Vector2(float(pet.uid % 3 - 1) * 16.0, 0)
			else:
				_target = feet


func _move(delta: float) -> void:
	if is_at_target():
		feet = _target
		return
	# 다른 층으로 갈 때는 먼저 세로로(계단/사다리), 그다음 가로로 이동
	var step := WALK_SPEED * delta
	var diff := _target - feet
	if absf(diff.y) > 2.0 and not pet.activity in ["climb", "sleep", "nap", "swim"]:
		feet.y = move_toward(feet.y, _target.y, step * 1.5)
	elif absf(diff.y) > 2.0:
		feet = feet.move_toward(_target, step)
	else:
		feet.x = move_toward(feet.x, _target.x, step)
	if absf(diff.x) > 1.0:
		facing = signf(diff.x)
	_update_position()


func _update_position() -> void:
	position = feet - Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(pet.uid)
		accept_event()


func _draw() -> void:
	var base := Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y)
	var moving := not is_at_target()
	var anim := String(ActivityDB.get_def(pet.activity)["anim"])
	var offset := Vector2.ZERO
	var rot := 0.0
	var opts := {"stage": pet.growth_stage(), "facing": facing, "time": _time, "glasses": pet.has_study_glasses()}
	if moving:
		offset.y = -absf(sin(_time * 10.0)) * 4.0
	else:
		match anim:
			"sleep":
				opts["closed"] = true
				offset.y = sin(_time * 2.0) * 1.0
			"jump":
				offset.y = -absf(sin(_time * 6.0)) * 10.0
			"dance":
				rot = sin(_time * 8.0) * 0.25
				offset.y = -absf(sin(_time * 8.0)) * 5.0
			"look":
				opts["look_dir"] = Vector2(0, 0.5)
			"look_away":
				opts["look_dir"] = Vector2(0, -1)
			"eat":
				offset.y = absf(sin(_time * 7.0)) * 3.0
				opts["look_dir"] = Vector2(0, 1)
			"read":
				opts["look_dir"] = Vector2(facing, 0.6)
			"idle":
				offset.y = sin(_time * 1.5) * 1.0
	opts["rot"] = rot
	# 그림자
	draw_set_transform(base + Vector2(0, -2), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, BASE_RADIUS * 0.8, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	PetArt.draw_pet(self, base + offset, BASE_RADIUS, pet.species, opts)

	var font := ThemeDB.fallback_font
	var top := base.y - BASE_RADIUS * 2.3
	if not moving and anim == "sleep":
		for i in 3:
			var ph := fmod(_time * 0.6 + i * 0.33, 1.0)
			draw_string(font, base + Vector2(16 + ph * 14, -BASE_RADIUS * 1.5 - ph * 22), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11 + i * 2, Color(0.3, 0.3, 0.6, 1.0 - ph))
	if not moving and anim == "read":
		draw_rect(Rect2(base + Vector2(-10 + facing * 14, -18), Vector2(20, 14)), Color(0.95, 0.95, 0.9))
		draw_line(base + Vector2(facing * 14, -18), base + Vector2(facing * 14, -4), Color(0.5, 0.4, 0.3), 1.5)
	if pet.activity == "beg" and not moving:
		draw_string(font, base + Vector2(14, -BASE_RADIUS * 1.8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.3, 0.3))
	for h in _hearts:
		var age: float = h[1]
		PetArt.draw_heart(self, (h[0] as Vector2) - position + Vector2(0, -age * 30), 5.0, Color(1, 0.35, 0.5, 1.0 - age / 1.5))

	# 이름
	var name_text := "%s Lv.%d" % [pet.display_name(), pet.level]
	var nw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(base.x - nw * 0.5, base.y + 12), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.15, 0.1))

	# 말풍선
	if pet.speech != "":
		var fs := 13
		var tw := font.get_string_size(pet.speech, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := tw + 16
		var rect := Rect2(Vector2(base.x - bw * 0.5, top - 30), Vector2(bw, 24))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.95)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(0.4, 0.3, 0.25)
		sb.set_border_width_all(1)
		draw_style_box(sb, rect)
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - 5, rect.end.y - 1), Vector2(base.x + 5, rect.end.y - 1), Vector2(base.x, rect.end.y + 7)]), Color(1, 1, 1, 0.95))
		draw_string(font, rect.position + Vector2(8, 17), pet.speech, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.15, 0.1))
