extends Control
## 메인 화면. 상단 재화 바 + 펫집 + 사이드 탭 + 알림 바, 관찰 팝업, 접속 리포트.

const HouseView := preload("res://scripts/ui/house_view.gd")
const PetPopup := preload("res://scripts/ui/pet_popup.gd")
const FocusTab := preload("res://scripts/ui/tabs/focus_tab.gd")
const PetsTab := preload("res://scripts/ui/tabs/pets_tab.gd")
const ShopTab := preload("res://scripts/ui/tabs/shop_tab.gd")
const HouseTab := preload("res://scripts/ui/tabs/house_tab.gd")
const FusionTab := preload("res://scripts/ui/tabs/fusion_tab.gd")
const CollectionTab := preload("res://scripts/ui/tabs/collection_tab.gd")
const RecordTab := preload("res://scripts/ui/tabs/record_tab.gd")

const MINI_SIZE := Vector2i(560, 380)
const MAX_MESSAGES := 3

var _gold_label: Label
var _rate_label: Label
var _status_label: Label
var _mini_button: Button
var _top_bar: Control
var _tabs := TabContainer.new()
var _messages_label: Label
var _bottom_bar: Control
var _house_scroll := ScrollContainer.new()
var _house_view: Control
var _popup: PanelContainer
var _report := AcceptDialog.new()

var _messages: Array = []
var _refresh_timer := 0.0
var _mini := false
var _normal_size := Vector2i(1280, 720)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.1, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# --- 상단 바 ---
	var top := _panel(Color(0.18, 0.15, 0.2))
	_top_bar = top
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top.add_child(top_row)
	_gold_label = TabBase.make_label("", 20, Color(1.0, 0.85, 0.3))
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_row.add_child(_gold_label)
	_rate_label = TabBase.make_label("", 14)
	_rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_row.add_child(_rate_label)
	_status_label = TabBase.make_label("", 13, Color(0.8, 0.85, 1.0))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	top_row.add_child(_status_label)
	_mini_button = TabBase.make_button("미니 모드", _toggle_mini)
	_mini_button.tooltip_text = "작은 창으로 띄워두고 펫을 지켜봐요 (항상 위)"
	top_row.add_child(_mini_button)
	root.add_child(top)

	# --- 중앙: 펫집 + 탭 ---
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	root.add_child(middle)
	_house_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_house_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_house_scroll)
	_house_view = HouseView.new()
	_house_scroll.add_child(_house_view)
	_house_view.pet_clicked.connect(_open_popup)

	_tabs.custom_minimum_size = Vector2(430, 0)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_tabs)
	_tabs.add_child(FocusTab.new())
	var pets_tab := PetsTab.new()
	pets_tab.observe_requested.connect(_open_popup)
	_tabs.add_child(pets_tab)
	_tabs.add_child(ShopTab.new())
	var house_tab := HouseTab.new()
	house_tab.house_view = _house_view
	_tabs.add_child(house_tab)
	_tabs.add_child(FusionTab.new())
	_tabs.add_child(CollectionTab.new())
	_tabs.add_child(RecordTab.new())

	# --- 하단 알림 바 ---
	var bottom := _panel(Color(0.16, 0.14, 0.18))
	_bottom_bar = bottom
	_messages_label = TabBase.make_label("", 13)
	_messages_label.custom_minimum_size.y = 54
	bottom.add_child(_messages_label)
	root.add_child(bottom)

	# --- 팝업 ---
	_popup = PetPopup.new()
	add_child(_popup)
	_popup.position = Vector2(24, 70)
	_report.title = "다녀왔어요!"
	_report.ok_button_text = "수령하기"
	_report.confirmed.connect(_claim)
	_report.canceled.connect(_claim)
	add_child(_report)

	EventBus.toast.connect(_push_message)
	EventBus.pet_speech.connect(_on_pet_speech)

	_on_loaded()
	_refresh()


func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	return p


## 접속 시: 펫의 인사(기억 시스템) + 자리 비운 동안의 리포트
func _on_loaded() -> void:
	var rep := SaveManager.startup_report
	if rep.is_empty():
		return
	var pet := PetManager.get_pet(int(rep.get("pet_uid", -1)))
	if pet and String(rep.get("greeting", "")) != "":
		PetManager.say(pet, String(rep["greeting"]))
	if bool(rep.get("new_game", false)):
		_push_message("🐶 몽이가 새 집에 왔어요! [집중] 탭에서 '공부 시작'을 누르면 몽이가 함께 집중해요.")
		return
	var away := int(rep.get("away_sec", 0))
	var gold := float(rep.get("gold", 0.0))
	if away < 60 or gold <= 0.0:
		_claim()
		return
	var lines: Array = ["자리를 비운 %s 동안" % _away_text(away),
		"펫들이 %s 골드를 생산했어요!" % Balance.format_number(gold)]
	var levels: Dictionary = rep.get("levels", {})
	for uid in levels:
		var p := PetManager.get_pet(int(uid))
		if p:
			lines.append("· %s 레벨 +%d (Lv.%d)" % [p.display_name(), int(levels[uid]), p.level])
	var focus: Dictionary = rep.get("focus_result", {})
	if not focus.is_empty():
		lines.append("· 집중 세션 %s 완료! 애정도 +%d" % [Balance.format_minutes_korean(float(focus["minutes"])), int(focus["affection"])])
	if pet:
		lines.append("\n%s: \"%s\"" % [pet.display_name(), rep["greeting"]])
	_report.dialog_text = "\n".join(lines)
	_report.popup_centered.call_deferred()


func _away_text(sec: int) -> String:
	if sec >= 86400:
		return "%d일 %d시간" % [sec / 86400, (sec % 86400) / 3600]
	if sec >= 3600:
		return "%d시간 %d분" % [sec / 3600, (sec % 3600) / 60]
	return "%d분" % (sec / 60)


func _claim() -> void:
	var amount := Economy.claim_offline_gold()
	if amount > 0.0:
		_push_message("💰 %s 골드를 수령했어요!" % Balance.format_number(amount))


func _open_popup(uid: int) -> void:
	_popup.open(uid)


func _on_pet_speech(uid: int, text: String) -> void:
	var pet := PetManager.get_pet(uid)
	if pet:
		_push_message("%s: \"%s\"" % [pet.display_name(), text])


func _push_message(text: String) -> void:
	_messages.append(text)
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	_messages_label.text = "\n".join(_messages)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh()


func _refresh() -> void:
	_gold_label.text = "💰 %s G" % Balance.format_number(Economy.gold)
	_rate_label.text = "+%s / 분" % Balance.format_number(PetManager.total_production_per_min())
	var status: Array = []
	if FocusManager.active:
		status.append("📖 집중 중 %s" % Balance.format_duration(FocusManager.elapsed_seconds()))
	var buff := FocusManager.production_buff_at(Clock.now())
	if buff > 0.0:
		status.append("생산 +%d%%" % int(buff * 100))
	status.append("🏠 %s (Lv.%d)" % [HouseManager.stage_name(), HouseManager.house_level])
	status.append("📘 %d/%d" % [Collection.discovered_count(), Collection.total_count()])
	_status_label.text = "   ".join(status)
	var current := _tabs.get_current_tab_control()
	if current is TabBase and not _mini:
		(current as TabBase).refresh()


## 미니 모드: 작은 창 + 항상 위. 게임을 계속 조작하지 않고 펫을 지켜보는 용도 (기획안 7)
func _toggle_mini() -> void:
	_mini = not _mini
	_tabs.visible = not _mini
	_bottom_bar.visible = not _mini
	_rate_label.visible = not _mini
	_mini_button.text = "전체 화면" if _mini else "미니 모드"
	var win := get_window()
	if _mini:
		_normal_size = win.size
		win.always_on_top = true
		win.size = MINI_SIZE
		_house_scroll.scroll_horizontal = 0
		_house_scroll.scroll_vertical = 220
	else:
		win.always_on_top = false
		win.size = _normal_size
