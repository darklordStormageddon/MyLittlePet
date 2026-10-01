class_name PetData
extends RefCounted
## 펫 한 마리의 상태 (기획안 3-1, 6).
## 레벨 / 애정도 / 배고픔 / 기분 / 생산량 / 성장 경험치를 가진다.
## 시간 기반 시뮬레이션(simulate)은 온라인/오프라인 모두에서 같은 식을 사용한다.

var uid: int = 0
var species: String = "dog"
var nickname: String = ""
var level: int = 1
var exp: float = 0.0
var affection: float = 10.0 ## 0 ~ 100
var hunger: float = 20.0 ## 0(배부름) ~ 100(매우 배고픔)
var mood: float = 60.0 ## 0 ~ 100
var total_produced: float = 0.0
var focus_minutes_together: float = 0.0
var born_at: int = 0
var last_pet_time: float = -999.0

# --- 행동(런타임 전용, 저장하지 않음) ---
var activity: String = "idle"
var activity_left: float = 0.0
var activity_target: int = -1 ## 가구 uid 또는 다른 펫 uid
var speech: String = ""
var speech_left: float = 0.0


func species_data() -> Dictionary:
	return PetDB.get_species(species)


func display_name() -> String:
	return nickname if nickname != "" else PetDB.display_name(species)


func prod_stars() -> int:
	return int(species_data()["prod"])


func growth_stars() -> int:
	return int(species_data()["growth"])


func affection_stars() -> int:
	return int(species_data()["affection"])


# --- 생산 ---

## 기분에 따른 생산 배율: 0.85 ~ 1.15
func mood_multiplier() -> float:
	return 0.85 + 0.3 * clampf(mood, 0.0, 100.0) / 100.0


## 애정도 생산 보너스: 최대 +20%
func affection_multiplier() -> float:
	return 1.0 + 0.2 * clampf(affection, 0.0, 100.0) / 100.0


## 너무 배고프면 생산이 조금 느려진다 (죽거나 사라지지 않음 - 원칙 1)
func hunger_multiplier() -> float:
	return 0.75 if hunger >= Balance.STARVING_THRESHOLD else 1.0


func production_per_min(global_mult: float = 1.0) -> float:
	return Balance.base_production_per_min(level) * Balance.star_mult(prod_stars()) \
		* mood_multiplier() * affection_multiplier() * hunger_multiplier() * global_mult


# --- 성장 ---

func exp_to_next() -> float:
	return Balance.exp_to_next(level)


func exp_per_min(growth_mult: float = 1.0) -> float:
	if level >= Balance.MAX_LEVEL:
		return 0.0
	return Balance.base_exp_per_min(level) * Balance.star_mult(growth_stars()) * growth_mult


## 경험치를 더하고 오른 레벨 수를 반환한다.
func add_exp(amount: float) -> int:
	if level >= Balance.MAX_LEVEL:
		exp = 0.0
		return 0
	exp += amount
	var gained := 0
	while level < Balance.MAX_LEVEL and exp >= exp_to_next():
		exp -= exp_to_next()
		level += 1
		gained += 1
	if level >= Balance.MAX_LEVEL:
		exp = 0.0
	return gained


func add_affection(amount: float) -> void:
	# 애정도 상승 별이 높을수록 같은 행동으로 더 많이 오른다
	if amount > 0.0:
		amount *= Balance.star_mult(affection_stars())
	affection = clampf(affection + amount, 0.0, Balance.MAX_AFFECTION)


func add_mood(amount: float) -> void:
	mood = clampf(mood + amount, 0.0, 100.0)


func add_hunger(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 100.0)


## dt 초 동안의 성장/생산/배고픔/기분 변화를 적용한다.
## 반환: {"gold": 생산량, "levels": 오른 레벨 수}
func simulate(dt: float, growth_mult: float, prod_mult: float) -> Dictionary:
	var minutes := dt / 60.0
	var gold := production_per_min(prod_mult) * minutes
	total_produced += gold
	var levels := add_exp(exp_per_min(growth_mult) * minutes)
	add_hunger(Balance.HUNGER_PER_HOUR * dt / 3600.0)
	# 기분은 천천히 중립으로 돌아간다. 배고프면 조금씩 떨어진다.
	var target := Balance.MOOD_NEUTRAL
	if hunger >= Balance.HUNGRY_THRESHOLD:
		target = 30.0
	mood = move_toward(mood, target, Balance.MOOD_DRIFT_PER_HOUR * dt / 3600.0)
	return {"gold": gold, "levels": levels}


# --- 외형 / 상태 표시 ---

func growth_stage() -> int:
	return Balance.growth_stage_index(level)


func growth_stage_name() -> String:
	return String(Balance.GROWTH_STAGES[growth_stage()]["name"])


func has_study_glasses() -> bool:
	return focus_minutes_together >= Balance.STUDY_GLASSES_MINUTES


func mood_label() -> String:
	if activity == "sleep" or activity == "nap":
		return "쿨쿨"
	if hunger >= Balance.HUNGRY_THRESHOLD:
		return "배고픔"
	if mood >= 75.0:
		return "행복함"
	if mood >= 45.0:
		return "평온함"
	if mood >= 20.0:
		return "심심함"
	return "시무룩"


func affection_title() -> String:
	if affection >= 85.0:
		return "단짝"
	if affection >= 60.0:
		return "절친"
	if affection >= 30.0:
		return "친구"
	return "알아가는 중"


# --- 저장 ---

func to_dict() -> Dictionary:
	return {
		"uid": uid, "species": species, "nickname": nickname, "level": level, "exp": exp,
		"affection": affection, "hunger": hunger, "mood": mood, "total_produced": total_produced,
		"focus_minutes_together": focus_minutes_together, "born_at": born_at,
	}


static func from_dict(d: Dictionary) -> PetData:
	var p := PetData.new()
	p.uid = int(d.get("uid", 0))
	p.species = String(d.get("species", "dog"))
	if not PetDB.has(p.species):
		p.species = "dog"
	p.nickname = String(d.get("nickname", ""))
	p.level = clampi(int(d.get("level", 1)), 1, Balance.MAX_LEVEL)
	p.exp = float(d.get("exp", 0.0))
	p.affection = float(d.get("affection", 10.0))
	p.hunger = float(d.get("hunger", 20.0))
	p.mood = float(d.get("mood", 60.0))
	p.total_produced = float(d.get("total_produced", 0.0))
	p.focus_minutes_together = float(d.get("focus_minutes_together", 0.0))
	p.born_at = int(d.get("born_at", 0))
	return p
