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
				LevelData.start_level(1)
			KEY_2:
				LevelData.start_level(2)
			KEY_3:
				LevelData.start_level(3)
			KEY_H:
