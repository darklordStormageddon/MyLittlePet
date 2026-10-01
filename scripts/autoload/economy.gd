extends Node
## 재화(골드) 시스템 (기획안 15).
## 펫은 플레이어가 보고 있지 않아도 계속 재화를 생산한다.

var gold: float = 0.0
var total_produced: float = 0.0 ## "현재까지 N골드를 생산했습니다."
var total_spent: float = 0.0
var pending_offline_gold: float = 0.0 ## 자리를 비운 동안 생산된, 아직 수령하지 않은 골드


func reset() -> void:
	gold = 100.0
	total_produced = 0.0
	total_spent = 0.0
	pending_offline_gold = 0.0


## 펫 생산으로 들어온 골드
func add_production(amount: float) -> void:
	if amount <= 0.0:
		return
	gold += amount
	total_produced += amount
	ActivityLog.record_gold(amount)


## 오프라인 생산분은 '수령' 전까지 보관한다 (기획안 18: 생산된 골드 수령)
func add_offline_production(amount: float) -> void:
	if amount <= 0.0:
		return
	pending_offline_gold += amount
	total_produced += amount
	ActivityLog.record_gold(amount)


func claim_offline_gold() -> float:
	var amount := pending_offline_gold
	gold += amount
	pending_offline_gold = 0.0
	return amount


func can_afford(amount: float) -> bool:
	return gold + 0.0001 >= amount


func spend(amount: float) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	total_spent += amount
	return true


func to_dict() -> Dictionary:
	return {"gold": gold, "total_produced": total_produced, "total_spent": total_spent,
		"pending_offline_gold": pending_offline_gold}


func from_dict(d: Dictionary) -> void:
	gold = float(d.get("gold", 0.0))
	total_produced = float(d.get("total_produced", 0.0))
	total_spent = float(d.get("total_spent", 0.0))
	pending_offline_gold = float(d.get("pending_offline_gold", 0.0))
