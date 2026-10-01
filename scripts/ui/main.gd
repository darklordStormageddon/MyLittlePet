extends Control
## 메인 화면. 상단 재화 바 + 펫집 + 사이드 탭 + 알림 바, 관찰 팝업, 접속 리포트.
## 화면 크기: 프로젝트 stretch(canvas_items/expand)로 창 크기에 맞춰 UI 전체가 비율 유지 확대/축소되고,
## 상단 바의 -/+ 로 UI 크기를 따로 조절할 수 있다. 펫집은 남은 공간에 맞춰 자동으로 맞춰진다.
## PiP 모드: 테두리 없는 투명 창(항상 위)에 펫집만 띄워 바탕화면의 일부처럼 보이게 한다.

const HouseView := preload("res://scripts/ui/house_view.gd")
const HouseFrame := preload("res://scripts/ui/house_frame.gd")
const PipOverlay := preload("res://scripts/ui/pip_overlay.gd")
const PetPopup := preload("res://scripts/ui/pet_popup.gd")
const FocusTab := preload("res://scripts/ui/tabs/focus_tab.gd")
const PetsTab := preload("res://scripts/ui/tabs/pets_tab.gd")
const ShopTab := preload("res://scripts/ui/tabs/shop_tab.gd")
const HouseTab := preload("res://scripts/ui/tabs/house_tab.gd")
const FusionTab := preload("res://scripts/ui/tabs/fusion_tab.gd")
const CollectionTab := preload("res://scripts/ui/tabs/collection_tab.gd")
const RecordTab := preload("res://scripts/ui/tabs/record_tab.gd")

const MAX_MESSAGES := 3
const NORMAL_MIN_SIZE := Vector2i(640, 360)
const SCREEN_MARGIN := 24

var _gold_label: Label
var _rate_label: Label
var _status_label: Label
var _top_bar: Control
var _scale_label: Label
var _bg: ColorRect
var _split := HSplitContainer.new()
var _house_frame: Control
var _pip_overlay: Control
var _tabs := TabContainer.new()
var _messages_label: Label
var _bottom_bar: Control
var _house_view: Control
var _popup: PanelContainer
var _report := AcceptDialog.new()

var _messages: Array = []
var _refresh_timer := 0.0
var _pip := false
var _normal_rect := Rect2i()
var _normal_maximized := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.color = Color(0.11, 0.1, 0.13)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

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
	var scale_box := HBoxContainer.new()
	scale_box.add_theme_constant_override("separation", 2)
	scale_box.add_child(_small_button("－", "UI 작게", func(): _set_ui_scale(-0.1)))
	_scale_label = TabBase.make_label("", 12)
	_scale_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_scale_label.tooltip_text = "UI 크기"
	_scale_label.mouse_filter = Control.MOUSE_FILTER_PASS
	scale_box.add_child(_scale_label)
	scale_box.add_child(_small_button("＋", "UI 크게", func(): _set_ui_scale(0.1)))
	top_row.add_child(scale_box)
	var pip_button := TabBase.make_button("바탕화면에 띄우기", _enter_pip)
	pip_button.tooltip_text = "펫집만 작은 투명 창으로 바탕화면 위에 띄워요 (항상 위, PiP)"
	top_row.add_child(pip_button)
	root.add_child(top)

	# --- 중앙: 펫집 + 탭 (가운데 경계를 드래그해 비율 조절) ---
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.split_offset = Settings.split_offset
	_split.dragged.connect(func(offset): Settings.split_offset = offset; Settings.save_settings())
	root.add_child(_split)
	_house_frame = HouseFrame.new()
	_house_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_house_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_house_frame.custom_minimum_size = Vector2(240, 160)
	_split.add_child(_house_frame)
	_house_view = HouseView.new()
	_house_frame.setup(_house_view)
	_house_frame.window_drag_finished.connect(_on_pip_window_changed)
	_house_view.pet_clicked.connect(_on_pet_clicked)

	_tabs.custom_minimum_size = Vector2(360, 0)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_tabs)
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
	_pip_overlay = PipOverlay.new()
	_pip_overlay.visible = false
	add_child(_pip_overlay)
	_pip_overlay.exit_requested.connect(_exit_pip)
	_pip_overlay.window_changed.connect(_on_pip_window_changed)
	_report.title = "다녀왔어요!"
	_report.ok_button_text = "수령하기"
	_report.confirmed.connect(_claim)
	_report.canceled.connect(_claim)
	add_child(_report)

	EventBus.toast.connect(_push_message)
	EventBus.pet_speech.connect(_on_pet_speech)

	_apply_ui_scale()
	_fit_window_to_screen.call_deferred()
	_on_loaded()
	_refresh()


func _small_button(text: String, tip: String, cb: Callable) -> Button:
	var b := TabBase.make_button(text, cb)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b


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


## PiP 에서는 팝업 대신 바로 쓰다듬는다 (작은 창에 맞게)
func _on_pet_clicked(uid: int) -> void:
	if _pip:
		PetManager.pet_pet(uid)
	else:
		_open_popup(uid)


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
	if current is TabBase and not _pip:
		(current as TabBase).refresh()


# --- 화면 크기 ---

func _set_ui_scale(delta: float) -> void:
	Settings.step_ui_scale(delta)
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	_scale_label.text = "UI %d%%" % int(round(Settings.ui_scale * 100))
	if not _pip:
		get_window().content_scale_factor = Settings.ui_scale


## 화면(작업 영역)보다 창이 크면 화면 안에 들어오도록 줄이고 가운데로 옮긴다
func _fit_window_to_screen() -> void:
	var win := get_window()
	win.min_size = NORMAL_MIN_SIZE
	if win.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if usable.size.x <= 0:
		return
	var target := Vector2i(mini(win.size.x, usable.size.x - SCREEN_MARGIN * 2),
		mini(win.size.y, usable.size.y - SCREEN_MARGIN * 2))
	if target != win.size:
		win.size = target
		win.position = usable.position + (usable.size - target) / 2


# --- PiP (바탕화면 위젯) 모드 ---

func _enter_pip() -> void:
	if _pip:
		return
	_pip = true
	_popup.visible = false
	var win := get_window()
	_normal_maximized = win.mode == Window.MODE_MAXIMIZED
	if _normal_maximized:
		win.mode = Window.MODE_WINDOWED
	_normal_rect = Rect2i(win.position, win.size)
	_set_chrome_visible(false)
	_house_frame.pip_mode = true
	_house_view.pip_mode = true
	_house_view.modulate.a = Settings.pip_opacity
	_pip_overlay.visible = true

	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_factor = 1.0
	get_viewport().transparent_bg = true
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	win.min_size = Settings.PIP_MIN_SIZE
	win.size = Settings.pip_size
	win.position = _pip_position(win)


func _exit_pip() -> void:
	if not _pip:
		return
	_on_pip_window_changed()
	_pip = false
	var win := get_window()
	_house_frame.pip_mode = false
	_house_view.pip_mode = false
	_house_view.modulate.a = 1.0
	_pip_overlay.visible = false
	_set_chrome_visible(true)

	win.always_on_top = false
	win.borderless = false
	win.transparent = false
	get_viewport().transparent_bg = false
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.min_size = NORMAL_MIN_SIZE
	win.size = _normal_rect.size
	win.position = _normal_rect.position
	if _normal_maximized:
		win.mode = Window.MODE_MAXIMIZED
	_apply_ui_scale()


func _set_chrome_visible(on: bool) -> void:
	_bg.visible = on
	_top_bar.visible = on
	_tabs.visible = on
	_bottom_bar.visible = on


## 저장된 위치가 화면 안에 있으면 그대로, 아니면 작업 영역 오른쪽 아래 구석
func _pip_position(win: Window) -> Vector2i:
	var pos := Settings.pip_position
	for i in DisplayServer.get_screen_count():
		var usable := DisplayServer.screen_get_usable_rect(i)
		if pos.x >= 0 and usable.has_point(pos + win.size / 2):
			return pos
	var screen := DisplayServer.screen_get_usable_rect(win.current_screen)
	return screen.end - win.size - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN)


## PiP 창을 옮기거나 크기를 바꾸면 기억해 둔다
func _on_pip_window_changed() -> void:
	if not _pip:
		return
	var win := get_window()
	Settings.pip_position = win.position
	Settings.pip_size = win.size
	_house_view.modulate.a = Settings.pip_opacity
	Settings.save_settings()
