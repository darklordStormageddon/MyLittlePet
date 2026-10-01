class_name FurnitureDB
extends RefCounted
## 가구 데이터 (기획안 9).
## 가구는 스탯 아이템이 아니라 '펫의 행동을 추가하는 콘텐츠'다.
## activities: 이 가구가 배치되면 펫이 할 수 있게 되는 행동 id 목록 (ActivityDB 참고)

const FURNITURE := {
	"food_bowl": {"name": "밥그릇", "price": 0.0, "house_level": 1, "activities": ["beg"],
		"size": Vector2(36, 18), "color": Color(0.85, 0.35, 0.35), "desc": "배고플 때 펫이 기웃거린다."},
	"bed": {"name": "침대", "price": 200.0, "house_level": 1, "activities": ["sleep"],
		"size": Vector2(90, 40), "color": Color(0.55, 0.65, 0.95), "desc": "펫이 잠을 잔다."},
	"ball": {"name": "공", "price": 80.0, "house_level": 1, "activities": ["play_ball"],
		"size": Vector2(22, 22), "color": Color(0.95, 0.4, 0.4), "desc": "펫이 공을 가지고 논다."},
	"cushion": {"name": "쿠션", "price": 150.0, "house_level": 1, "activities": ["nap"],
		"size": Vector2(50, 18), "color": Color(0.95, 0.75, 0.85), "desc": "말랑한 쿠션 위에서 뒹군다."},
	"window": {"name": "창문", "price": 300.0, "house_level": 1, "activities": ["look_window"],
		"size": Vector2(70, 60), "color": Color(0.65, 0.85, 1.0), "wall": true, "desc": "창밖을 바라보는 행동이 추가된다."},
	"plant": {"name": "화분", "price": 250.0, "house_level": 1, "activities": ["sniff_plant"],
		"size": Vector2(30, 50), "color": Color(0.35, 0.7, 0.35), "desc": "초록 잎사귀 냄새를 킁킁."},
	"bookshelf": {"name": "책장", "price": 500.0, "house_level": 1, "activities": ["read"],
		"size": Vector2(60, 90), "color": Color(0.55, 0.38, 0.25), "desc": "펫이 책장 앞에 앉아 책을 본다."},
	"desk": {"name": "공부 책상", "price": 800.0, "house_level": 1, "activities": ["study"],
		"size": Vector2(80, 50), "color": Color(0.7, 0.55, 0.38), "desc": "집중 세션 중 펫이 책상에서 같이 공부한다."},
	"cat_tower": {"name": "캣타워", "price": 1200.0, "house_level": 10, "activities": ["climb"],
		"size": Vector2(50, 120), "color": Color(0.8, 0.7, 0.55), "desc": "높은 곳에 올라간다."},
	"piano": {"name": "피아노", "price": 5000.0, "house_level": 10, "activities": ["play_piano"],
		"size": Vector2(90, 70), "color": Color(0.15, 0.15, 0.18), "desc": "애정도가 높은 펫이 연주를 시도한다."},
	"telescope": {"name": "망원경", "price": 8000.0, "house_level": 25, "activities": ["stargaze"],
		"size": Vector2(40, 70), "color": Color(0.4, 0.4, 0.55), "desc": "밤이 되면 별을 본다."},
	"pool": {"name": "수영장", "price": 20000.0, "house_level": 50, "activities": ["swim"],
		"size": Vector2(140, 30), "color": Color(0.35, 0.7, 0.95), "desc": "첨벙첨벙 물놀이."},
}

const ORDER := ["food_bowl", "bed", "ball", "cushion", "window", "plant", "bookshelf", "desk",
	"cat_tower", "piano", "telescope", "pool"]


static func get_def(id: String) -> Dictionary:
	return FURNITURE.get(id, {})


static func display_name(id: String) -> String:
	return String(FURNITURE.get(id, {}).get("name", id))
