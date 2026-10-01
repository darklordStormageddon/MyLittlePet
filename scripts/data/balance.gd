class_name Balance
extends RefCounted
## 게임 밸런스 수치와 공용 계산식 모음.
## 기획안의 수치(레벨별 생산량, 집중 보상, 성장 배율 등)를 한 곳에서 조정할 수 있게 모아둔다.

const MAX_LEVEL := 100

## 레벨별 분당 기본 생산량 앵커 (기획안 3-1 표). 사이 구간은 로그 보간 → 점점 폭발적으로 증가.
const PRODUCTION_ANCHORS := [
	[1, 1.0],
	[5, 8.0],
	[10, 30.0],
	[20, 150.0],
	[50, 2000.0],
	[100, 50000.0],
]

## 별 개수(1~5)에 따른 배율. index = 별 개수
const STAR_MULT := [0.0, 0.6, 0.8, 1.0, 1.3, 1.7]

# --- 성장 경험치 ---
const BASE_EXP_PER_MIN := 10.0
const EXP_LEVEL_SCALE := 0.1
const EXP_CURVE_BASE := 30.0
const EXP_CURVE_POW := 1.8

# --- 집중 / 방치 배율 (기획안 5) ---
const FOCUS_GROWTH_MULT := 1.5
const NORMAL_GROWTH_MULT := 1.0
const IDLE_GROWTH_MULT := 0.7
## 마지막 집중 이후 이 시간이 지나면 '장시간 미집중'
const IDLE_THRESHOLD_SEC := 48 * 3600
## 자유 집중 세션이 앱이 꺼진 상태로 이어질 때 인정하는 최대 길이
const MAX_SESSION_MIN := 240
## 집중 중 펫이 응원하는 간격
const FOCUS_CHEER_INTERVAL_MIN := 15

## 집중 세션 보상 단계 (기획안 4). 높은 단계부터 검사한다.
## exp_ratio: 현재 레벨 필요 경험치 대비 보너스 비율, prod_bonus: 생산량 버프
const FOCUS_REWARDS := [
	{"minutes": 120, "affection": 14.0, "exp_ratio": 0.60, "prod_bonus": 0.20},
	{"minutes": 90, "affection": 10.0, "exp_ratio": 0.40, "prod_bonus": 0.15},
	{"minutes": 60, "affection": 7.0, "exp_ratio": 0.25, "prod_bonus": 0.10},
	{"minutes": 30, "affection": 3.0, "exp_ratio": 0.10, "prod_bonus": 0.05},
	{"minutes": 10, "affection": 1.0, "exp_ratio": 0.03, "prod_bonus": 0.0},
]
const PROD_BUFF_DURATION_SEC := 4 * 3600

# --- 펫 상태 ---
const HUNGER_PER_HOUR := 100.0 / 12.0
const HUNGRY_THRESHOLD := 70.0
const STARVING_THRESHOLD := 85.0
const MOOD_DRIFT_PER_HOUR := 6.0
const MOOD_NEUTRAL := 55.0
const PET_COOLDOWN_SEC := 30.0
const MAX_AFFECTION := 100.0

# --- 오프라인 ---
const OFFLINE_CAP_SEC := 7 * 24 * 3600
const OFFLINE_STEP_SEC := 60.0

# --- 먹이 ---
const FOODS := {
	"kibble": {"name": "사료", "hunger": -35.0, "mood": 5.0, "affection": 0.5, "price_min": 10.0, "price_rate_min": 0.5},
	"treat": {"name": "간식", "hunger": -15.0, "mood": 18.0, "affection": 1.5, "price_min": 30.0, "price_rate_min": 1.5},
}

# --- 펫집 확장 (기획안 16) ---
## house_level 은 '보유했던 펫 레벨 합의 최댓값'
const HOUSE_STAGES := [
	{"level": 1, "id": "room1", "name": "첫 번째 방", "capacity": 3},
	{"level": 10, "id": "room2", "name": "두 번째 방", "capacity": 5},
	{"level": 25, "id": "floor2", "name": "2층", "capacity": 8},
	{"level": 50, "id": "garden", "name": "정원", "capacity": 12},
	{"level": 100, "id": "basement", "name": "지하실", "capacity": 16},
	{"level": 200, "id": "town", "name": "거대한 펫 타운", "capacity": 30},
]

## 펫 성장 단계 (기획안 14)
const GROWTH_STAGES := [
	{"level": 1, "name": "아기", "scale": 0.6},
	{"level": 10, "name": "어린이", "scale": 0.78},
	{"level": 25, "name": "청소년", "scale": 0.9},
	{"level": 50, "name": "성체", "scale": 1.0},
	{"level": 100, "name": "특수 외형", "scale": 1.12},
]
## 함께 집중한 시간이 이 이상이면 '공부 안경' 외형이 생긴다 (기억 → 외형 변화)
const STUDY_GLASSES_MINUTES := 600.0

const PET_PRICE_GROWTH := 1.35
const FUSION_FEE_BASE := 200.0


static func base_production_per_min(level: int) -> float:
	level = clampi(level, 1, MAX_LEVEL)
	for i in range(PRODUCTION_ANCHORS.size() - 1):
		var a: Array = PRODUCTION_ANCHORS[i]
		var b: Array = PRODUCTION_ANCHORS[i + 1]
		if level <= int(b[0]):
			var t := float(level - int(a[0])) / float(int(b[0]) - int(a[0]))
			return exp(lerpf(log(float(a[1])), log(float(b[1])), t))
	return float(PRODUCTION_ANCHORS[-1][1])


static func star_mult(stars: int) -> float:
	return STAR_MULT[clampi(stars, 1, 5)]


static func exp_to_next(level: int) -> float:
	return roundf(EXP_CURVE_BASE * pow(float(level), EXP_CURVE_POW))


static func base_exp_per_min(level: int) -> float:
	return BASE_EXP_PER_MIN * (1.0 + EXP_LEVEL_SCALE * float(level - 1))


static func focus_reward_for(minutes: float) -> Dictionary:
	for tier in FOCUS_REWARDS:
		if minutes >= float(tier["minutes"]):
			return tier
	return {}


static func growth_stage_index(level: int) -> int:
	var idx := 0
	for i in GROWTH_STAGES.size():
		if level >= int(GROWTH_STAGES[i]["level"]):
			idx = i
	return idx


static func house_stage_index(house_level: int) -> int:
	var idx := 0
	for i in HOUSE_STAGES.size():
		if house_level >= int(HOUSE_STAGES[i]["level"]):
			idx = i
	return idx


static func pet_capacity(house_level: int) -> int:
	return int(HOUSE_STAGES[house_stage_index(house_level)]["capacity"])


static func food_price(food_id: String, total_rate_per_min: float) -> float:
	var f: Dictionary = FOODS[food_id]
	return ceilf(float(f["price_min"]) + total_rate_per_min * float(f["price_rate_min"]))


## 큰 숫자 표기. 천만 미만은 콤마, 그 이상은 만/억/조/경 단위.
static func format_number(value: float) -> String:
	var v := floorf(value)
	if absf(v) < 10000000.0:
		return _with_commas(int(v))
	var units := [[1e16, "경"], [1e12, "조"], [1e8, "억"], [1e4, "만"]]
	for u in units:
		if absf(v) >= float(u[0]):
			return "%.2f%s" % [v / float(u[0]), u[1]]
	return _with_commas(int(v))


static func _with_commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func format_duration(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%02d:%02d" % [m, sec]


static func format_minutes_korean(minutes: float) -> String:
	var m := int(minutes)
	if m >= 60:
		return "%d시간 %d분" % [m / 60, m % 60] if m % 60 != 0 else "%d시간" % (m / 60)
	return "%d분" % m
