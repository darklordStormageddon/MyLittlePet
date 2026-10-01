class_name PetArt
extends RefCounted
## 펫 그리기 (플레이스홀더 아트). 성장 단계에 따라 외형이 변한다 (기획안 14).
## 0 아기: 작고 동글 / 1 어린이: 조금 커짐 / 2 청소년: 리본 장식 / 3 성체: 꼬리, 큰 체형 / 4 특수 외형: 왕관 + 반짝임

const OUTLINE := Color(0.25, 0.18, 0.15)
const CHEEK := Color(1.0, 0.55, 0.6, 0.55)


## feet: 발 위치(바닥 중앙), radius: 기본 반지름(단계 배율 적용 전)
## opts: {"stage", "closed", "look_dir"(Vector2), "glasses", "facing"(1/-1), "silhouette", "time", "rot"}
static func draw_pet(ci: CanvasItem, feet: Vector2, radius: float, species_id: String, opts: Dictionary = {}) -> void:
	var look: Dictionary = PetDB.get_species(species_id)["look"]
	var stage := int(opts.get("stage", 0))
	var silhouette := bool(opts.get("silhouette", false))
	var facing := float(opts.get("facing", 1.0))
	var t := float(opts.get("time", 0.0))
	var r := radius * float(Balance.GROWTH_STAGES[stage]["scale"])
	var body: Color = Color(0.15, 0.15, 0.2) if silhouette else look["color"]
	var accent: Color = Color(0.15, 0.15, 0.2) if silhouette else look["accent"]
	var ears := String(look.get("ears", "round"))
	# 아기일수록 머리가 크고 동글동글
	var squash := 1.0 - 0.08 * float(4 - stage)
	var center := feet + Vector2(0, -r * squash)

	ci.draw_set_transform(feet, float(opts.get("rot", 0.0)), Vector2.ONE)
	center -= feet

	# 꼬리 (성체 이상)
	if stage >= 3 and ears != "beak":
		var tail_base := center + Vector2(-r * 0.9 * facing, r * 0.3)
		var tail_tip := tail_base + Vector2(-r * 0.5 * facing, -r * (0.5 + 0.1 * sin(t * 4.0)))
		ci.draw_line(tail_base, tail_tip, accent if species_id in ["fox", "ninetail", "tiger"] else body, r * 0.28, true)
		if species_id == "ninetail":
			for i in 3:
				var off := Vector2(-r * (0.3 + 0.2 * i) * facing, -r * (0.2 + 0.25 * i))
				ci.draw_line(tail_base, tail_base + off, accent, r * 0.18, true)

	# 귀
	match ears:
		"pointy":
			for s in [-1.0, 1.0]:
				var base := center + Vector2(s * r * 0.55, -r * 0.55)
				ci.draw_colored_polygon(PackedVector2Array([
					base + Vector2(-r * 0.3, 0), base + Vector2(s * r * 0.15, -r * 0.6), base + Vector2(r * 0.3, 0)]), body)
				if not silhouette:
					ci.draw_colored_polygon(PackedVector2Array([
						base + Vector2(-r * 0.15, -r * 0.05), base + Vector2(s * r * 0.12, -r * 0.42), base + Vector2(r * 0.15, -r * 0.05)]), accent)
		"floppy":
			for s in [-1.0, 1.0]:
				_ellipse(ci, center + Vector2(s * r * 0.85, -r * 0.2), Vector2(r * 0.28, r * 0.5), accent)
		"long":
			for s in [-1.0, 1.0]:
				var tilt := 0.15 * sin(t * 2.0 + s)
				_ellipse(ci, center + Vector2(s * r * 0.35 + tilt * r, -r * 1.15), Vector2(r * 0.2, r * 0.6), body)
				if not silhouette:
					_ellipse(ci, center + Vector2(s * r * 0.35 + tilt * r, -r * 1.1), Vector2(r * 0.09, r * 0.45), accent)
		"round":
			for s in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(s * r * 0.62, -r * 0.62), r * 0.28, body)
				if not silhouette:
					ci.draw_circle(center + Vector2(s * r * 0.62, -r * 0.62), r * 0.15, accent)
		"horn":
			var hb := center + Vector2(0, -r * 0.85)
			ci.draw_colored_polygon(PackedVector2Array([hb + Vector2(-r * 0.15, 0), hb + Vector2(0, -r * 0.6), hb + Vector2(r * 0.15, 0)]),
				Color(1.0, 0.85, 0.3) if not silhouette else body)

	# 몸통
	_ellipse(ci, center, Vector2(r, r * squash), body)
	if species_id == "turtle" and not silhouette:
		_ellipse(ci, center + Vector2(-r * 0.15 * facing, -r * 0.25), Vector2(r * 0.8, r * 0.55), accent)
		for i in 3:
			ci.draw_circle(center + Vector2((-r * 0.45 + r * 0.3 * i) * facing, -r * 0.35), r * 0.12, body.darkened(0.2))
	# 배 / 무늬
	if not silhouette:
		if bool(look.get("stripes", false)):
			for i in 3:
				var x := (-0.4 + 0.4 * i) * r
				ci.draw_line(center + Vector2(x, -r * 0.95), center + Vector2(x, -r * 0.65), accent, r * 0.1)
		if ears != "beak" and species_id != "turtle":
			_ellipse(ci, center + Vector2(0, r * 0.45 * squash), Vector2(r * 0.55, r * 0.4), accent.lerp(Color.WHITE, 0.4))

	if silhouette:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# 얼굴
	var face := center + Vector2(r * 0.12 * facing, -r * 0.1)
	var look_dir: Vector2 = opts.get("look_dir", Vector2.ZERO)
	var eye_off := r * 0.36
	if bool(look.get("mask", false)):
		for s in [-1.0, 1.0]:
			_ellipse(ci, face + Vector2(s * eye_off, 0), Vector2(r * 0.22, r * 0.17), accent)
	for s in [-1.0, 1.0]:
		var e := face + Vector2(s * eye_off, 0) + look_dir * r * 0.08
		if bool(opts.get("closed", false)):
			ci.draw_line(e + Vector2(-r * 0.1, 0), e + Vector2(r * 0.1, 0), OUTLINE, maxf(1.5, r * 0.06))
		else:
			ci.draw_circle(e, r * 0.1, Color.WHITE if bool(look.get("mask", false)) and species_id != "panda" else OUTLINE)
			if bool(look.get("mask", false)) and species_id != "panda":
				ci.draw_circle(e, r * 0.06, OUTLINE)
			ci.draw_circle(e + Vector2(-r * 0.03, -r * 0.03), r * 0.035, Color.WHITE)
		ci.draw_circle(face + Vector2(s * r * 0.55, r * 0.2), r * 0.11, CHEEK)
	if ears == "beak":
		ci.draw_colored_polygon(PackedVector2Array([face + Vector2(-r * 0.14, r * 0.12),
			face + Vector2(r * 0.14, r * 0.12), face + Vector2(r * 0.25 * facing, r * 0.22)]), accent)
	else:
		ci.draw_circle(face + Vector2(0, r * 0.15), r * 0.06, OUTLINE)
		ci.draw_arc(face + Vector2(-r * 0.06, r * 0.22), r * 0.06, 0.0, PI, 8, OUTLINE, maxf(1.0, r * 0.04))
		ci.draw_arc(face + Vector2(r * 0.06, r * 0.22), r * 0.06, 0.0, PI, 8, OUTLINE, maxf(1.0, r * 0.04))

	# 함께 공부한 시간이 쌓이면 생기는 공부 안경 (기억 → 외형 변화)
	if bool(opts.get("glasses", false)):
		for s in [-1.0, 1.0]:
			ci.draw_arc(face + Vector2(s * eye_off, 0), r * 0.18, 0, TAU, 16, OUTLINE, maxf(1.0, r * 0.05))
		ci.draw_line(face + Vector2(-eye_off + r * 0.18, 0), face + Vector2(eye_off - r * 0.18, 0), OUTLINE, maxf(1.0, r * 0.05))

	# 청소년 이상: 리본
	if stage >= 2:
		var bow := center + Vector2(r * 0.55 * facing, -r * 0.75)
		var red := Color(0.92, 0.3, 0.4)
		ci.draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-r * 0.25, -r * 0.15), bow + Vector2(-r * 0.25, r * 0.15)]), red)
		ci.draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(r * 0.25, -r * 0.15), bow + Vector2(r * 0.25, r * 0.15)]), red)
		ci.draw_circle(bow, r * 0.07, red.darkened(0.2))
	# 특수 외형: 왕관 + 반짝임
	if stage >= 4:
		var c := center + Vector2(0, -r * 1.05)
		var gold := Color(1.0, 0.82, 0.2)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, 0), c + Vector2(-r * 0.35, -r * 0.3),
			c + Vector2(-r * 0.17, -r * 0.12), c + Vector2(0, -r * 0.38), c + Vector2(r * 0.17, -r * 0.12),
			c + Vector2(r * 0.35, -r * 0.3), c + Vector2(r * 0.35, 0)]), gold)
		for i in 3:
			var a := t * 1.5 + TAU * i / 3.0
			var p := center + Vector2(cos(a) * r * 1.4, sin(a) * r * 0.8 - r * 0.3)
			_sparkle(ci, p, r * 0.15, Color(1.0, 0.95, 0.5, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_colored_polygon(pts, color)


static func _sparkle(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 2), c + Vector2(s * 0.5, 0), c + Vector2(0, s * 2), c + Vector2(-s * 0.5, 0)]), color)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 2, 0), c + Vector2(0, s * 0.5), c + Vector2(s * 2, 0), c + Vector2(0, -s * 0.5)]), color)


static func draw_heart(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.5, 0), s * 0.55, color)
	ci.draw_circle(c + Vector2(s * 0.5, 0), s * 0.55, color)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, s * 0.2), c + Vector2(s * 1.02, s * 0.2), c + Vector2(0, s * 1.3)]), color)
