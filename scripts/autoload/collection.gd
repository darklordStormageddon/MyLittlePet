extends Node
## 도감 / 히든 펫 시스템 (기획안 12).
## 도감에는 존재한다는 사실만 보여주고 획득 조건은 공개하지 않는다.
## 히든 펫의 조건은 레벨 / 가구 배치 / 접속 시간 / 애정도 / 집중 시간 / 연속 기록 등 다양하다.

## 히든 펫 조건. check 는 _is_condition_met 에서 해석한다.
const HIDDEN_RULES := {
	"unicorn": {"type": "any_level", "value": 50},
	"hedgehog": {"type": "furniture_all", "value": ["bookshelf", "plant"]},
	"bat": {"type": "hour_between", "value": [2, 4]},
	"alpaca": {"type": "any_affection", "value": 100.0},
	"turtle": {"type": "total_focus_minutes", "value": 600.0},
	"golden_hamster": {"type": "species_level", "value": ["hamster", 30]},
	"koala": {"type": "focus_streak", "value": 7},
}

var discovered: Dictionary = {} ## species_id -> {"at": int, "how": String}
var _checking := false


func reset() -> void:
	discovered = {}


func is_discovered(species_id: String) -> bool:
	return discovered.has(species_id)


func discovered_count() -> int:
	return discovered.size()


func total_count() -> int:
	return PetDB.ORDER.size()


func discover(species_id: String, how: String) -> bool:
	if discovered.has(species_id) or not PetDB.has(species_id):
		return false
	discovered[species_id] = {"at": Clock.now(), "how": how}
	EventBus.species_discovered.emit(species_id, how)
	return true


func check_hidden() -> void:
	if _checking or not SaveManager.loaded:
		return
	_checking = true
	for id in HIDDEN_RULES:
		if discovered.has(id):
			continue
		if _is_condition_met(HIDDEN_RULES[id]):
			discover(id, "hidden")
			var pet := PetManager.add_pet(id, "hidden")
			EventBus.toast.emit("🎉 히든 펫 발견! [%s]이(가) 펫집에 찾아왔어요! (도감 %d / %d)" % [
				pet.display_name(), discovered_count(), total_count()])
	_checking = false


func _is_condition_met(rule: Dictionary) -> bool:
	var v = rule["value"]
	match String(rule["type"]):
		"any_level":
			for pet in PetManager.pets:
				if pet.level >= int(v):
					return true
		"species_level":
			for pet in PetManager.pets:
				if pet.species == String(v[0]) and pet.level >= int(v[1]):
					return true
		"any_affection":
			for pet in PetManager.pets:
				if pet.affection >= float(v) - 0.001:
					return true
		"furniture_all":
			for f in v:
				if not HouseManager.has_placed(String(f)):
					return false
			return true
		"hour_between":
			var h := Clock.local_hour()
			return h >= int(v[0]) and h < int(v[1])
		"total_focus_minutes":
			return ActivityLog.total_focus_minutes >= float(v)
		"focus_streak":
			return ActivityLog.focus_streak() >= int(v)
	return false


func how_text(species_id: String) -> String:
	match String(discovered.get(species_id, {}).get("how", "")):
		"shop", "starter":
			return "입양"
		"fusion":
			return "합성으로 발견"
		"hidden":
			return "히든 조건 달성"
	return ""


func to_dict() -> Dictionary:
	return {"discovered": discovered}


func from_dict(d: Dictionary) -> void:
	discovered = {}
	var src: Dictionary = d.get("discovered", {})
	for k in src:
		discovered[String(k)] = {"at": int(src[k].get("at", 0)), "how": String(src[k].get("how", ""))}
