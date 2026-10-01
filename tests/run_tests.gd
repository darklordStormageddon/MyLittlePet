extends SceneTree
## 헤드리스 시스템 테스트.
## 실행: godot --headless -s tests/run_tests.gd -- --no-autoload-save

var _failures := 0
var _checks := 0
var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   - ", label)
	else:
		_failures += 1
		print("  FAIL - ", label)


func approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func node(n: String) -> Node:
	return root.get_node(n)


func _run() -> void:
	var save: Node = node("SaveManager")
	var pets: Node = node("PetManager")
	var economy: Node = node("Economy")
	var focus: Node = node("FocusManager")
	var house: Node = node("HouseManager")
	var collection: Node = node("Collection")
	var fusion: Node = node("FusionManager")
	var log: Node = node("ActivityLog")
	save.autosave_enabled = false
	save.save_path = "user://test_save.json"
	save.delete_save()
	# 새벽 2~4시에는 히든 펫(박쥐)이 등장해 펫 수 검사가 달라지므로 시간을 비켜간다
	if Clock.local_hour() >= 1 and Clock.local_hour() < 5:
		Clock.debug_offset = 6 * 3600

	print("[Balance]")
	check(approx(Balance.base_production_per_min(1), 1.0, 0.01), "Lv1 생산량 1/분")
	check(approx(Balance.base_production_per_min(5), 8.0, 0.01), "Lv5 생산량 8/분")
	check(approx(Balance.base_production_per_min(10), 30.0, 0.01), "Lv10 생산량 30/분")
	check(approx(Balance.base_production_per_min(20), 150.0, 0.1), "Lv20 생산량 150/분")
	check(approx(Balance.base_production_per_min(50), 2000.0, 1.0), "Lv50 생산량 2000/분")
	check(Balance.base_production_per_min(30) > 150.0 and Balance.base_production_per_min(30) < 2000.0, "Lv30 보간")
	check(Balance.format_number(124823) == "124,823", "숫자 콤마 표기")
	check(Balance.format_number(123456789) == "1.23억", "억 단위 표기")
	check(Balance.focus_reward_for(30)["affection"] == 3.0, "30분 보상 애정도 +3")
	check(Balance.focus_reward_for(65)["prod_bonus"] == 0.10, "60분 보상 생산 +10%")
	check(Balance.focus_reward_for(5).is_empty(), "5분은 보상 없음")

	print("[새 게임]")
	var now := Clock.now()
	save.new_game(now)
	check(pets.pets.size() == 1, "시작 펫 1마리")
	check(economy.gold == 100.0, "시작 골드 100")
	check(house.has_placed("food_bowl"), "밥그릇 배치")
	check(collection.is_discovered("dog"), "강아지 도감 등록")

	print("[오프라인 진행]")
	var dog: PetData = pets.pets[0]
	var report: Dictionary = pets.simulate_offline(now - 3600, now)
	check(report["gold"] > 50.0, "1시간 방치 생산 > 50 (%.1f)" % report["gold"])
	check(economy.pending_offline_gold == report["gold"], "오프라인 골드는 수령 대기")
	check(dog.level > 1, "1시간 방치 후 레벨업 (Lv.%d)" % dog.level)
	check(dog.hunger > 20.0, "시간이 지나면 배고픔 증가")
	var claimed: float = economy.claim_offline_gold()
	check(claimed > 0.0 and economy.pending_offline_gold == 0.0, "오프라인 골드 수령")

	print("[집중 세션]")
	check(focus.growth_multiplier_at(now) == 1.0, "평상시 성장 ×1.0")
	check(focus.growth_multiplier_at(now + 49 * 3600) == 0.7, "장시간 미집중 ×0.7")
	var aff_before := dog.affection
	focus.start_session(60)
	check(focus.active, "세션 시작")
	check(focus.growth_multiplier_at(Clock.now() + 10) == 1.5, "집중 중 성장 ×1.5")
	focus.start_time -= 60 * 60
	var result: Dictionary = focus.finish_session(Clock.now())
	check(not focus.active, "세션 종료")
	check(result["minutes"] == 60.0, "60분 기록")
	check(approx(dog.affection - aff_before, 7.0 * Balance.star_mult(4), 0.01), "애정도 +7 (애정 별 보정)")
	check(focus.production_buff_at(Clock.now()) == 0.10, "생산량 버프 +10%")
	check(log.focus_minutes_on(Clock.date_key()) == 60.0, "오늘 집중 60분 기억")
	check(dog.focus_minutes_together == 60.0, "함께 집중한 시간 기록")

	print("[기억 시스템]")
	var yesterday := Clock.date_key(Clock.now() - 86400)
	log.days[yesterday] = {"focus_min": 30.0, "sessions": 1, "gold": 0.0, "levels": 0, "logins": 1}
	check(log.focus_streak() == 2, "연속 집중 2일")
	var greet: String = log.build_greeting(dog, 60, Clock.now())
	check(greet.contains("2일째"), "연속 기록 인사: " + greet)
	log.first_play = Clock.now() - 10 * 86400
	greet = log.build_greeting(dog, 3 * 86400, Clock.now())
	check(greet.contains("어디 갔다 왔어") or greet.contains("드디어 왔다"), "오랜 부재 인사: " + greet)

	print("[펫 구매 / 먹이]")
	economy.gold = 1000000.0
	var cat: PetData = pets.buy_pet("cat")
	check(cat != null and pets.pets.size() == 2, "고양이 구매")
	check(pets.pet_price("cat") > 150.0, "구매할수록 가격 상승")
	check(pets.buy_pet("tiger") == null, "미발견 합성 펫은 구매 불가")
	cat.hunger = 80.0
	check(pets.feed(cat.uid, "kibble") and cat.hunger < 80.0, "사료 주기")
	check(cat.activity == "eat", "먹이 후 밥 먹는 행동")

	print("[가구 / 행동]")
	check(house.buy_furniture("bed"), "침대 구매")
	check(not house.buy_furniture("cat_tower") or house.house_level >= 10, "캣타워는 펫집 Lv.10 필요")
	var saw_sleep := false
	for i in 300:
		pets.choose_activity(dog)
		if dog.activity == "sleep":
			saw_sleep = true
			break
	check(saw_sleep, "침대가 있으면 잠자는 행동 등장")
	var saw_study := false
	focus.start_session(30)
	for i in 50:
		pets.choose_activity(dog)
		if dog.activity == "cheer" or dog.activity == "study":
			saw_study = true
			break
	focus.stop_session()
	check(saw_study, "집중 중에는 응원/같이 공부 행동")

	print("[펫집 확장]")
	dog.level = 9
	cat.level = 3
	house.update_level(pets.total_levels())
	check(house.stage_index() == 1, "레벨 합 12 → 두 번째 방")
	check(house.pet_capacity() == 5, "수용량 5")

	print("[합성]")
	dog.level = 10
	cat.level = 10
	house.update_level(pets.total_levels())
	var rabbit: PetData = pets.add_pet("rabbit", "shop", true)
	var fail: Dictionary = fusion.fuse(dog.uid, rabbit.uid)
	check(not fail["ok"] and pets.pets.size() == 3, "레시피 없는 조합은 실패 + 펫 유지")
	var count_before: int = pets.pets.size()
	var ok: Dictionary = fusion.fuse(dog.uid, cat.uid)
	check(ok["ok"], "강아지 + 고양이 합성 성공")
	check(pets.pets.size() == count_before - 1, "합성 재료 소모")
	check(collection.is_discovered("fox"), "여우 도감 등록")
	check(fusion.learned.has("fox"), "레시피 학습")
	check(house.house_level >= 20, "합성으로 펫이 줄어도 집 레벨 유지")

	print("[히든 펫]")
	var n_before: int = pets.pets.size()
	house.buy_furniture("bookshelf")
	house.buy_furniture("plant")
	check(collection.is_discovered("hedgehog"), "책장 + 화분 → 고슴도치 발견")
	check(pets.pets.size() == n_before + 1, "히든 펫 획득")

	print("[저장 / 불러오기]")
	var gold_before: float = economy.gold
	var pet_count: int = pets.pets.size()
	var placed_count: int = house.placed.size()
	check(save.save_game(), "저장")
	economy.reset()
	pets.reset()
	house.reset()
	collection.reset()
	fusion.reset()
	check(save.load_game(), "불러오기")
	check(approx(economy.gold, gold_before, 0.01), "골드 복원")
	check(pets.pets.size() == pet_count, "펫 복원")
	check(house.placed.size() == placed_count, "가구 복원")
	check(collection.is_discovered("hedgehog") and fusion.learned.has("fox"), "도감/레시피 복원")
	var rep: Dictionary = save._process_return(Clock.now() + 7200)
	check(rep["gold"] > 0.0 and rep["greeting"] != "", "재접속 리포트 + 인사: " + String(rep["greeting"]))
	save.delete_save()

	print("\n%d / %d checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
