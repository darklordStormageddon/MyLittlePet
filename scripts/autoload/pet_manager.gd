extends Node
## 펫 관리 / 성장 / 생산 / 일상 행동 시스템 (기획안 3, 6, 7, 8, 10, 15).

const TICK_SEC := 1.0
const SPEECH_SEC := 4.5

var pets: Array[PetData] = []
var next_uid: int = 1
var purchases: int = 0 ## 상점 구매 횟수 (가격 상승용)

var _tick := 0.0
var _hungry_notified := {} ## uid -> bool


func reset() -> void:
	pets.clear()
	next_uid = 1
	purchases = 0
	_hungry_notified.clear()


func _process(delta: float) -> void:
	if not SaveManager.loaded:
		return
	update_behaviors(delta)
	_tick += delta
	if _tick >= TICK_SEC:
		var dt := _tick
		_tick = 0.0
		simulate_step(dt, Clock.now())


# --- 시간 기반 성장 / 생산 ---

## 온라인 상태의 한 틱. 생산된 골드는 바로 지급된다.
func simulate_step(dt: float, t: int) -> Dictionary:
	var growth := FocusManager.growth_multiplier_at(t)
	var prod := 1.0 + FocusManager.production_buff_at(t)
	var gold := 0.0
	var levels := 0
	for pet in pets.duplicate():
		var r: Dictionary = pet.simulate(dt, growth, prod)
		gold += float(r["gold"])
		levels += int(r["levels"])
		notify_level_ups(pet, int(r["levels"]))
		_check_hunger(pet)
	Economy.add_production(gold)
	return {"gold": gold, "levels": levels}


## 자리를 비운 동안의 성장/생산을 한 번에 계산한다 (최대 7일).
## 골드는 '수령 대기'로 들어간다.
func simulate_offline(from_t: int, to_t: int) -> Dictionary:
	var span := clampi(to_t - from_t, 0, Balance.OFFLINE_CAP_SEC)
	var report := {"seconds": span, "gold": 0.0, "levels": {}, "total_levels": 0}
	if span <= 0 or pets.is_empty():
		return report
	var start_levels := {}
	for pet in pets:
		start_levels[pet.uid] = pet.level
	var t := to_t - span
	var gold := 0.0
	while t < to_t:
		var dt := mini(int(Balance.OFFLINE_STEP_SEC), to_t - t)
		var growth := FocusManager.growth_multiplier_at(t)
		var prod := 1.0 + FocusManager.production_buff_at(t)
		for pet in pets:
			gold += float(pet.simulate(float(dt), growth, prod)["gold"])
		t += dt
	Economy.add_offline_production(gold)
	report["gold"] = gold
	for pet in pets.duplicate():
		var gained: int = pet.level - int(start_levels.get(pet.uid, pet.level))
		if gained > 0:
			report["levels"][pet.uid] = gained
			report["total_levels"] = int(report["total_levels"]) + gained
			notify_level_ups(pet, gained, true)
	HouseManager.update_level(total_levels())
	return report


func notify_level_ups(pet: PetData, gained: int, quiet: bool = false) -> void:
	if gained <= 0:
		return
	ActivityLog.record_level_up(gained)
	EventBus.pet_level_up.emit(pet.uid, pet.level)
	var old_stage := Balance.growth_stage_index(pet.level - gained)
	if pet.growth_stage() != old_stage:
		EventBus.pet_stage_up.emit(pet.uid, pet.growth_stage())
		if not quiet:
			say(pet, DialogueDB.pick("stage_up", pet.affection))
			EventBus.toast.emit("✨ %s의 모습이 변했어요! [%s]" % [pet.display_name(), pet.growth_stage_name()])
	elif not quiet:
		say(pet, DialogueDB.pick("level_up", pet.affection))
	HouseManager.update_level(total_levels())
	Collection.check_hidden()


func _check_hunger(pet: PetData) -> void:
	var hungry := pet.hunger >= Balance.HUNGRY_THRESHOLD
	if hungry and not _hungry_notified.get(pet.uid, false):
		say(pet, DialogueDB.pick("hungry", pet.affection))
	_hungry_notified[pet.uid] = hungry


# --- 조회 ---

func get_pet(uid: int) -> PetData:
	for pet in pets:
		if pet.uid == uid:
			return pet
	return null


func random_pet() -> PetData:
	return null if pets.is_empty() else pets[randi() % pets.size()]


func total_levels() -> int:
	var n := 0
	for pet in pets:
		n += pet.level
	return n


func current_prod_mult() -> float:
	return 1.0 + FocusManager.production_buff_at(Clock.now())


func total_production_per_min() -> float:
	var mult := current_prod_mult()
	var total := 0.0
	for pet in pets:
		total += pet.production_per_min(mult)
	return total


func count_species(species: String) -> int:
	var n := 0
	for pet in pets:
		if pet.species == species:
			n += 1
	return n


# --- 획득 (기획안 10) ---

func add_pet(species: String, source: String = "shop", quiet: bool = false) -> PetData:
	var pet := PetData.new()
	pet.uid = next_uid
	next_uid += 1
	pet.species = species
	pet.born_at = Clock.now()
	pets.append(pet)
	Collection.discover(species, source)
	EventBus.pets_changed.emit()
	if not quiet:
		say(pet, DialogueDB.pick("born", pet.affection))
	return pet


func remove_pet(uid: int) -> void:
	for i in pets.size():
		if pets[i].uid == uid:
			pets.remove_at(i)
			_hungry_notified.erase(uid)
			EventBus.pets_changed.emit()
			return


func is_full() -> bool:
	return pets.size() >= HouseManager.pet_capacity()


func pet_price(species: String) -> float:
	return ceilf(float(PetDB.get_species(species)["price"]) * pow(Balance.PET_PRICE_GROWTH, purchases))


## 상점 구매: 기본 펫 + 도감에서 발견한 펫
func can_buy_species(species: String) -> bool:
	var src := String(PetDB.get_species(species)["source"])
	return src == "shop" or Collection.is_discovered(species)


func buy_pet(species: String) -> PetData:
	if not can_buy_species(species):
		return null
	if is_full():
		EventBus.toast.emit("펫집이 가득 찼어요. 펫을 키워서 집을 확장해 보세요!")
		return null
	if not Economy.spend(pet_price(species)):
		EventBus.toast.emit("골드가 부족해요.")
		return null
	purchases += 1
	var pet := add_pet(species, "shop")
	EventBus.toast.emit("새 가족 %s이(가) 왔어요!" % pet.display_name())
	return pet


# --- 돌보기 ---

func food_price(food_id: String) -> float:
	return Balance.food_price(food_id, total_production_per_min())


func feed(uid: int, food_id: String = "kibble") -> bool:
	var pet := get_pet(uid)
	if pet == null or not Balance.FOODS.has(food_id):
		return false
	if food_id == "kibble" and pet.hunger < 5.0:
		say(pet, "배불러~")
		return false
	if not Economy.spend(food_price(food_id)):
		EventBus.toast.emit("골드가 부족해요.")
		return false
	var food: Dictionary = Balance.FOODS[food_id]
	pet.add_hunger(float(food["hunger"]))
	pet.add_mood(float(food["mood"]))
	pet.add_affection(float(food["affection"]))
	var bowls := HouseManager.placed_of("food_bowl")
	_set_activity(pet, "eat", int(bowls[0]["uid"]) if not bowls.is_empty() else -1)
	say(pet, DialogueDB.pick("feed" if food_id == "kibble" else "treat", pet.affection))
	Collection.check_hidden()
	return true


## 쓰다듬기: 쿨다운이 있어 애정도를 '연타'로 올릴 수는 없다.
func pet_pet(uid: int) -> bool:
	var pet := get_pet(uid)
	if pet == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - pet.last_pet_time < Balance.PET_COOLDOWN_SEC:
		pet.add_mood(1.0)
		say(pet, "히히")
		return false
	pet.last_pet_time = now
	pet.add_affection(0.6)
	pet.add_mood(4.0)
	_set_activity(pet, "heart" if pet.affection >= 85.0 else "look_player", -1)
	say(pet, DialogueDB.pick("pet", pet.affection))
	Collection.check_hidden()
	return true


func say(pet: PetData, text: String) -> void:
	if pet == null or text == "":
		return
	pet.speech = text
	pet.speech_left = SPEECH_SEC
	EventBus.pet_speech.emit(pet.uid, text)


# --- 펫의 일상 (기획안 8) ---

func update_behaviors(delta: float) -> void:
	for pet in pets:
		if pet.speech_left > 0.0:
			pet.speech_left -= delta
			if pet.speech_left <= 0.0:
				pet.speech = ""
		pet.activity_left -= delta
		if pet.activity_left <= 0.0:
			choose_activity(pet)
		# 애정도가 높을수록 혼잣말이 늘어난다
		elif pet.speech == "" and randf() < delta * 0.004 * pet.affection / 10.0:
			say(pet, DialogueDB.pick("idle_chat", pet.affection))


func choose_activity(pet: PetData) -> void:
	var focus := FocusManager.active
	var night := Clock.is_night()
	var cands: Array = [] # [id, weight, target]
	var total := 0.0
	for id in ActivityDB.ACTIVITIES:
		var def: Dictionary = ActivityDB.ACTIVITIES[id]
		if pet.affection < float(def.get("min_affection", 0.0)):
			continue
		var w := float(def["weight"])
		if focus and def.has("focus_weight"):
			w = float(def["focus_weight"])
		if night and def.has("night_weight"):
			w = float(def["night_weight"])
		match id:
			"beg":
				w = 6.0 if pet.hunger >= Balance.HUNGRY_THRESHOLD else 0.0
			"sleep", "nap":
				if night:
					w *= 3.0
			"look_player":
				w += pet.affection / 30.0
		if w <= 0.0:
			continue
		var target := -1
		var furniture := String(def["furniture"])
		if furniture != "":
			var list := HouseManager.placed_of(furniture)
			if list.is_empty():
				continue
			target = int(list[randi() % list.size()]["uid"])
		elif id == "play_pet":
			var others: Array = []
			for other in pets:
				if other.uid != pet.uid:
					others.append(other.uid)
			if others.is_empty():
				continue
			target = int(others[randi() % others.size()])
		cands.append([id, w, target])
		total += w
	if cands.is_empty():
		_set_activity(pet, "idle", -1)
		return
	var roll := randf() * total
	for c in cands:
		roll -= float(c[1])
		if roll <= 0.0:
			_set_activity(pet, String(c[0]), int(c[2]))
			return
	_set_activity(pet, String(cands[-1][0]), int(cands[-1][2]))


func _set_activity(pet: PetData, id: String, target: int) -> void:
	var def := ActivityDB.get_def(id)
	pet.activity = id
	pet.activity_target = target
	pet.activity_left = randf_range(float(def["duration"][0]), float(def["duration"][1]))
	pet.add_mood(float(def["mood"]) * 0.3)


func activity_text(pet: PetData) -> String:
	var other := ""
	if pet.activity == "play_pet":
		var o := get_pet(pet.activity_target)
		other = o.display_name() if o else "친구"
	return ActivityDB.describe(pet.activity, other)


# --- 저장 ---

func to_dict() -> Dictionary:
	var arr: Array = []
	for pet in pets:
		arr.append(pet.to_dict())
	return {"pets": arr, "next_uid": next_uid, "purchases": purchases}


func from_dict(d: Dictionary) -> void:
	reset()
	for pd in d.get("pets", []):
		pets.append(PetData.from_dict(pd))
	next_uid = int(d.get("next_uid", pets.size() + 1))
	purchases = int(d.get("purchases", 0))
	EventBus.pets_changed.emit()
