extends Node
## 시스템 ↔ UI 사이의 전역 시그널.

signal toast(text: String)
signal pet_speech(uid: int, text: String)
signal pet_level_up(uid: int, new_level: int)
signal pet_stage_up(uid: int, stage: int)
signal pets_changed
signal furniture_changed
signal house_level_changed(level: int)
signal species_discovered(species_id: String, how: String)
signal focus_started(target_min: int)
signal focus_finished(result: Dictionary)
signal recipe_learned(recipe_id: String)
signal game_loaded
