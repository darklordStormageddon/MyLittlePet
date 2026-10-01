extends PanelContainer
## 펫 관찰 팝업 (기획안 7). "우리 펫 지금 뭐 하고 있지?"

const PetPortrait := preload("res://scripts/ui/pet_portrait.gd")

var uid: int = -1

var _portrait: Control
var _name_edit := LineEdit.new()
var _info: Label
var _now: Label
var _exp_bar := ProgressBar.new()
var _feed: Button
var _treat: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(320, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.12, 0.16, 0.97)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	sb.border_color = Color(1.0, 0.8, 0.5)
	sb.set_border_width_all(2)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	add_child(v)

	var head := HBoxContainer.new()
	_portrait = PetPortrait.new()
	head.add_child(_portrait)
	var head_v := VBoxContainer.new()
	head_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "이름 짓기"
	_name_edit.max_length = 12
	_name_edit.text_submitted.connect(_on_rename)
	_name_edit.focus_exited.connect(func(): _on_rename(_name_edit.text))
	head_v.add_child(_name_edit)
	_now = TabBase.make_label("", 13, Color(0.75, 0.88, 1.0))
	head_v.add_child(_now)
	head.add_child(head_v)
	v.add_child(head)

	_info = TabBase.make_label("", 14)
	v.add_child(_info)
	_exp_bar.custom_minimum_size.y = 12
	_exp_bar.show_percentage = false
	v.add_child(_exp_bar)

	var row := HBoxContainer.new()
	row.add_child(TabBase.make_button("쓰다듬기", func(): PetManager.pet_pet(uid)))
	_feed = TabBase.make_button("", func(): PetManager.feed(uid, "kibble"))
	_treat = TabBase.make_button("", func(): PetManager.feed(uid, "treat"))
	row.add_child(_feed)
	row.add_child(_treat)
	row.add_child(TabBase.make_button("닫기", func(): visible = false))
	v.add_child(row)
	EventBus.pets_changed.connect(func(): if PetManager.get_pet(uid) == null: visible = false)


func open(pet_uid: int) -> void:
	uid = pet_uid
	var pet := PetManager.get_pet(uid)
	if pet == null:
		return
	_name_edit.text = pet.nickname
	_name_edit.placeholder_text = PetDB.display_name(pet.species)
	visible = true
	refresh()


func _on_rename(text: String) -> void:
	var pet := PetManager.get_pet(uid)
	if pet:
		pet.nickname = text.strip_edges()


func _process(_delta: float) -> void:
	if visible:
		refresh()


func refresh() -> void:
	var pet := PetManager.get_pet(uid)
	if pet == null:
		visible = false
		return
	_portrait.species = pet.species
	_portrait.stage = pet.growth_stage()
	_portrait.glasses = pet.has_study_glasses()
	_portrait.queue_redraw()
	_now.text = "%s · %s\n지금: %s" % [PetDB.display_name(pet.species), pet.growth_stage_name(), PetManager.activity_text(pet)]
	_info.text = "현재 상태: %s\n배고픔: %d%%\n애정도: %d%% (%s)\nLv.%d\n현재 생산량: %s / 분\n누적 생산: %s G\n함께 집중한 시간: %s%s" % [
		pet.mood_label(), int(pet.hunger), int(pet.affection), pet.affection_title(), pet.level,
		Balance.format_number(pet.production_per_min(PetManager.current_prod_mult())),
		Balance.format_number(pet.total_produced), Balance.format_minutes_korean(pet.focus_minutes_together),
		"  👓" if pet.has_study_glasses() else ""]
	_exp_bar.max_value = pet.exp_to_next()
	_exp_bar.value = pet.exp
	var kibble := PetManager.food_price("kibble")
	var treat := PetManager.food_price("treat")
	_feed.text = "사료 %sG" % Balance.format_number(kibble)
	_feed.disabled = not Economy.can_afford(kibble)
	_treat.text = "간식 %sG" % Balance.format_number(treat)
	_treat.disabled = not Economy.can_afford(treat)
