extends TabBase
## 상점 탭: 펫 입양(기획안 10)과 가구 구매(기획안 9).

var _pet_list := VBoxContainer.new()
var _furniture_list := VBoxContainer.new()
var _pet_buttons := {} # species -> Button
var _furniture_buttons := {} # id -> [Button, Label]


func _ready() -> void:
	name = "상점"
	add_title("펫 입양")
	add_text("펫마다 생산량 / 성장 속도 / 애정도 상승 특성이 달라요. 도감에서 발견한 펫도 입양할 수 있어요.", 12)
	box.add_child(_pet_list)
	box.add_child(HSeparator.new())
	add_title("가구")
	add_text("가구는 능력치가 아니라 펫의 새로운 행동을 만들어요.", 12)
	box.add_child(_furniture_list)
	EventBus.species_discovered.connect(func(_a, _b): _rebuild_pets())
	EventBus.game_loaded.connect(_rebuild_all)
	EventBus.house_level_changed.connect(func(_l): _rebuild_furniture())
	_rebuild_all()


func _rebuild_all() -> void:
	_rebuild_pets()
	_rebuild_furniture()


func _rebuild_pets() -> void:
	clear(_pet_list)
	_pet_buttons.clear()
	for id in PetDB.ORDER:
		if not PetManager.can_buy_species(id):
			continue
		var s := PetDB.get_species(id)
		var card := make_card()
		var v: VBoxContainer = card[1]
		v.add_child(make_label("%s — %s" % [s["name"], s["desc"]], 14, Color(1, 0.9, 0.7)))
		v.add_child(make_label("생산량 %s  성장 속도 %s  애정도 상승 %s" % [PetDB.stars_text(int(s["prod"])),
			PetDB.stars_text(int(s["growth"])), PetDB.stars_text(int(s["affection"]))], 12))
		var b := make_button("", func(): PetManager.buy_pet(id))
		v.add_child(b)
		_pet_buttons[id] = b
		_pet_list.add_child(card[0])
	refresh()


func _rebuild_furniture() -> void:
	clear(_furniture_list)
	_furniture_buttons.clear()
	for id in FurnitureDB.ORDER:
		if id == "food_bowl":
			continue
		var def := FurnitureDB.get_def(id)
		var row := HBoxContainer.new()
		var info := make_label("%s — %s" % [def["name"], def["desc"]], 13)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var b := make_button("", func(): HouseManager.buy_furniture(id))
		b.custom_minimum_size.x = 130
		row.add_child(b)
		_furniture_list.add_child(row)
		_furniture_buttons[id] = b
	refresh()


func refresh() -> void:
	var full := PetManager.is_full()
	for id in _pet_buttons:
		var price := PetManager.pet_price(id)
		var b: Button = _pet_buttons[id]
		b.text = "펫집이 가득 찼어요" if full else "입양하기 (%s G)" % Balance.format_number(price)
		b.disabled = full or not Economy.can_afford(price)
	for id in _furniture_buttons:
		var b: Button = _furniture_buttons[id]
		var def := FurnitureDB.get_def(id)
		if not HouseManager.is_furniture_unlocked(id):
			b.text = "🔒 펫집 Lv.%d" % int(def["house_level"])
			b.disabled = true
		else:
			var owned := HouseManager.owned_count(id)
			b.text = "%s G%s" % [Balance.format_number(HouseManager.furniture_price(id)), " (보유 %d)" % owned if owned > 0 else ""]
			b.disabled = not Economy.can_afford(HouseManager.furniture_price(id))
