extends Node
## 저장 / 불러오기 / 오프라인 진행 (기획안 15, 18, 20).
## 게임을 꺼두어도 펫은 계속 생산/성장하며, 다시 켜면 그동안의 결과와 펫의 인사(기억 시스템)를 보여준다.

const SAVE_VERSION := 1
const AUTOSAVE_SEC := 30.0

var save_path := "user://mylittlepet_save.json"
var loaded := false
## 접속 시 UI가 읽어가는 리포트: {away_sec, gold, levels, greeting, pet_uid, focus_result, new_game}
var startup_report: Dictionary = {}
var autosave_enabled := true

var _autosave_timer := 0.0


func _ready() -> void:
	# 테스트 실행 시에는 자동 로드하지 않는다
	if OS.get_cmdline_user_args().has("--no-autoload-save"):
		return
	start()


func start() -> void:
	var now := Clock.now()
	if not load_game():
		new_game(now)
	startup_report = _process_return(now)
	EventBus.game_loaded.emit()


func _process(delta: float) -> void:
	if not loaded or not autosave_enabled:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SEC:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if not loaded or not autosave_enabled:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func new_game(now: int) -> void:
	Economy.reset()
	ActivityLog.reset(now)
	FocusManager.reset()
	PetManager.reset()
	HouseManager.reset()
	Collection.reset()
	FusionManager.reset()
	loaded = true
	var pet := PetManager.add_pet("dog", "starter", true)
	pet.nickname = "몽이"
	pet.affection = 15.0
	startup_report = {}


## 저장 시점부터 지금까지의 시간을 처리하고 접속 리포트를 만든다.
func _process_return(now: int) -> Dictionary:
	var is_new := ActivityLog.total_sessions == 0 and now - ActivityLog.first_play < 5
	var last_seen := ActivityLog.last_seen
	var away := maxi(0, now - last_seen)
	var offline := PetManager.simulate_offline(last_seen, now)
	# 앱이 꺼져 있는 동안 끝난 집중 세션은 오프라인 성장 계산 후 보상 처리
	var focus_result := FocusManager.resume_after_load(now)
	ActivityLog.record_login(now)
	ActivityLog.touch(now)
	Collection.check_hidden()

	var report := {"away_sec": away, "gold": float(offline["gold"]), "levels": offline["levels"],
		"total_levels": int(offline["total_levels"]), "focus_result": focus_result, "new_game": is_new,
		"greeting": "", "pet_uid": -1}
	var pet := _favorite_pet()
	if pet:
		report["pet_uid"] = pet.uid
		report["greeting"] = DialogueDB.pick("born", pet.affection) if is_new \
			else ActivityLog.build_greeting(pet, away, now)
	return report


func _favorite_pet() -> PetData:
	var best: PetData = null
	for pet in PetManager.pets:
		if best == null or pet.affection > best.affection:
			best = pet
	return best


func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Clock.now(),
		"economy": Economy.to_dict(),
		"activity_log": ActivityLog.to_dict(),
		"focus": FocusManager.to_dict(),
		"pets": PetManager.to_dict(),
		"house": HouseManager.to_dict(),
		"collection": Collection.to_dict(),
		"fusion": FusionManager.to_dict(),
	}


func apply_save_data(data: Dictionary) -> void:
	Economy.from_dict(data.get("economy", {}))
	ActivityLog.from_dict(data.get("activity_log", {}))
	ActivityLog.last_seen = int(data.get("saved_at", ActivityLog.last_seen))
	FocusManager.from_dict(data.get("focus", {}))
	PetManager.from_dict(data.get("pets", {}))
	HouseManager.from_dict(data.get("house", {}))
	Collection.from_dict(data.get("collection", {}))
	FusionManager.from_dict(data.get("fusion", {}))
	loaded = true


func save_game() -> bool:
	if not loaded:
		return false
	ActivityLog.touch(Clock.now())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(build_save_data()))
	file.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("세이브 파일이 손상되어 새 게임을 시작합니다.")
		return false
	apply_save_data(data)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
