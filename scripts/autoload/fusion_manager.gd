extends Node
## 펫 합성 시스템 (기획안 11).
## 두 펫을 합성하면 새로운 펫을 얻는다. 일부 조합만 공개(결과는 ???)하고, 나머지는 직접 발견해야 한다.
## 실패해도 펫은 사라지지 않는다 (원칙 1: 죄책감으로 통제하지 않는다).

## public: 도감/합성 탭에 조합이 힌트로 노출되는지 여부 (결과는 발견 전까지 ???)
const RECIPES := [
	{"id": "fox", "a": "dog", "b": "cat", "result": "fox", "min_level": 10, "public": true},
	{"id": "squirrel", "a": "rabbit", "b": "hamster", "result": "squirrel", "min_level": 10, "public": true},
	{"id": "duck", "a": "chick", "b": "chick", "result": "duck", "min_level": 8, "public": true},
	{"id": "tiger", "a": "cat", "b": "rabbit", "result": "tiger", "min_level": 10, "public": false},
	{"id": "raccoon", "a": "dog", "b": "hamster", "result": "raccoon", "min_level": 10, "public": false},
	{"id": "owl", "a": "chick", "b": "cat", "result": "owl", "min_level": 15, "night": true, "public": false},
	{"id": "panda", "a": "tiger", "b": "raccoon", "result": "panda", "min_level": 20, "public": false},
	{"id": "penguin", "a": "duck", "b": "squirrel", "result": "penguin", "min_level": 20, "furniture": "pool", "public": false},
	{"id": "ninetail", "a": "fox", "b": "owl", "result": "ninetail", "min_level": 25, "min_affection": 80.0, "public": false},
	{"id": "dragon", "a": "panda", "b": "ninetail", "result": "dragon", "min_level": 30, "min_affection": 90.0, "public": false},
]

var learned: Dictionary = {} ## recipe_id -> true


func reset() -> void:
	learned = {}


func find_recipe(species_a: String, species_b: String) -> Dictionary:
	for r in RECIPES:
		if (r["a"] == species_a and r["b"] == species_b) or (r["a"] == species_b and r["b"] == species_a):
			return r
	return {}


func fusion_fee(pet_a: PetData, pet_b: PetData) -> float:
	return Balance.FUSION_FEE_BASE * float(pet_a.level + pet_b.level)


## 조건 검사. 실패 사유 목록을 반환한다 (빈 배열이면 성공 가능).
func unmet_conditions(recipe: Dictionary, pet_a: PetData, pet_b: PetData) -> Array:
	var reasons: Array = []
	var min_level := int(recipe.get("min_level", 1))
	if pet_a.level < min_level or pet_b.level < min_level:
		reasons.append("두 펫 모두 Lv.%d 이상" % min_level)
	var min_aff := float(recipe.get("min_affection", 0.0))
	if pet_a.affection < min_aff or pet_b.affection < min_aff:
		reasons.append("두 펫 모두 애정도 %d 이상" % int(min_aff))
	if bool(recipe.get("night", false)) and not Clock.is_night():
		reasons.append("밤 시간대 (22시~6시)")
	var furniture := String(recipe.get("furniture", ""))
	if furniture != "" and not HouseManager.has_placed(furniture):
		reasons.append("%s 배치" % FurnitureDB.display_name(furniture))
	return reasons


## 합성 미리보기. 발견하지 않은 결과는 ??? 로 표시한다.
func preview(uid_a: int, uid_b: int) -> Dictionary:
	var a := PetManager.get_pet(uid_a)
	var b := PetManager.get_pet(uid_b)
	if a == null or b == null or uid_a == uid_b:
		return {"valid": false, "text": "서로 다른 두 펫을 골라주세요."}
	var fee := fusion_fee(a, b)
	var recipe := find_recipe(a.species, b.species)
	var text := "%s + %s → " % [a.display_name(), b.display_name()]
	if not recipe.is_empty() and learned.has(recipe["id"]):
		text += PetDB.display_name(String(recipe["result"]))
		var reasons := unmet_conditions(recipe, a, b)
		if not reasons.is_empty():
			text += "\n필요 조건: " + ", ".join(reasons)
	elif not recipe.is_empty() and bool(recipe["public"]):
		text += "???\n힌트: 두 펫 모두 Lv.%d 이상" % int(recipe["min_level"])
	else:
		text += "???"
	text += "\n합성 비용: %s G (성공 시에만)" % Balance.format_number(fee)
	return {"valid": true, "text": text, "fee": fee}


func fuse(uid_a: int, uid_b: int) -> Dictionary:
	var a := PetManager.get_pet(uid_a)
	var b := PetManager.get_pet(uid_b)
	if a == null or b == null or uid_a == uid_b:
		return {"ok": false, "message": "서로 다른 두 펫을 골라주세요."}
	var recipe := find_recipe(a.species, b.species)
	if recipe.is_empty():
		return {"ok": false, "message": "아무 반응이 없었어요... 다른 조합을 시도해 볼까요?"}
	var reasons := unmet_conditions(recipe, a, b)
	if not reasons.is_empty():
		var msg := "뭔가 반응이 있는 것 같지만... 아직 무언가 부족해요."
		if bool(recipe["public"]) or learned.has(recipe["id"]):
			msg += "\n(" + ", ".join(reasons) + ")"
		return {"ok": false, "message": msg, "hint": true}
	var fee := fusion_fee(a, b)
	if not Economy.spend(fee):
		return {"ok": false, "message": "합성 비용이 부족해요. (%s G)" % Balance.format_number(fee)}

	var result_species := String(recipe["result"])
	var first_time := not Collection.is_discovered(result_species)
	var inherited_aff := (a.affection + b.affection) * 0.25
	var inherited_focus := (a.focus_minutes_together + b.focus_minutes_together) * 0.5
	PetManager.remove_pet(uid_a)
	PetManager.remove_pet(uid_b)
	var pet := PetManager.add_pet(result_species, "fusion")
	pet.affection = inherited_aff
	pet.focus_minutes_together = inherited_focus
	var newly_learned := not learned.has(recipe["id"])
	learned[recipe["id"]] = true
	if newly_learned:
		EventBus.recipe_learned.emit(String(recipe["id"]))
	var message := "합성 성공! %s이(가) 태어났어요!" % pet.display_name()
	if first_time:
		message = "🎉 새로운 펫 발견! %s (도감 %d / %d)" % [pet.display_name(),
			Collection.discovered_count(), Collection.total_count()]
	EventBus.toast.emit(message)
	Collection.check_hidden()
	return {"ok": true, "message": message, "pet": pet, "first_time": first_time}


## 합성 탭에 보여줄 레시피 목록 (공개 레시피 + 직접 발견한 레시피)
func visible_recipes() -> Array:
	var out: Array = []
	for r in RECIPES:
		var known := learned.has(r["id"])
		if not known and not bool(r["public"]):
			continue
		var text := "%s + %s → %s" % [PetDB.display_name(String(r["a"])), PetDB.display_name(String(r["b"])),
			PetDB.display_name(String(r["result"])) if known else "???"]
		if not known:
			text += "  (Lv.%d 이상)" % int(r["min_level"])
		out.append({"text": text, "known": known})
	return out


func to_dict() -> Dictionary:
	return {"learned": learned.keys()}


func from_dict(d: Dictionary) -> void:
	learned = {}
	for id in d.get("learned", []):
		learned[String(id)] = true
