extends TabBase
## 펫집 탭: 확장 단계(기획안 16), 가구 배치/보관(기획안 9).

var house_view: Control

var _level_label: Label
var _next_label: Label
var _progress := ProgressBar.new()
var _areas_label: Label
var _edit_toggle := CheckButton.new()
var _inventory := VBoxContainer.new()
var _placed := VBoxContainer.new()


func _ready() -> void:
	name = "펫집"
	add_title("우리 펫집")
	_level_label = add_text("")
	_next_label = add_text("", 13)
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 10
	box.add_child(_progress)
	_areas_label = add_text("", 13)
	add_text("펫집 레벨 = 펫들의 레벨 합 (최고 기록). 펫이 자랄수록 집도 넓어져요.", 12)

	box.add_child(HSeparator.new())
	add_title("가구 배치")
	_edit_toggle.text = "배치 모드 (드래그로 이동, 우클릭으로 보관)"
	_edit_toggle.toggled.connect(func(on): if house_view: house_view.edit_mode = on)
	box.add_child(_edit_toggle)
	add_text("보관함", 14)
	box.add_child(_inventory)
	add_text("배치된 가구", 14)
	box.add_child(_placed)

	EventBus.furniture_changed.connect(_rebuild)
	EventBus.game_loaded.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	clear(_inventory)
	clear(_placed)
	if HouseManager.inventory.is_empty():
		_inventory.add_child(make_label("(비어 있음)", 12))
	for id in HouseManager.inventory:
		var row := HBoxContainer.new()
		var l := make_label("%s × %d" % [FurnitureDB.display_name(id), HouseManager.inventory[id]], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(make_button("배치", func(): HouseManager.place_from_inventory(id)))
		_inventory.add_child(row)
	for f in HouseManager.placed:
		var row := HBoxContainer.new()
		var id := String(f["id"])
		var acts := ActivityDB.names_for_furniture(id)
		var l := make_label("%s%s" % [FurnitureDB.display_name(id), (" — " + acts[0]) if not acts.is_empty() else ""], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var uid := int(f["uid"])
		row.add_child(make_button("보관", func(): HouseManager.store(uid)))
		_placed.add_child(row)
	refresh()


func refresh() -> void:
	_level_label.text = "펫집 Lv.%d · %s · 펫 수용 %d / %d" % [HouseManager.house_level, HouseManager.stage_name(),
		PetManager.pets.size(), HouseManager.pet_capacity()]
	var next := HouseManager.next_stage()
	if next.is_empty():
		_next_label.text = "최종 단계에 도달했어요!"
		_progress.value = 100
	else:
		var cur := int(Balance.HOUSE_STAGES[HouseManager.stage_index()]["level"])
		_next_label.text = "다음 확장: %s (펫 레벨 합 %d / %d)" % [next["name"], PetManager.total_levels(), next["level"]]
		_progress.min_value = cur
		_progress.max_value = int(next["level"])
		_progress.value = clampi(HouseManager.house_level, cur, int(next["level"]))
	var parts: Array = []
	for s in Balance.HOUSE_STAGES:
		parts.append(("✔ " if HouseManager.house_level >= int(s["level"]) else "🔒 ") + "%s(Lv.%d)" % [s["name"], s["level"]])
	_areas_label.text = "  ".join(parts)
