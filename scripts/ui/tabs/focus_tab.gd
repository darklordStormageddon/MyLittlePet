extends TabBase
## 집중 세션 탭 (기획안 4, 5). "공부 시작"을 누르면 펫이 함께 집중한다.

var _timer_label: Label
var _status_label: Label
var _growth_label: Label
var _buff_label: Label
var _stats_label: Label
var _result_label: Label
var _start_buttons: Array = []
var _stop_button: Button


func _ready() -> void:
	name = "집중"
	add_title("펫과 함께 집중하기")
	add_text("공부·과제·작업을 시작할 때 눌러주세요. 펫이 옆에서 같이 집중하며 더 빨리 자라요.", 13)
	_timer_label = make_label("00:00", 44, Color(1, 1, 1))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_label)
	_status_label = make_label("", 14)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in [30, 60, 90, 120]:
		var b := make_button("%d분" % m, FocusManager.start_session.bind(m))
		row.add_child(b)
		_start_buttons.append(b)
	var free := make_button("자유", FocusManager.start_session.bind(0))
	row.add_child(free)
	_start_buttons.append(free)
	box.add_child(row)
	_stop_button = make_button("집중 끝내기", _on_stop)
	box.add_child(_stop_button)

	box.add_child(HSeparator.new())
	_growth_label = add_text("")
	_buff_label = add_text("")
	_stats_label = add_text("")
	_result_label = make_label("", 14, Color(0.6, 1.0, 0.7))
	box.add_child(_result_label)

	box.add_child(HSeparator.new())
	add_title("집중 보상")
	var lines: Array = []
	for i in range(Balance.FOCUS_REWARDS.size() - 1, -1, -1):
		var t: Dictionary = Balance.FOCUS_REWARDS[i]
		lines.append("%d분 → 애정도 +%d · 경험치 +%d%% · 생산량 +%d%% (4시간)" % [
			t["minutes"], t["affection"], int(float(t["exp_ratio"]) * 100), int(float(t["prod_bonus"]) * 100)])
	add_text("\n".join(lines), 13)
	add_text("집중 중 성장 ×1.5 · 평소 ×1.0 · 이틀 넘게 집중하지 않으면 ×0.7\n(펫은 절대 아프거나 떠나지 않아요. 함께할 때 더 잘 클 뿐!)", 12)

	EventBus.focus_finished.connect(_on_finished)
	refresh()


func refresh() -> void:
	var now := Clock.now()
	if FocusManager.active:
		if FocusManager.target_min > 0:
			_timer_label.text = Balance.format_duration(FocusManager.remaining_seconds(now))
			_status_label.text = "펫과 함께 집중하는 중... (목표 %d분)" % FocusManager.target_min
		else:
			_timer_label.text = Balance.format_duration(FocusManager.elapsed_seconds(now))
			_status_label.text = "펫과 함께 집중하는 중... (자유 세션)"
	else:
		_timer_label.text = "00:00"
		_status_label.text = "시간을 골라 집중을 시작해 보세요."
	for b in _start_buttons:
		b.disabled = FocusManager.active
	_stop_button.disabled = not FocusManager.active
	_growth_label.text = "현재 성장 상태: " + FocusManager.growth_state_text(now)
	var buff := FocusManager.production_buff_at(now)
	_buff_label.text = "생산량 버프: +%d%% (남은 시간 %s)" % [int(buff * 100), Balance.format_duration(FocusManager.prod_buff_until - now)] \
		if buff > 0.0 else "생산량 버프: 없음"
	var today := ActivityLog.focus_minutes_on(Clock.date_key(now)) + FocusManager.elapsed_minutes(now)
	_stats_label.text = "오늘 집중: %s · 연속 %d일 · 누적 %s" % [Balance.format_minutes_korean(today),
		ActivityLog.focus_streak(now), Balance.format_minutes_korean(ActivityLog.total_focus_minutes)]


func _on_stop() -> void:
	FocusManager.stop_session()


func _on_finished(result: Dictionary) -> void:
	var minutes := float(result.get("minutes", 0.0))
	if float(result.get("affection", 0.0)) <= 0.0:
		_result_label.text = "%s 집중했어요. 10분 이상 집중하면 보상이 있어요!" % Balance.format_minutes_korean(minutes)
	else:
		_result_label.text = "🎉 %s 집중 완료! 애정도 +%d, 경험치 +%d%%%s%s" % [
			Balance.format_minutes_korean(minutes), int(result["affection"]), int(float(result["exp_ratio"]) * 100),
			", 생산량 +%d%%" % int(float(result["prod_bonus"]) * 100) if float(result["prod_bonus"]) > 0.0 else "",
			" · 레벨업 %d회!" % int(result["levels"]) if int(result["levels"]) > 0 else ""]
	EventBus.toast.emit(_result_label.text)
	refresh()
