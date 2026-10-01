class_name PetDB
extends RefCounted
## 펫 종 데이터 (기획안 10, 11, 12).
## prod / growth / affection: 생산량, 성장 속도, 애정도 상승 별(1~5)
## source: "shop"(기본 펫), "fusion"(합성 전용), "hidden"(히든 조건 달성)
## look: 그리기용 외형 정보 (ears: pointy/floppy/long/round/beak/horn/none)

const SPECIES := {
	# --- 기본 펫 ---
	"dog": {"name": "강아지", "prod": 3, "growth": 3, "affection": 4, "price": 100.0, "source": "shop",
		"desc": "누구와도 금방 친해지는 다정한 친구.",
		"look": {"color": Color(0.88, 0.68, 0.45), "accent": Color(0.6, 0.4, 0.22), "ears": "floppy"}},
	"cat": {"name": "고양이", "prod": 3, "growth": 2, "affection": 4, "price": 150.0, "source": "shop",
		"desc": "높은 곳을 좋아하는 도도한 고양이.",
		"look": {"color": Color(0.95, 0.75, 0.45), "accent": Color(0.85, 0.55, 0.25), "ears": "pointy"}},
	"rabbit": {"name": "토끼", "prod": 2, "growth": 4, "affection": 3, "price": 150.0, "source": "shop",
		"desc": "쑥쑥 자라는 깡총 토끼.",
		"look": {"color": Color(0.97, 0.95, 0.95), "accent": Color(0.95, 0.7, 0.75), "ears": "long"}},
	"hamster": {"name": "햄스터", "prod": 4, "growth": 2, "affection": 2, "price": 250.0, "source": "shop",
		"desc": "볼주머니 가득 재화를 모아오는 일꾼.",
		"look": {"color": Color(0.96, 0.82, 0.6), "accent": Color(1.0, 0.95, 0.88), "ears": "round"}},
	"chick": {"name": "병아리", "prod": 2, "growth": 3, "affection": 3, "price": 80.0, "source": "shop",
		"desc": "삐약삐약 노란 병아리.",
		"look": {"color": Color(1.0, 0.9, 0.35), "accent": Color(1.0, 0.6, 0.2), "ears": "beak"}},

	# --- 합성 펫 ---
	"tiger": {"name": "호랑이", "prod": 4, "growth": 3, "affection": 3, "price": 3000.0, "source": "fusion",
		"desc": "고양이와 토끼의 용기가 만나 태어난 아기 호랑이.",
		"look": {"color": Color(1.0, 0.62, 0.2), "accent": Color(0.25, 0.18, 0.12), "ears": "round", "stripes": true}},
	"fox": {"name": "여우", "prod": 3, "growth": 4, "affection": 3, "price": 2500.0, "source": "fusion",
		"desc": "영리하고 눈치 빠른 여우.",
		"look": {"color": Color(0.95, 0.5, 0.2), "accent": Color(1.0, 1.0, 1.0), "ears": "pointy"}},
	"raccoon": {"name": "너구리", "prod": 4, "growth": 3, "affection": 2, "price": 2500.0, "source": "fusion",
		"desc": "뭐든 주워오는 수집가.",
		"look": {"color": Color(0.55, 0.52, 0.5), "accent": Color(0.2, 0.2, 0.22), "ears": "round", "mask": true}},
	"squirrel": {"name": "다람쥐", "prod": 3, "growth": 4, "affection": 3, "price": 2500.0, "source": "fusion",
		"desc": "도토리를 열심히 모으는 다람쥐.",
		"look": {"color": Color(0.75, 0.45, 0.25), "accent": Color(0.95, 0.85, 0.7), "ears": "pointy"}},
	"duck": {"name": "오리", "prod": 3, "growth": 3, "affection": 4, "price": 2000.0, "source": "fusion",
		"desc": "병아리들이 함께 자라 의젓한 오리가 되었다.",
		"look": {"color": Color(0.97, 0.97, 0.97), "accent": Color(1.0, 0.65, 0.15), "ears": "beak"}},
	"owl": {"name": "부엉이", "prod": 3, "growth": 3, "affection": 4, "price": 4000.0, "source": "fusion",
		"desc": "밤에만 모습을 드러내는 지혜로운 부엉이.",
		"look": {"color": Color(0.55, 0.42, 0.3), "accent": Color(0.95, 0.85, 0.5), "ears": "pointy"}},
	"panda": {"name": "판다", "prod": 5, "growth": 2, "affection": 4, "price": 12000.0, "source": "fusion",
		"desc": "느긋하지만 존재만으로 집을 풍요롭게 한다.",
		"look": {"color": Color(0.98, 0.98, 0.98), "accent": Color(0.12, 0.12, 0.12), "ears": "round", "mask": true}},
	"penguin": {"name": "펭귄", "prod": 4, "growth": 4, "affection": 3, "price": 9000.0, "source": "fusion",
		"desc": "뒤뚱뒤뚱, 수영장을 사랑하는 펭귄.",
		"look": {"color": Color(0.2, 0.22, 0.3), "accent": Color(1.0, 1.0, 1.0), "ears": "beak"}},
	"ninetail": {"name": "구미호", "prod": 5, "growth": 4, "affection": 5, "price": 30000.0, "source": "fusion",
		"desc": "깊은 애정 속에서만 깨어나는 신비한 여우.",
		"look": {"color": Color(1.0, 0.95, 0.85), "accent": Color(0.6, 0.4, 1.0), "ears": "pointy"}},
	"dragon": {"name": "아기 용", "prod": 5, "growth": 5, "affection": 4, "price": 100000.0, "source": "fusion",
		"desc": "전설 속 존재. 함께 자란 시간이 용을 깨웠다.",
		"look": {"color": Color(0.4, 0.8, 0.5), "accent": Color(1.0, 0.85, 0.3), "ears": "horn"}},

	# --- 히든 펫 ---
	"unicorn": {"name": "아기 유니콘", "prod": 5, "growth": 3, "affection": 4, "price": 50000.0, "source": "hidden",
		"desc": "어떤 펫이 성체가 되는 순간 찾아온 유니콘.",
		"look": {"color": Color(1.0, 0.96, 1.0), "accent": Color(1.0, 0.6, 0.85), "ears": "horn"}},
	"hedgehog": {"name": "고슴도치", "prod": 3, "growth": 3, "affection": 3, "price": 5000.0, "source": "hidden",
		"desc": "책과 식물이 있는 조용한 방을 좋아한다.",
		"look": {"color": Color(0.6, 0.48, 0.38), "accent": Color(0.95, 0.88, 0.75), "ears": "round"}},
	"bat": {"name": "꼬마 박쥐", "prod": 3, "growth": 4, "affection": 2, "price": 5000.0, "source": "hidden",
		"desc": "새벽에 깨어 있는 사람에게만 찾아온다.",
		"look": {"color": Color(0.35, 0.3, 0.45), "accent": Color(0.75, 0.6, 0.9), "ears": "pointy"}},
	"alpaca": {"name": "알파카", "prod": 4, "growth": 3, "affection": 5, "price": 20000.0, "source": "hidden",
		"desc": "최고의 애정을 받은 펫의 소문을 듣고 찾아왔다.",
		"look": {"color": Color(1.0, 0.96, 0.88), "accent": Color(0.85, 0.75, 0.6), "ears": "long"}},
	"turtle": {"name": "거북이", "prod": 4, "growth": 2, "affection": 4, "price": 8000.0, "source": "hidden",
		"desc": "느리지만 꾸준한 사람을 알아보는 거북이.",
		"look": {"color": Color(0.5, 0.75, 0.45), "accent": Color(0.45, 0.35, 0.2), "ears": "none"}},
	"golden_hamster": {"name": "황금 햄스터", "prod": 5, "growth": 3, "affection": 3, "price": 40000.0, "source": "hidden",
		"desc": "오래 키운 햄스터가 황금빛으로 빛나기 시작했다.",
		"look": {"color": Color(1.0, 0.82, 0.25), "accent": Color(1.0, 0.95, 0.6), "ears": "round"}},
	"koala": {"name": "코알라", "prod": 4, "growth": 3, "affection": 5, "price": 15000.0, "source": "hidden",
		"desc": "일주일 내내 함께한 당신에게 꼭 안겨온다.",
		"look": {"color": Color(0.68, 0.7, 0.74), "accent": Color(0.95, 0.95, 0.95), "ears": "round"}},
}

## 도감 정렬 순서
const ORDER := [
	"dog", "cat", "rabbit", "hamster", "chick",
	"fox", "tiger", "raccoon", "squirrel", "duck", "owl", "panda", "penguin", "ninetail", "dragon",
	"unicorn", "hedgehog", "bat", "alpaca", "turtle", "golden_hamster", "koala",
]


static func has(species_id: String) -> bool:
	return SPECIES.has(species_id)


static func get_species(species_id: String) -> Dictionary:
	return SPECIES.get(species_id, SPECIES["dog"])


static func display_name(species_id: String) -> String:
	return String(get_species(species_id)["name"])


static func shop_species() -> Array:
	var out: Array = []
	for id in ORDER:
		if SPECIES[id]["source"] == "shop":
			out.append(id)
	return out


static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)
