class_name DialogueDB
extends RefCounted
## 펫 대사 (기획안 4, 6, 13, 18).
## 각 대사는 [필요 애정도, 문장]. 애정도가 높아질수록 고를 수 있는 대사가 늘어난다.
## {name} 펫 이름, {n} 숫자, {time} 시간 문자열 치환.

const LINES := {
	# --- 접속 인사 (기억 시스템) ---
	"greet_long_absence": [
		[0.0, "어디 갔다 왔어?"],
		[40.0, "어디 갔다 왔어? 계속 기다렸어."],
		[75.0, "드디어 왔다! 보고 싶었어!"],
	],
	"greet_streak": [
		[0.0, "우리 같이 {n}일째야!"],
		[50.0, "우리 같이 {n}일째야! 오늘도 같이 하자!"],
	],
	"greet_long_focus_today": [
		[0.0, "오늘 오래 공부했네!"],
		[50.0, "오늘 {time}이나 집중했어! 진짜 대단해!"],
	],
	"greet_long_focus_yesterday": [
		[0.0, "어제 정말 열심히 했지?"],
		[50.0, "어제 열심히 한 덕분에 나도 쑥쑥 컸어!"],
	],
	"greet_busy": [
		[0.0, "요즘 바쁜가 봐..."],
		[50.0, "요즘 바쁜가 봐... 시간 나면 같이 집중하자!"],
	],
	"greet_morning": [
		[0.0, "잘 잤어?"],
		[40.0, "좋은 아침! 잘 잤어?"],
	],
	"greet_afternoon": [
		[0.0, "왔구나!"],
		[40.0, "오늘 하루 잘 보내고 있어?"],
	],
	"greet_evening": [
		[0.0, "오늘 하루 어땠어?"],
		[40.0, "오늘도 수고 많았어!"],
	],
	"greet_night": [
		[0.0, "늦었는데 아직 안 자?"],
		[40.0, "늦게까지 고생이 많아. 무리하지 마!"],
	],
	"greet_regular": [
		[60.0, "오늘도 왔네!"],
		[80.0, "오늘도 와줬구나! 기다렸어!"],
	],
	# --- 집중 세션 ---
	"focus_start": [
		[0.0, "같이 집중해 보자!"],
		[30.0, "좋아, 나도 옆에서 같이 할게!"],
		[70.0, "오늘도 같이 힘내자! 화이팅!"],
	],
	"focus_cheer": [
		[0.0, "오늘도 열심히 하고 있네!"],
		[0.0, "{time}째 집중 중! 대단해!"],
		[30.0, "나도 옆에서 같이 하는 중이야."],
		[60.0, "조금만 더 힘내! 나 계속 여기 있어."],
	],
	"focus_done": [
		[0.0, "수고했어! 나도 같이 컸어!"],
		[40.0, "{time} 동안 같이 했어! 고마워!"],
		[75.0, "오늘 너랑 같이 해서 정말 좋았어!"],
	],
	"focus_short": [
		[0.0, "조금 쉬었다가 다시 해보자!"],
	],
	# --- 상호작용 ---
	"pet": [
		[0.0, "히히, 간지러워!"],
		[0.0, "좋아!"],
		[30.0, "더 쓰다듬어 줘!"],
		[50.0, "너 손이 제일 좋아."],
		[80.0, "우리 평생 친구 하자!"],
	],
	"feed": [
		[0.0, "냠냠! 맛있어!"],
		[40.0, "역시 네가 주는 밥이 최고야!"],
	],
	"treat": [
		[0.0, "간식이다!!"],
		[50.0, "와! 내가 제일 좋아하는 거!"],
	],
	"level_up": [
		[0.0, "레벨업했어!"],
		[0.0, "나 조금 더 컸어!"],
		[50.0, "봐봐! 나 또 컸어!"],
	],
	"stage_up": [
		[0.0, "나 모습이 바뀌었어! 어때?"],
	],
	"hungry": [
		[0.0, "배고파..."],
		[40.0, "밥 먹고 싶다~"],
	],
	"idle_chat": [
		[20.0, "오늘 날씨 좋다~"],
		[30.0, "뭐 하고 있어?"],
		[45.0, "같이 있으니까 좋다."],
		[60.0, "내일이면 나 더 크려나?"],
		[75.0, "너랑 사는 이 집이 제일 좋아."],
	],
	"born": [
		[0.0, "안녕! 잘 부탁해!"],
	],
}


static func pick(key: String, affection: float, params: Dictionary = {}) -> String:
	var pool: Array = []
	for entry in LINES.get(key, []):
		if affection >= float(entry[0]):
			pool.append(String(entry[1]))
	if pool.is_empty():
		return ""
	# 애정도가 높을수록 최근에 해금된(뒤쪽) 대사를 고를 확률이 높아진다
	var idx := randi() % pool.size()
	if pool.size() > 1 and randf() < clampf(affection / 100.0, 0.0, 0.7):
		idx = pool.size() - 1 - (randi() % mini(2, pool.size()))
	return format_line(pool[idx], params)


static func format_line(text: String, params: Dictionary) -> String:
	for k in params:
		text = text.replace("{%s}" % k, str(params[k]))
	return text
