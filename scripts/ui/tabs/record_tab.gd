extends TabBase
## 기록 탭: 누적 생산량(기획안 15), 오늘의 성장(기획안 18 저녁), 기억 시스템(기획안 13).

var _total_label: Label
var _today_label: Label
var _memory_label: Label
var _eta_label: Label
var _chart := Control.new()


func _ready() -> void:
	name = "기록"
	add_title("우리의 기록")
	_total_label = make_label("", 18, Color(1.0, 0.9, 0.4))
	box.add_child(_total_label)
	_today_label = add_text("")
	_eta_label = add_text("", 13)
	box.add_child(HSeparator.new())
	add_title("최근 7일 집중 시간")
	_chart.custom_minimum_size = Vector2(0, 130)
	_chart.draw.connect(_draw_chart)
	box.add_child(_chart)
	_memory_label = add_text("", 13)
	box.add_child(HSeparator.new())
	box.add_child(make_button("지금 저장하기", func():
		if SaveManager.save_game():
			EventBus.toast.emit("저장했어요.")))
	refresh()


func refresh() -> void:
	var now := Clock.now()
	_total_label.text = "현재까지 %s골드를 생산했습니다." % Balance.format_number(Economy.total_produced)
	var today := ActivityLog.today()
	_today_label.text = "오늘의 성장\n· 집중 %s\n· 생산 %s G\n· 레벨업 %d회" % [
		Balance.format_minutes_korean(float(today["focus_min"]) + FocusManager.elapsed_minutes(now)),
		Balance.format_number(float(today["gold"])), int(today["levels"])]
	_eta_label.text = _eta_text()
	var together := int((now - ActivityLog.first_play) / 86400) + 1
	_memory_label.text = "함께한 지 %d일째 · 연속 집중 %d일 (최고 %d일)\n총 %d번 집중 · 누적 %s" % [together,
		ActivityLog.focus_streak(now), ActivityLog.best_streak, ActivityLog.total_sessions,
		Balance.format_minutes_korean(ActivityLog.total_focus_minutes)]
	_chart.queue_redraw()


## "조금만 더" - 다음 레벨/성장 단계까지 남은 시간 안내
func _eta_text() -> String:
	var lines: Array = []
	var growth := FocusManager.growth_multiplier_at(Clock.now())
	for pet in PetManager.pets:
		var rate := pet.exp_per_min(growth)
		if rate <= 0.0:
			continue
		var minutes := (pet.exp_to_next() - pet.exp) / rate
		var line := "%s: 다음 레벨까지 약 %s" % [pet.display_name(), Balance.format_minutes_korean(ceilf(minutes))]
		var stage := pet.growth_stage()
		if stage + 1 < Balance.GROWTH_STAGES.size() and pet.level + 1 == int(Balance.GROWTH_STAGES[stage + 1]["level"]):
			line += " → 곧 [%s] 모습으로 변해요!" % Balance.GROWTH_STAGES[stage + 1]["name"]
		lines.append(line)
		if lines.size() >= 4:
			break
	return "\n".join(lines)


func _draw_chart() -> void:
	var days := ActivityLog.recent_days(7)
	var w := _chart.size.x
	var h := _chart.size.y - 22
	var max_v := 60.0
	for d in days:
		max_v = maxf(max_v, float(d["focus_min"]))
	var bw := w / 7.0
	var font := ThemeDB.fallback_font
	for i in days.size():
		var v := float(days[i]["focus_min"])
		var bh := h * v / max_v
		var x := i * bw + 6
		_chart.draw_rect(Rect2(x, h - bh, bw - 12, bh), Color(0.5, 0.8, 1.0) if i < 6 else Color(1.0, 0.8, 0.4))
		_chart.draw_string(font, Vector2(x, h + 16), String(days[i]["date"]).substr(5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		if v > 0:
			_chart.draw_string(font, Vector2(x, h - bh - 4), "%d분" % int(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
