extends Node

# Демонстрационный скрипт для тестирования системы превью уровней
# Этот скрипт можно прикрепить к любой сцене для тестирования

func _ready() -> void:
	_demo_level_data()

func _demo_level_data() -> void:
	"""Демонстрирует работу с данными уровней"""
	
	
	for i in range(1, LevelData.get_total_levels() + 1):
		var level_info = LevelData.get_level_info(i)
	
	LevelData.set_current_level(2)
	var current = LevelData.get_current_level_info()
	

func _input(event: InputEvent) -> void:
	"""Обработка ввода для демонстрации"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				LevelData.set_current_level(1)
				GameStateManager.reset_for_level(1)
				get_tree().change_scene_to_file("res://scenes/Game.tscn")
			KEY_2:
				LevelData.set_current_level(2)
				GameStateManager.reset_for_level(2)
				get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
			KEY_3:
				LevelData.set_current_level(3)
				GameStateManager.reset_for_level(3)
				get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
			KEY_H:
