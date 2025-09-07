extends Node
signal level_unlocked(level: int)

var highest_unlocked_level: int = 1
var current_level: int = 1
var score: int = 0

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	_load()

func reset_for_level(level: int) -> void:
	current_level = level
	score = 0

func add_score(delta: int) -> void:
	score += delta

func unlock_level(level: int) -> void:
	if level > highest_unlocked_level:
		highest_unlocked_level = level
		_save()
		emit_signal("level_unlocked", level)

func is_unlocked(level: int) -> bool:
	return level <= highest_unlocked_level

func _save() -> void:
	var data := {
		"highest_unlocked_level": highest_unlocked_level
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var txt := f.get_as_text()
		var res: Variant = JSON.parse_string(txt)
		if typeof(res) == TYPE_DICTIONARY and res.has("highest_unlocked_level"):
			highest_unlocked_level = int(res["highest_unlocked_level"])
