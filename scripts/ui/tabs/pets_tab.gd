extends TabBase
## 펫 목록 탭: 상태 확인, 먹이 주기, 쓰다듬기.

signal observe_requested(uid: int)

var _header: Label
var _list := VBoxContainer.new()
var _rows := {} # uid -> {"status": Label, "now": Label, "feed": Button, "treat": Button}


func _ready() -> void:
	name = "펫"
	_header = add_title("")
	add_text("펫을 누르면 지금 무엇을 하는지 관찰할 수 있어요.", 12)
	box.add_child(_list)
	EventBus.pets_changed.connect(_rebuild)
	EventBus.game_loaded.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	clear(_list)
	_rows.clear()
	for pet in PetManager.pets:
		var card := make_card()
		var v: VBoxContainer = card[1]
		var title := make_label("", 15, Color(1, 0.9, 0.7))
		v.add_child(title)
		var status := make_label("", 13)
		v.add_child(status)
		var now_label := make_label("", 12, Color(0.75, 0.85, 1.0))
		v.add_child(now_label)
		var row := HBoxContainer.new()
		row.add_child(make_button("관찰", func(): observe_requested.emit(pet.uid)))
		row.add_child(make_button("쓰다듬기", func(): PetManager.pet_pet(pet.uid)))
		var feed := make_button("", func(): PetManager.feed(pet.uid, "kibble"))
		var treat := make_button("", func(): PetManager.feed(pet.uid, "treat"))
		row.add_child(feed)
		row.add_child(treat)
		v.add_child(row)
		_list.add_child(card[0])
		_rows[pet.uid] = {"title": title, "status": status, "now": now_label, "feed": feed, "treat": treat}
	refresh()


func refresh() -> void:
	_header.text = "우리 펫 (%d / %d)" % [PetManager.pets.size(), HouseManager.pet_capacity()]
	var mult := PetManager.current_prod_mult()
	var kibble := PetManager.food_price("kibble")
	var treat := PetManager.food_price("treat")
	for pet in PetManager.pets:
		if not _rows.has(pet.uid):
			continue
		var r: Dictionary = _rows[pet.uid]
		(r["title"] as Label).text = "%s (%s) Lv.%d · %s" % [pet.display_name(), PetDB.display_name(pet.species),
			pet.level, pet.growth_stage_name()]
		(r["status"] as Label).text = "기분: %s · 배고픔 %d%% · 애정도 %d%% (%s)\n생산 %s / 분 · 경험치 %d%%" % [
			pet.mood_label(), int(pet.hunger), int(pet.affection), pet.affection_title(),
			Balance.format_number(pet.production_per_min(mult)), int(100.0 * pet.exp / maxf(1.0, pet.exp_to_next()))]
		(r["now"] as Label).text = "지금: " + PetManager.activity_text(pet)
		(r["feed"] as Button).text = "사료 %sG" % Balance.format_number(kibble)
		(r["feed"] as Button).disabled = not Economy.can_afford(kibble)
		(r["treat"] as Button).text = "간식 %sG" % Balance.format_number(treat)
		(r["treat"] as Button).disabled = not Economy.can_afford(treat)
