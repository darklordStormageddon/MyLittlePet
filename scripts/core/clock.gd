class_name Clock
extends RefCounted
## 시간 유틸리티. 모든 시스템은 이 클래스를 통해 현재 시간을 얻는다.
## (테스트에서 debug_offset 으로 시간을 앞당길 수 있다)

static var debug_offset: int = 0


static func now() -> int:
	return int(Time.get_unix_time_from_system()) + debug_offset


static func _bias_sec() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## 로컬 날짜 키 "YYYY-MM-DD"
static func date_key(unix: int = -1) -> String:
	if unix < 0:
		unix = now()
	return Time.get_date_string_from_unix_time(unix + _bias_sec())


static func local_hour(unix: int = -1) -> int:
	if unix < 0:
		unix = now()
	return int(Time.get_datetime_dict_from_unix_time(unix + _bias_sec())["hour"])


static func is_night(unix: int = -1) -> bool:
	var h := local_hour(unix)
	return h >= 22 or h < 6


## 시간대: morning / afternoon / evening / night
static func day_part(unix: int = -1) -> String:
	var h := local_hour(unix)
	if h >= 5 and h < 11:
		return "morning"
	if h >= 11 and h < 17:
		return "afternoon"
	if h >= 17 and h < 22:
		return "evening"
	return "night"
