extends SceneTree
## 데모 상태를 만들고 메인 화면 스크린샷을 저장한다 (개발용).
## 실행: xvfb-run godot -s tests/screenshot.gd -- --no-autoload-save <출력 경로> [탭 번호]

var _frames := 0
var _main: Node
var _out := "user://screenshot.png"
var _tab := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var args := OS.get_cmdline_user_args()
		if args.size() > 1:
			_out = args[1]
		if args.size() > 2:
			_tab = int(args[2])
		_setup_demo()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	elif _frames == 6 and _main:
		(_main.get("_tabs") as TabContainer).current_tab = _tab
		var pets: Node = root.get_node("PetManager")
		pets.say(pets.pets[0], "오늘도 열심히 하고 있네!")
	elif _frames == 400:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false


func _setup_demo() -> void:
	var save: Node = root.get_node("SaveManager")
	save.autosave_enabled = false
	save.new_game(Clock.now())
	var pets: Node = root.get_node("PetManager")
	var house: Node = root.get_node("HouseManager")
	root.get_node("Economy").gold = 54321.0
	pets.pets[0].level = 27
	pets.pets[0].affection = 90.0
	pets.pets[0].focus_minutes_together = 700.0
	for s in [["cat", 12], ["rabbit", 3], ["hamster", 55]]:
		var p: PetData = pets.add_pet(s[0], "shop", true)
		p.level = s[1]
		p.affection = 50.0
	house.update_level(pets.total_levels())
	for f in ["bed", "ball", "window", "bookshelf", "desk", "cat_tower", "plant", "cushion"]:
		house.buy_furniture(f)
	root.get_node("FocusManager").start_session(60)
