extends Control
## 도감/팝업용 펫 초상화. 미발견 펫은 실루엣으로 표시한다.

var species: String = "dog"
var stage: int = 3
var silhouette: bool = false
var glasses: bool = false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if stage >= 4:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var radius := size.y * 0.32 / float(Balance.GROWTH_STAGES[stage]["scale"]) * 0.9
	PetArt.draw_pet(self, Vector2(size.x * 0.5, size.y - 4), radius, species,
		{"stage": stage, "silhouette": silhouette, "glasses": glasses, "time": _time})
