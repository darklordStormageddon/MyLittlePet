extends Control
## 펫집에 배치된 가구 하나. 배치 모드에서는 드래그로 이동, 우클릭으로 보관한다.

var furniture_uid: int = -1
var furniture_id: String = ""
var house_view: Control

var _dragging := false
var _drag_offset := Vector2.ZERO


func setup(entry: Dictionary, view: Control) -> void:
	furniture_uid = int(entry["uid"])
	furniture_id = String(entry["id"])
	house_view = view
	var def := FurnitureDB.get_def(furniture_id)
	size = def["size"]
	custom_minimum_size = size
	tooltip_text = "%s\n%s" % [def["name"], def["desc"]]
	mouse_filter = Control.MOUSE_FILTER_STOP
	sync_position()


func sync_position() -> void:
	var f := HouseManager.get_placed(furniture_uid)
	if f.is_empty():
		return
	var p: Vector2 = f["pos"]
	position = p - Vector2(size.x * 0.5, size.y)


## 펫이 이 가구를 사용할 때 서 있을 위치 (house 좌표)
func use_point(activity: String) -> Vector2:
	var f := HouseManager.get_placed(furniture_uid)
	var p: Vector2 = f.get("pos", position + Vector2(size.x * 0.5, size.y))
	match activity:
		"climb":
			return p + Vector2(0, -size.y + 8)
		"sleep", "nap":
			return p + Vector2(0, -size.y * 0.45)
		"swim":
			return p + Vector2(randf_range(-size.x * 0.3, size.x * 0.3), -4)
		"look_window", "stargaze":
			var floor_y := HouseManager.area_of(p).end.y - HouseManager.FLOOR_MARGIN
			return Vector2(p.x, floor_y)
		"read", "study", "play_piano":
			return p + Vector2(size.x * 0.5 + 18, 0)
		"eat", "beg":
			return p + Vector2(28, 0)
		"play_ball":
			return p + Vector2(-26, 0)
	return p + Vector2(0, 0)


func _gui_input(event: InputEvent) -> void:
	if not house_view.edit_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_drag_offset = mb.position
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			HouseManager.store(furniture_uid)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var local := position + (event as InputEventMouseMotion).position - _drag_offset
		HouseManager.move_furniture(furniture_uid, local + Vector2(size.x * 0.5, size.y))
		sync_position()
		accept_event()


func _draw() -> void:
	var def := FurnitureDB.get_def(furniture_id)
	var c: Color = def["color"]
	var w := size.x
	var h := size.y
	var dark := c.darkened(0.3)
	match furniture_id:
		"food_bowl":
			draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(w, 4), Vector2(w - 6, h), Vector2(6, h)]), c)
			draw_rect(Rect2(3, 0, w - 6, 6), Color(0.75, 0.55, 0.3))
		"bed":
			draw_rect(Rect2(0, h * 0.35, w, h * 0.65), dark)
			draw_rect(Rect2(4, h * 0.2, w - 8, h * 0.45), c)
			draw_rect(Rect2(6, h * 0.1, w * 0.3, h * 0.3), Color.WHITE)
			draw_rect(Rect2(0, 0, 6, h), dark.darkened(0.2))
		"ball":
			draw_circle(Vector2(w, h) * 0.5, w * 0.5, c)
			draw_arc(Vector2(w, h) * 0.5, w * 0.32, 0.3, 2.6, 8, Color.WHITE, 2.0)
		"cushion":
			draw_rect(Rect2(0, h * 0.2, w, h * 0.8), c)
			draw_circle(Vector2(w * 0.5, h * 0.6), 3, dark)
		"window":
			var sky := Color(0.55, 0.78, 1.0) if not Clock.is_night() else Color(0.12, 0.15, 0.35)
			draw_rect(Rect2(0, 0, w, h), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(4, 4, w - 8, h - 8), sky)
			if Clock.is_night():
				draw_circle(Vector2(w * 0.7, h * 0.3), 6, Color(1, 1, 0.8))
			else:
				draw_circle(Vector2(w * 0.25, h * 0.3), 7, Color(1, 0.95, 0.6))
			draw_line(Vector2(w * 0.5, 4), Vector2(w * 0.5, h - 4), Color(0.95, 0.95, 0.95), 3)
			draw_line(Vector2(4, h * 0.5), Vector2(w - 4, h * 0.5), Color(0.95, 0.95, 0.95), 3)
		"plant":
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.15, h * 0.6), Vector2(w * 0.85, h * 0.6), Vector2(w * 0.75, h), Vector2(w * 0.25, h)]), Color(0.75, 0.45, 0.3))
			for i in 4:
				var a := -PI * 0.5 + (i - 1.5) * 0.45
				var tip := Vector2(w * 0.5, h * 0.6) + Vector2(cos(a), sin(a)) * h * 0.55
				draw_line(Vector2(w * 0.5, h * 0.6), tip, c, 7)
		"bookshelf":
			draw_rect(Rect2(0, 0, w, h), c)
			for row in 3:
				var y := 6 + row * (h - 8) / 3.0
				draw_rect(Rect2(4, y, w - 8, (h - 8) / 3.0 - 6), c.darkened(0.4))
				for b in 5:
					var bc := Color.from_hsv(fmod(0.13 * (b + row * 3), 1.0), 0.5, 0.85)
					draw_rect(Rect2(6 + b * (w - 12) / 5.0, y + 3, (w - 12) / 5.0 - 2, (h - 8) / 3.0 - 9), bc)
		"desk":
			draw_rect(Rect2(0, 0, w, 8), c)
			draw_rect(Rect2(4, 8, 6, h - 8), dark)
			draw_rect(Rect2(w - 10, 8, 6, h - 8), dark)
			draw_rect(Rect2(w * 0.3, -10, 22, 10), Color(0.95, 0.95, 0.9))
			draw_rect(Rect2(w * 0.65, -16, 4, 16), Color(0.3, 0.3, 0.3))
			draw_circle(Vector2(w * 0.65 + 2, -16), 6, Color(1, 0.9, 0.5) if FocusManager.active else Color(0.6, 0.6, 0.6))
		"cat_tower":
			draw_rect(Rect2(w * 0.42, 0, w * 0.16, h), Color(0.85, 0.8, 0.65))
			for y in [0.0, h * 0.4, h * 0.8]:
				draw_rect(Rect2(0, y, w, 10), c.darkened(0.15))
		"piano":
			draw_rect(Rect2(0, 0, w, h * 0.75), c)
			draw_rect(Rect2(4, h * 0.45, w - 8, h * 0.15), Color.WHITE)
			for k in 8:
				draw_rect(Rect2(8 + k * (w - 16) / 8.0, h * 0.45, 3, h * 0.09), Color.BLACK)
			draw_rect(Rect2(6, h * 0.75, 6, h * 0.25), c)
			draw_rect(Rect2(w - 12, h * 0.75, 6, h * 0.25), c)
		"telescope":
			draw_line(Vector2(w * 0.5, h * 0.5), Vector2(w * 0.15, h), dark, 3)
			draw_line(Vector2(w * 0.5, h * 0.5), Vector2(w * 0.85, h), dark, 3)
			draw_line(Vector2(w * 0.2, h * 0.65), Vector2(w * 0.95, h * 0.1), c, 10)
		"pool":
			draw_rect(Rect2(0, 0, w, h), Color(0.9, 0.9, 0.95))
			draw_rect(Rect2(4, 4, w - 8, h - 8), c)
			for i in 3:
				draw_arc(Vector2(w * (0.25 + 0.25 * i), h * 0.5), 6, PI, TAU, 6, Color(1, 1, 1, 0.7), 1.5)
		_:
			draw_rect(Rect2(Vector2.ZERO, size), c)
	if house_view and house_view.edit_mode:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.8, 0.2), false, 2.0)
