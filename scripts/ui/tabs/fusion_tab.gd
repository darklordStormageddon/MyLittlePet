extends TabBase
## 합성 탭 (기획안 11). 결과를 모르는 조합을 직접 시도하며 발견하는 재미.

var _a := OptionButton.new()
var _b := OptionButton.new()
var _preview: Label
var _result: Label
var _recipes := VBoxContainer.new()


func _ready() -> void:
	name = "합성"
	add_title("펫 합성")
	add_text("두 펫을 합성하면 새로운 펫이 태어나요. 어떤 조합은 결과를 알려주지 않아요.\n실패해도 펫은 사라지지 않아요.", 12)
	box.add_child(_a)
	box.add_child(_b)
	_a.item_selected.connect(func(_i): _update_preview())
	_b.item_selected.connect(func(_i): _update_preview())
	_preview = add_text("", 14)
	box.add_child(make_button("합성하기", _on_fuse))
	_result = make_label("", 14, Color(0.6, 1.0, 0.7))
	box.add_child(_result)
	box.add_child(HSeparator.new())
	add_title("알려진 조합")
	box.add_child(_recipes)
	EventBus.pets_changed.connect(_rebuild_options)
	EventBus.recipe_learned.connect(func(_id): _rebuild_recipes())
	EventBus.game_loaded.connect(func(): _rebuild_options(); _rebuild_recipes())
	_rebuild_options()
	_rebuild_recipes()


func _rebuild_options() -> void:
	var keep_a := _a.get_selected_id()
	var keep_b := _b.get_selected_id()
	for ob in [_a, _b]:
		ob.clear()
		for pet in PetManager.pets:
			ob.add_item("%s (%s) Lv.%d · 애정 %d" % [pet.display_name(), PetDB.display_name(pet.species), pet.level, int(pet.affection)], pet.uid)
	_select(_a, keep_a, 0)
	_select(_b, keep_b, 1)
	_update_preview()


func _select(ob: OptionButton, id: int, fallback: int) -> void:
	var idx := ob.get_item_index(id) if id >= 0 else -1
	if idx < 0:
		idx = mini(fallback, ob.item_count - 1)
	if idx >= 0:
		ob.select(idx)


func _rebuild_recipes() -> void:
	clear(_recipes)
	for r in FusionManager.visible_recipes():
		_recipes.add_child(make_label(r["text"], 13, Color(0.7, 1.0, 0.8) if r["known"] else Color(0.85, 0.85, 0.85)))
	_recipes.add_child(make_label("...그리고 아직 아무도 모르는 조합들이 있어요.", 12, Color(0.7, 0.7, 0.7)))


func _update_preview() -> void:
	if PetManager.pets.size() < 2:
		_preview.text = "합성하려면 펫이 2마리 이상 필요해요."
		return
	_preview.text = String(FusionManager.preview(_a.get_selected_id(), _b.get_selected_id())["text"])


func _on_fuse() -> void:
	var res := FusionManager.fuse(_a.get_selected_id(), _b.get_selected_id())
	_result.text = String(res["message"])
	_rebuild_options()


func refresh() -> void:
	_update_preview()
