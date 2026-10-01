extends Node
## 펫집 시스템 (기획안 9, 16).
## - 펫집 레벨 = 지금까지 달성한 '모든 펫 레벨 합'의 최댓값 (합성으로 펫이 줄어도 집은 줄지 않는다)
## - 레벨에 따라 방 하나 → 방 두 개 → 2층 → 정원 → 지하실 → 펫 타운으로 확장
## - 가구를 구매/배치하면 펫의 행동이 추가된다

## 펫집 월드 좌표에서 각 공간의 영역 (Balance.HOUSE_STAGES 와 같은 순서)
const AREA_RECTS := {
	"room1": Rect2(20, 270, 520, 250),
	"room2": Rect2(540, 270, 420, 250),
	"floor2": Rect2(20, 30, 940, 240),
	"garden": Rect2(960, 150, 520, 370),
	"basement": Rect2(20, 520, 940, 180),
	"town": Rect2(1480, 30, 760, 670),
}
const WORLD_SIZE := Vector2(2260, 720)
const FLOOR_MARGIN := 14.0

var house_level: int = 1
var placed: Array = [] ## [{"uid": int, "id": String, "pos": Vector2}]
var inventory: Dictionary = {} ## 보관 중인 가구 id -> 개수
var next_uid: int = 1


func reset() -> void:
	house_level = 1
	placed = []
	inventory = {}
	next_uid = 1
	_place_new("food_bowl", Vector2(120, AREA_RECTS["room1"].end.y - FLOOR_MARGIN))


# --- 공간 ---

func stage_index() -> int:
	return Balance.house_stage_index(house_level)


func stage_name() -> String:
	return String(Balance.HOUSE_STAGES[stage_index()]["name"])


func next_stage() -> Dictionary:
	var idx := stage_index() + 1
	return Balance.HOUSE_STAGES[idx] if idx < Balance.HOUSE_STAGES.size() else {}


func pet_capacity() -> int:
	return Balance.pet_capacity(house_level)


func is_area_unlocked(area_id: String) -> bool:
	for stage in Balance.HOUSE_STAGES:
		if stage["id"] == area_id:
			return house_level >= int(stage["level"])
	return false


func unlocked_area_rects() -> Array:
	var out: Array = []
	for stage in Balance.HOUSE_STAGES:
		if house_level >= int(stage["level"]):
			out.append(AREA_RECTS[stage["id"]])
	return out


## 펫이 걸어다닐 수 있는 바닥 위의 임의 지점
func random_floor_point() -> Vector2:
	var rects := unlocked_area_rects()
	var r: Rect2 = rects[randi() % rects.size()]
	return Vector2(randf_range(r.position.x + 30.0, r.end.x - 30.0),
		r.end.y - FLOOR_MARGIN - randf_range(0.0, 30.0))


func area_of(pos: Vector2) -> Rect2:
	for r in unlocked_area_rects():
		if r.has_point(pos):
			return r
	return unlocked_area_rects()[0]


func clamp_to_unlocked(pos: Vector2) -> Vector2:
	var best := pos
	var best_d := INF
	for r in unlocked_area_rects():
		var c := Vector2(clampf(pos.x, r.position.x + 20.0, r.end.x - 20.0),
			clampf(pos.y, r.position.y + 40.0, r.end.y - FLOOR_MARGIN))
		var d := c.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = c
	return best


## 펫 레벨 합이 늘면 집이 확장된다.
func update_level(total_pet_levels: int) -> void:
	if total_pet_levels <= house_level:
		return
	var old_stage := stage_index()
	house_level = total_pet_levels
	if stage_index() != old_stage:
		EventBus.toast.emit("🏠 펫집이 확장되었어요! [%s] 공간이 열렸어요." % stage_name())
		EventBus.house_level_changed.emit(house_level)
		Collection.check_hidden()


# --- 가구 ---

func is_furniture_unlocked(id: String) -> bool:
	return house_level >= int(FurnitureDB.get_def(id).get("house_level", 1))


func furniture_price(id: String) -> float:
	return float(FurnitureDB.get_def(id).get("price", 0.0))


func owned_count(id: String) -> int:
	var n := int(inventory.get(id, 0))
	for f in placed:
		if f["id"] == id:
			n += 1
	return n


func buy_furniture(id: String) -> bool:
	if FurnitureDB.get_def(id).is_empty() or not is_furniture_unlocked(id):
		return false
	if not Economy.spend(furniture_price(id)):
		EventBus.toast.emit("골드가 부족해요.")
		return false
	_place_new(id, _default_position(id))
	var acts := ActivityDB.names_for_furniture(id)
	EventBus.toast.emit("%s 배치 완료! %s" % [FurnitureDB.display_name(id),
		("펫이 이제 '%s' 행동을 해요." % acts[0]) if not acts.is_empty() else ""])
	Collection.check_hidden()
	return true


func _default_position(id: String) -> Vector2:
	var p := random_floor_point()
	if bool(FurnitureDB.get_def(id).get("wall", false)):
		p.y = area_of(p).position.y + 110.0
	return p


func _place_new(id: String, pos: Vector2) -> Dictionary:
	var entry := {"uid": next_uid, "id": id, "pos": pos}
	next_uid += 1
	placed.append(entry)
	EventBus.furniture_changed.emit()
	return entry


func place_from_inventory(id: String) -> bool:
	if int(inventory.get(id, 0)) <= 0:
		return false
	inventory[id] = int(inventory[id]) - 1
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	_place_new(id, _default_position(id))
	Collection.check_hidden()
	return true


func store(uid: int) -> bool:
	for i in placed.size():
		if int(placed[i]["uid"]) == uid:
			var id := String(placed[i]["id"])
			placed.remove_at(i)
			inventory[id] = int(inventory.get(id, 0)) + 1
			EventBus.furniture_changed.emit()
			return true
	return false


func move_furniture(uid: int, pos: Vector2) -> void:
	var f := get_placed(uid)
	if not f.is_empty():
		f["pos"] = clamp_to_unlocked(pos)


func get_placed(uid: int) -> Dictionary:
	for f in placed:
		if int(f["uid"]) == uid:
			return f
	return {}


func has_placed(id: String) -> bool:
	for f in placed:
		if f["id"] == id:
			return true
	return false


func placed_of(id: String) -> Array:
	var out: Array = []
	for f in placed:
		if f["id"] == id:
			out.append(f)
	return out


# --- 저장 ---

func to_dict() -> Dictionary:
	var arr: Array = []
	for f in placed:
		var p: Vector2 = f["pos"]
		arr.append({"uid": f["uid"], "id": f["id"], "x": p.x, "y": p.y})
	return {"house_level": house_level, "placed": arr, "inventory": inventory, "next_uid": next_uid}


func from_dict(d: Dictionary) -> void:
	house_level = int(d.get("house_level", 1))
	next_uid = int(d.get("next_uid", 1))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[String(k)] = int(inv[k])
	placed = []
	for f in d.get("placed", []):
		if FurnitureDB.get_def(String(f["id"])).is_empty():
			continue
		placed.append({"uid": int(f["uid"]), "id": String(f["id"]),
			"pos": Vector2(float(f["x"]), float(f["y"]))})
	EventBus.furniture_changed.emit()
