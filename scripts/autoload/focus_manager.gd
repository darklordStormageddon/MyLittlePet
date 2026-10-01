extends Node
## 집중 세션 시스템 (기획안 4, 5).
## "공부 시작" 버튼을 누르면 펫이 함께 집중한다. PC 활동을 감시하지 않고 세션 타이머만 사용한다.
## - 집중 중: 성장 속도 ×1.5
## - 일반: ×1.0
## - 장시간(48시간) 집중 기록이 없음: ×0.7 (강한 패널티 없음)
## 세션이 끝나면 시간에 따라 애정도/경험치/생산량 버프 보상을 준다.

const HISTORY_SIZE := 50

var active: bool = false
var start_time: int = 0
var target_min: int = 0 ## 0 = 자유 세션(직접 종료)
var last_cheer_min: int = 0
var history: Array = [] ## [[start, end], ...] 오프라인 성장 배율 계산용
var prod_buff: float = 0.0
var prod_buff_until: int = 0

var _tick := 0.0


func reset() -> void:
	active = false
	start_time = 0
	target_min = 0
	last_cheer_min = 0
	history = []
	prod_buff = 0.0
	prod_buff_until = 0


func _process(delta: float) -> void:
	if not active:
		return
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	var now := Clock.now()
	var elapsed := elapsed_minutes(now)
	var limit := target_min if target_min > 0 else Balance.MAX_SESSION_MIN
	if elapsed >= float(limit):
		finish_session(start_time + limit * 60)
		return
	var whole := int(elapsed)
	if whole > 0 and whole - last_cheer_min >= Balance.FOCUS_CHEER_INTERVAL_MIN:
		last_cheer_min = whole
		var pet: PetData = PetManager.random_pet()
		if pet:
			PetManager.say(pet, DialogueDB.pick("focus_cheer", pet.affection,
				{"time": Balance.format_minutes_korean(whole)}))


func start_session(minutes: int) -> bool:
	if active:
		return false
	active = true
	start_time = Clock.now()
	target_min = maxi(0, minutes)
	last_cheer_min = 0
	for p in PetManager.pets:
		p.activity_left = 0.0 # 즉시 '같이 공부' 행동을 고르도록
	var pet: PetData = PetManager.random_pet()
	if pet:
		PetManager.say(pet, DialogueDB.pick("focus_start", pet.affection))
	EventBus.focus_started.emit(target_min)
	return true


func stop_session() -> Dictionary:
	if not active:
		return {}
	return finish_session(Clock.now())


func elapsed_seconds(now: int = -1) -> float:
	if not active:
		return 0.0
	if now < 0:
		now = Clock.now()
	return float(maxi(0, now - start_time))


func elapsed_minutes(now: int = -1) -> float:
	return elapsed_seconds(now) / 60.0


func remaining_seconds(now: int = -1) -> float:
	if not active or target_min <= 0:
		return 0.0
	return maxf(0.0, target_min * 60.0 - elapsed_seconds(now))


## 세션을 end_time 기준으로 종료하고 보상을 지급한다.
func finish_session(end_time: int) -> Dictionary:
	var minutes := floorf(float(maxi(0, end_time - start_time)) / 60.0)
	minutes = minf(minutes, float(target_min if target_min > 0 else Balance.MAX_SESSION_MIN))
	active = false
	var result := {"minutes": minutes, "affection": 0.0, "exp_ratio": 0.0, "prod_bonus": 0.0,
		"levels": 0, "completed": target_min > 0 and minutes >= target_min}
	if minutes >= 1.0:
		history.append([start_time, start_time + int(minutes * 60.0)])
		while history.size() > HISTORY_SIZE:
			history.pop_front()
		ActivityLog.record_focus(minutes, start_time)

	var tier := Balance.focus_reward_for(minutes)
	if not tier.is_empty():
		result["affection"] = tier["affection"]
		result["exp_ratio"] = tier["exp_ratio"]
		result["prod_bonus"] = tier["prod_bonus"]
		for pet in PetManager.pets:
			pet.add_affection(float(tier["affection"]))
			pet.add_mood(10.0)
			var gained := pet.add_exp(pet.exp_to_next() * float(tier["exp_ratio"]))
			result["levels"] = int(result["levels"]) + gained
			PetManager.notify_level_ups(pet, gained)
		if float(tier["prod_bonus"]) > 0.0:
			var current := production_buff_at(end_time)
			prod_buff = maxf(current, float(tier["prod_bonus"]))
			prod_buff_until = end_time + Balance.PROD_BUFF_DURATION_SEC
	for pet in PetManager.pets:
		pet.focus_minutes_together += minutes

	var speaker: PetData = PetManager.random_pet()
	if speaker:
		var key := "focus_done" if not tier.is_empty() else "focus_short"
		PetManager.say(speaker, DialogueDB.pick(key, speaker.affection,
			{"time": Balance.format_minutes_korean(minutes)}))
	EventBus.focus_finished.emit(result)
	Collection.check_hidden()
	return result


## 앱이 꺼져 있는 동안 목표 시간이 끝난 세션은 접속 시 완료 처리한다.
func resume_after_load(now: int) -> Dictionary:
	if not active:
		return {}
	var limit := target_min if target_min > 0 else Balance.MAX_SESSION_MIN
	if now >= start_time + limit * 60:
		return finish_session(start_time + limit * 60)
	return {}


func is_focus_at(t: int) -> bool:
	if active and t >= start_time:
		var limit := target_min if target_min > 0 else Balance.MAX_SESSION_MIN
		if t < start_time + limit * 60:
			return true
	for s in history:
		if t >= int(s[0]) and t < int(s[1]):
			return true
	return false


func last_focus_before(t: int) -> int:
	var last := ActivityLog.first_play
	for s in history:
		if int(s[0]) <= t:
			last = maxi(last, mini(int(s[1]), t))
	if active and start_time <= t:
		last = t
	return last


## 시각 t 에서의 성장 속도 배율 (기획안 5)
func growth_multiplier_at(t: int) -> float:
	if is_focus_at(t):
		return Balance.FOCUS_GROWTH_MULT
	if t - last_focus_before(t) > Balance.IDLE_THRESHOLD_SEC:
		return Balance.IDLE_GROWTH_MULT
	return Balance.NORMAL_GROWTH_MULT


func production_buff_at(t: int) -> float:
	return prod_buff if t < prod_buff_until else 0.0


func growth_state_text(t: int = -1) -> String:
	if t < 0:
		t = Clock.now()
	var m := growth_multiplier_at(t)
	if m > 1.0:
		return "집중 중 (성장 속도 ×%.1f)" % m
	if m < 1.0:
		return "오랜만이야 (성장 속도 ×%.1f)" % m
	return "일반 (성장 속도 ×%.1f)" % m


func to_dict() -> Dictionary:
	return {"active": active, "start_time": start_time, "target_min": target_min,
		"last_cheer_min": last_cheer_min, "history": history,
		"prod_buff": prod_buff, "prod_buff_until": prod_buff_until}


func from_dict(d: Dictionary) -> void:
	active = bool(d.get("active", false))
	start_time = int(d.get("start_time", 0))
	target_min = int(d.get("target_min", 0))
	last_cheer_min = int(d.get("last_cheer_min", 0))
	history = []
	for s in d.get("history", []):
		history.append([int(s[0]), int(s[1])])
	prod_buff = float(d.get("prod_buff", 0.0))
	prod_buff_until = int(d.get("prod_buff_until", 0))
