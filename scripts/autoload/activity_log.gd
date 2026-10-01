extends Node
## 「펫이 플레이어의 생활을 기억한다」 (기획안 13).
## 날짜별 집중 시간/생산량/레벨업 기록을 남기고, 다음 접속 시 펫의 인사말에 반영한다.

const KEEP_DAYS := 60
const LONG_ABSENCE_SEC := 2 * 24 * 3600
const LONG_FOCUS_MIN := 120.0
const BUSY_DAYS := 3

## "YYYY-MM-DD" -> {"focus_min", "sessions", "gold", "levels", "logins"}
var days: Dictionary = {}
var first_play: int = 0
var last_seen: int = 0
var total_focus_minutes: float = 0.0
var total_sessions: int = 0
var best_streak: int = 0


func reset(now: int) -> void:
	days = {}
	first_play = now
	last_seen = now
	total_focus_minutes = 0.0
	total_sessions = 0
	best_streak = 0


func _day(key: String) -> Dictionary:
	if not days.has(key):
		days[key] = {"focus_min": 0.0, "sessions": 0, "gold": 0.0, "levels": 0, "logins": 0}
	return days[key]


func today() -> Dictionary:
	return _day(Clock.date_key())


func record_focus(minutes: float, at: int = -1) -> void:
	var d := _day(Clock.date_key(at))
	d["focus_min"] = float(d["focus_min"]) + minutes
	d["sessions"] = int(d["sessions"]) + 1
	total_focus_minutes += minutes
	total_sessions += 1
	best_streak = maxi(best_streak, focus_streak())


func record_gold(amount: float) -> void:
	var d := today()
	d["gold"] = float(d["gold"]) + amount


func record_level_up(count: int = 1) -> void:
	var d := today()
	d["levels"] = int(d["levels"]) + count


func record_login(now: int) -> void:
	var d := _day(Clock.date_key(now))
	d["logins"] = int(d["logins"]) + 1
	_prune(now)


func touch(now: int) -> void:
	last_seen = now


func focus_minutes_on(key: String) -> float:
	return float(days.get(key, {}).get("focus_min", 0.0))


## 오늘(또는 오늘 아직 안 했으면 어제)부터 연속으로 집중한 날 수
func focus_streak(now: int = -1) -> int:
	if now < 0:
		now = Clock.now()
	var t := now
	if focus_minutes_on(Clock.date_key(t)) <= 0.0:
		t -= 86400
	var streak := 0
	while focus_minutes_on(Clock.date_key(t)) > 0.0:
		streak += 1
		t -= 86400
	return streak


## 마지막으로 집중한 날로부터 지난 일수. 기록이 없으면 첫 플레이부터 계산.
func days_since_focus(now: int = -1) -> int:
	if now < 0:
		now = Clock.now()
	for i in range(0, KEEP_DAYS):
		if focus_minutes_on(Clock.date_key(now - i * 86400)) > 0.0:
			return i
	return int((now - first_play) / 86400)


## 최근 n일 기록 (오래된 날 → 오늘)
func recent_days(n: int, now: int = -1) -> Array:
	if now < 0:
		now = Clock.now()
	var out: Array = []
	for i in range(n - 1, -1, -1):
		var key := Clock.date_key(now - i * 86400)
		var d: Dictionary = days.get(key, {})
		out.append({"date": key, "focus_min": float(d.get("focus_min", 0.0)),
			"gold": float(d.get("gold", 0.0)), "levels": int(d.get("levels", 0))})
	return out


## 접속 시 펫의 첫 인사. 우선순위대로 플레이어의 최근 생활을 반영한다.
func build_greeting(pet: PetData, away_sec: int, now: int) -> String:
	var aff := pet.affection
	var played_before := now - first_play > 3600
	if played_before and away_sec >= LONG_ABSENCE_SEC:
		return DialogueDB.pick("greet_long_absence", aff)
	var streak := focus_streak(now)
	if streak >= 2:
		return DialogueDB.pick("greet_streak", aff, {"n": streak})
	var today_min := focus_minutes_on(Clock.date_key(now))
	if today_min >= LONG_FOCUS_MIN:
		return DialogueDB.pick("greet_long_focus_today", aff, {"time": Balance.format_minutes_korean(today_min)})
	if focus_minutes_on(Clock.date_key(now - 86400)) >= LONG_FOCUS_MIN:
		return DialogueDB.pick("greet_long_focus_yesterday", aff)
	if played_before and total_sessions > 0 and days_since_focus(now) >= BUSY_DAYS:
		return DialogueDB.pick("greet_busy", aff)
	if aff >= 60.0 and randf() < 0.5:
		return DialogueDB.pick("greet_regular", aff)
	return DialogueDB.pick("greet_" + Clock.day_part(now), aff)


func _prune(now: int) -> void:
	var limit := Clock.date_key(now - KEEP_DAYS * 86400)
	for key in days.keys():
		if String(key) < limit:
			days.erase(key)


func to_dict() -> Dictionary:
	return {"days": days, "first_play": first_play, "last_seen": last_seen,
		"total_focus_minutes": total_focus_minutes, "total_sessions": total_sessions,
		"best_streak": best_streak}


func from_dict(d: Dictionary) -> void:
	days = d.get("days", {})
	first_play = int(d.get("first_play", Clock.now()))
	last_seen = int(d.get("last_seen", Clock.now()))
	total_focus_minutes = float(d.get("total_focus_minutes", 0.0))
	total_sessions = int(d.get("total_sessions", 0))
	best_streak = int(d.get("best_streak", 0))
