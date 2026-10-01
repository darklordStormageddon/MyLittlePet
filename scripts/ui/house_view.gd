extends Control
## 펫집 화면. 공간(방/2층/정원/지하실/펫 타운), 가구, 펫을 보여준다.

signal pet_clicked(uid: int)

const FurnitureNode := preload("res://scripts/ui/furniture_node.gd")
const PetNode := preload("res://scripts/ui/pet_node.gd")

var edit_mode := false:
	set(v):
		edit_mode = v
		for n in _furniture_layer.get_children():
			n.queue_redraw()

var _furniture_layer := Control.new()
var _pet_layer := Control.new()
var _furniture_nodes := {} # uid -> node
var _pet_nodes := {} # uid -> node
var _redraw_timer := 0.0


func _ready() -> void:
	custom_minimum_size = HouseManager.WORLD_SIZE
	size = HouseManager.WORLD_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	for layer in [_furniture_layer, _pet_layer]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.size = HouseManager.WORLD_SIZE
		add_child(layer)
	EventBus.pets_changed.connect(_sync_pets)
	EventBus.furniture_changed.connect(_sync_furniture)
	EventBus.house_level_changed.connect(func(_l): queue_redraw())
	EventBus.game_loaded.connect(_sync_all)
	_sync_all()


func _process(delta: float) -> void:
	_redraw_timer += delta
	if _redraw_timer > 5.0:
		_redraw_timer = 0.0
		queue_redraw() # 낮/밤 변화 반영
		for n in _furniture_layer.get_children():
			n.queue_redraw()


func _sync_all() -> void:
	_sync_furniture()
	_sync_pets()
	queue_redraw()


func _sync_furniture() -> void:
	var alive := {}
	for f in HouseManager.placed:
		var uid := int(f["uid"])
		alive[uid] = true
		if not _furniture_nodes.has(uid):
			var n := FurnitureNode.new()
			_furniture_layer.add_child(n)
			n.setup(f, self)
			_furniture_nodes[uid] = n
		else:
			_furniture_nodes[uid].sync_position()
	for uid in _furniture_nodes.keys():
		if not alive.has(uid):
			_furniture_nodes[uid].queue_free()
			_furniture_nodes.erase(uid)
	# 벽에 거는 가구는 뒤쪽, 키 큰 가구가 펫을 가리지 않도록 정렬
	var nodes := _furniture_layer.get_children()
	nodes.sort_custom(func(a, b): return a.position.y + a.size.y < b.position.y + b.size.y)
	for i in nodes.size():
		_furniture_layer.move_child(nodes[i], i)


func _sync_pets() -> void:
	var alive := {}
	for pet in PetManager.pets:
		alive[pet.uid] = true
		if not _pet_nodes.has(pet.uid):
			var n := PetNode.new()
			_pet_layer.add_child(n)
			n.setup(pet, self, HouseManager.random_floor_point())
			n.clicked.connect(func(uid): pet_clicked.emit(uid))
			_pet_nodes[pet.uid] = n
		else:
			_pet_nodes[pet.uid].pet = pet
	for uid in _pet_nodes.keys():
		if not alive.has(uid):
			_pet_nodes[uid].queue_free()
			_pet_nodes.erase(uid)


func get_furniture_node(uid: int) -> Control:
	return _furniture_nodes.get(uid)


func get_pet_node(uid: int) -> Control:
	return _pet_nodes.get(uid)


func focus_point_of(uid: int) -> Vector2:
	var n: Control = _pet_nodes.get(uid)
	return n.feet if n else Vector2.ZERO


func _draw() -> void:
	var night := Clock.is_night()
	var sky := Color(0.75, 0.88, 1.0) if not night else Color(0.1, 0.12, 0.28)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	# 땅
	draw_rect(Rect2(0, 520, size.x, size.y - 520), Color(0.45, 0.35, 0.28) if not night else Color(0.25, 0.2, 0.18))
	var font := ThemeDB.fallback_font
	for stage in Balance.HOUSE_STAGES:
		var r: Rect2 = HouseManager.AREA_RECTS[stage["id"]]
		var unlocked := HouseManager.house_level >= int(stage["level"])
		if unlocked:
			var wall := _wall_color(String(stage["id"]))
			if night:
				wall = wall.darkened(0.35)
			draw_rect(r, wall)
			draw_rect(Rect2(r.position.x, r.end.y - 22, r.size.x, 22), _floor_color(String(stage["id"])).darkened(0.25 if night else 0.0))
			draw_rect(r, Color(0.45, 0.3, 0.2), false, 4.0)
			draw_string(font, r.position + Vector2(10, 22), String(stage["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.2, 0.15, 0.7) if not night else Color(1, 1, 1, 0.6))
		else:
			draw_rect(r, Color(0.3, 0.3, 0.35, 0.55))
			draw_rect(r, Color(0.2, 0.2, 0.25, 0.8), false, 2.0)
			var text := "🔒 %s - 펫집 Lv.%d 필요" % [stage["name"], stage["level"]]
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, r.get_center() - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))
	# 지붕
	if HouseManager.is_area_unlocked("floor2"):
		var top: Rect2 = HouseManager.AREA_RECTS["floor2"]
		draw_colored_polygon(PackedVector2Array([Vector2(top.position.x - 10, top.position.y + 2),
			Vector2(top.get_center().x, 4), Vector2(top.end.x + 10, top.position.y + 2)]), Color(0.75, 0.35, 0.3))
	else:
		var r1: Rect2 = HouseManager.AREA_RECTS["room1"]
		var right := HouseManager.AREA_RECTS["room2"].end.x if HouseManager.is_area_unlocked("room2") else r1.end.x
		draw_colored_polygon(PackedVector2Array([Vector2(r1.position.x - 10, r1.position.y + 2),
			Vector2((r1.position.x + right) * 0.5, r1.position.y - 90), Vector2(right + 10, r1.position.y + 2)]), Color(0.75, 0.35, 0.3))


func _wall_color(id: String) -> Color:
	match id:
		"room1": return Color(1.0, 0.94, 0.84)
		"room2": return Color(0.9, 0.95, 1.0)
		"floor2": return Color(1.0, 0.9, 0.92)
		"garden": return Color(0.7, 0.9, 0.7, 0.6)
		"basement": return Color(0.8, 0.78, 0.75)
		"town": return Color(0.95, 0.9, 0.7, 0.8)
	return Color.WHITE


func _floor_color(id: String) -> Color:
	match id:
		"garden", "town": return Color(0.45, 0.75, 0.4)
		"basement": return Color(0.55, 0.55, 0.55)
	return Color(0.8, 0.62, 0.42)
