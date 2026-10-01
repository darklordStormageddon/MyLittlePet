class_name ActivityDB
extends RefCounted
## 펫의 일상 행동 (기획안 8). 펫은 플레이어 조작 없이 스스로 행동을 고른다.
## furniture: 필요한 가구 id ("" = 필요 없음)
## weight: 기본 선택 가중치, duration: [최소, 최대] 초, mood: 행동 시작 시 기분 변화
## min_affection: 애정도 조건 (애정도가 오르면 새 행동이 해금된다)
## anim: 뷰에서 사용할 애니메이션 종류

const ACTIVITIES := {
	"wander": {"text": "집 안을 어슬렁거리는 중", "furniture": "", "weight": 3.0, "duration": [4.0, 8.0], "mood": 0.5, "anim": "walk"},
	"idle": {"text": "멍하니 앉아 있는 중", "furniture": "", "weight": 2.0, "duration": [4.0, 9.0], "mood": 0.0, "anim": "idle"},
	"look_player": {"text": "나를 바라보는 중", "furniture": "", "weight": 1.0, "duration": [3.0, 6.0], "mood": 1.0, "anim": "look"},
	"play_pet": {"text": "{other}와(과) 노는 중", "furniture": "", "weight": 2.0, "duration": [6.0, 10.0], "mood": 4.0, "anim": "jump"},
	"beg": {"text": "배고파서 밥그릇 앞을 서성이는 중", "furniture": "food_bowl", "weight": 0.0, "duration": [5.0, 8.0], "mood": 0.0, "anim": "idle"},
	"eat": {"text": "냠냠 밥 먹는 중", "furniture": "food_bowl", "weight": 0.0, "duration": [5.0, 6.0], "mood": 3.0, "anim": "eat"},
	"sleep": {"text": "침대에서 새근새근 자는 중", "furniture": "bed", "weight": 2.0, "duration": [12.0, 25.0], "mood": 3.0, "anim": "sleep"},
	"nap": {"text": "쿠션 위에서 뒹구는 중", "furniture": "cushion", "weight": 2.0, "duration": [6.0, 12.0], "mood": 2.0, "anim": "sleep"},
	"play_ball": {"text": "공을 굴리며 노는 중", "furniture": "ball", "weight": 3.0, "duration": [5.0, 9.0], "mood": 5.0, "anim": "jump"},
	"look_window": {"text": "창밖을 바라보는 중", "furniture": "window", "weight": 2.5, "duration": [6.0, 12.0], "mood": 2.0, "anim": "look_away"},
	"sniff_plant": {"text": "화분 냄새를 맡는 중", "furniture": "plant", "weight": 2.0, "duration": [3.0, 6.0], "mood": 1.5, "anim": "idle"},
	"read": {"text": "책장 앞에 앉아 책을 보는 중", "furniture": "bookshelf", "weight": 2.5, "duration": [8.0, 14.0], "mood": 2.0, "anim": "read"},
	"study": {"text": "책상에서 같이 공부하는 중", "furniture": "desk", "weight": 0.5, "duration": [10.0, 20.0], "mood": 2.0, "anim": "read", "focus_weight": 12.0},
	"cheer": {"text": "옆에서 응원하는 중", "furniture": "", "weight": 0.0, "duration": [6.0, 10.0], "mood": 2.0, "anim": "jump", "focus_weight": 4.0},
	"climb": {"text": "캣타워 꼭대기에 올라간 중", "furniture": "cat_tower", "weight": 2.5, "duration": [8.0, 14.0], "mood": 4.0, "anim": "climb"},
	"play_piano": {"text": "피아노를 똥땅거리는 중", "furniture": "piano", "weight": 1.5, "duration": [6.0, 10.0], "mood": 5.0, "anim": "jump", "min_affection": 40.0},
	"stargaze": {"text": "망원경으로 별을 보는 중", "furniture": "telescope", "weight": 0.0, "duration": [10.0, 16.0], "mood": 4.0, "anim": "look_away", "night_weight": 4.0},
	"swim": {"text": "수영장에서 첨벙첨벙 노는 중", "furniture": "pool", "weight": 2.5, "duration": [8.0, 14.0], "mood": 6.0, "anim": "jump"},
	"dance": {"text": "신나서 춤추는 중", "furniture": "", "weight": 1.0, "duration": [4.0, 7.0], "mood": 5.0, "anim": "dance", "min_affection": 60.0},
	"heart": {"text": "나에게 하트를 보내는 중", "furniture": "", "weight": 0.6, "duration": [3.0, 5.0], "mood": 3.0, "anim": "heart", "min_affection": 85.0},
}


static func get_def(id: String) -> Dictionary:
	return ACTIVITIES.get(id, ACTIVITIES["idle"])


static func describe(id: String, other_name: String = "") -> String:
	return String(get_def(id)["text"]).replace("{other}", other_name)


## 가구를 배치하면 새로 생기는 행동 이름 목록 (UI 설명용)
static func names_for_furniture(furniture_id: String) -> Array:
	var out: Array = []
	for id in ACTIVITIES:
		if ACTIVITIES[id]["furniture"] == furniture_id:
			out.append(String(ACTIVITIES[id]["text"]))
	return out
