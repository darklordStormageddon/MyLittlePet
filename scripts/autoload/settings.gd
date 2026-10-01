extends Node
## 화면 설정 (UI 크기, PiP 창 위치/크기/투명도). 게임 세이브와 별도로 user://settings.cfg 에 저장한다.

const PATH := "user://settings.cfg"
const UI_SCALE_MIN := 0.7
const UI_SCALE_MAX := 1.4
const PIP_DEFAULT_SIZE := Vector2i(420, 300)
const PIP_MIN_SIZE := Vector2i(200, 140)

var ui_scale: float = 1.0
var split_offset: int = 0
var pip_position: Vector2i = Vector2i(-1, -1) ## (-1, -1) = 화면 오른쪽 아래 기본 위치
var pip_size: Vector2i = PIP_DEFAULT_SIZE
var pip_opacity: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	ui_scale = clampf(float(cfg.get_value("ui", "scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
	split_offset = int(cfg.get_value("ui", "split_offset", 0))
	pip_position = cfg.get_value("pip", "position", Vector2i(-1, -1))
	pip_size = cfg.get_value("pip", "size", PIP_DEFAULT_SIZE)
	pip_size = Vector2i(maxi(pip_size.x, PIP_MIN_SIZE.x), maxi(pip_size.y, PIP_MIN_SIZE.y))
	pip_opacity = clampf(float(cfg.get_value("pip", "opacity", 1.0)), 0.3, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "scale", ui_scale)
	cfg.set_value("ui", "split_offset", split_offset)
	cfg.set_value("pip", "position", pip_position)
	cfg.set_value("pip", "size", pip_size)
	cfg.set_value("pip", "opacity", pip_opacity)
	cfg.save(PATH)


func step_ui_scale(delta: float) -> float:
	ui_scale = clampf(snappedf(ui_scale + delta, 0.05), UI_SCALE_MIN, UI_SCALE_MAX)
	save_settings()
	return ui_scale
