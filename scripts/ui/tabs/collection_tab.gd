extends TabBase
## 도감 탭 (기획안 12). 존재한다는 사실만 보여주고, 획득 조건은 공개하지 않는다.

const PetPortrait := preload("res://scripts/ui/pet_portrait.gd")

var _count_label: Label
var _grid := GridContainer.new()


func _ready() -> void:
	name = "도감"
	_count_label = add_title("")
	add_text("??? 펫의 획득 조건은 비밀이에요. 키우고, 꾸미고, 함께 집중하다 보면 만나게 될지도?", 12)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	EventBus.species_discovered.connect(func(_a, _b): _rebuild())
	EventBus.game_loaded.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	clear(_grid)
	_count_label.text = "발견한 펫: %d / %d" % [Collection.discovered_count(), Collection.total_count()]
	for id in PetDB.ORDER:
		var found := Collection.is_discovered(id)
		var card := make_card()
		var v: VBoxContainer = card[1]
		(card[0] as Control).custom_minimum_size = Vector2(118, 0)
		var portrait := PetPortrait.new()
		portrait.species = id
		portrait.silhouette = not found
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(portrait)
		var s := PetDB.get_species(id)
		var title := make_label(String(s["name"]) if found else "???", 13, Color(1, 0.9, 0.7) if found else Color(0.6, 0.6, 0.6))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		if found:
			var info := make_label("생산★%d 성장★%d\n애정★%d · %s" % [s["prod"], s["growth"], s["affection"], Collection.how_text(id)], 11)
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(info)
			(card[0] as Control).tooltip_text = String(s["desc"])
		_grid.add_child(card[0])
