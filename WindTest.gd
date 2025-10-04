extends Node

# Тестовый скрипт для демонстрации системы ветра
func _ready() -> void:
	_test_wind_manager()

func _test_wind_manager() -> void:
	"""Тестирует WindManager"""
	
	var wind_manager_script = preload("res://scripts/WindManager.gd")
	var wind_manager = Node.new()
	wind_manager.set_script(wind_manager_script)
	add_child(wind_manager)
	
	# Подключаемся к сигналу изменения ветра
	wind_manager.wind_changed.connect(_on_test_wind_changed)
	

func _on_test_wind_changed(new_force: float) -> void:
	"""Обработчик изменения ветра в тесте"""
	var wind_manager = get_node("WindManager")
	if wind_manager:
		var direction = wind_manager.get_wind_direction()
		var strength = wind_manager.get_wind_strength()

func _input(event: InputEvent) -> void:
	"""Обработка ввода для тестирования"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				LevelData.set_current_level(3)
				GameStateManager.reset_for_level(3)
				get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
			KEY_H:
