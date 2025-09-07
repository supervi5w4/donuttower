extends Node

# Демонстрационный скрипт для тестирования системы превью уровней
# Этот скрипт можно прикрепить к любой сцене для тестирования

func _ready() -> void:
	print("=== Демонстрация системы превью уровней ===")
	_demo_level_data()

func _demo_level_data() -> void:
	"""Демонстрирует работу с данными уровней"""
	
	print("\n🎮 === НОВЫЙ ИГРОВОЙ СТИЛЬ ЭКРАНА ПРЕВЬЮ ===")
	print("   Всего уровней: %d" % LevelData.get_total_levels())
	
	for i in range(1, LevelData.get_total_levels() + 1):
		var level_info = LevelData.get_level_info(i)
		print("\n   ✅ Уровень %d — «%s»" % [level_info.level_number, level_info.level_name])
		print("   📝 %s" % level_info.description)
		print("   %s" % level_info.cart_speed)
		print("   %s" % level_info.objective)
		print("   🧁 Если всё получится — заработаешь %d очков!" % level_info.target_score)
		print("   %s" % level_info.hint)
	
	print("\n2. Тестирование установки текущего уровня:")
	LevelData.set_current_level(2)
	var current = LevelData.get_current_level_info()
	print("   Текущий уровень: %d - %s" % [current.level_number, current.level_name])
	
	print("\n3. Для запуска превью уровня используйте:")
	print("   LevelData.start_level(1)  # Запуск первого уровня")
	print("   LevelData.start_level(2)  # Запуск второго уровня")
	print("   LevelData.start_level(3)  # Запуск третьего уровня")

func _input(event: InputEvent) -> void:
	"""Обработка ввода для демонстрации"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				print("\nЗапуск превью уровня 1...")
				LevelData.start_level(1)
			KEY_2:
				print("\nЗапуск превью уровня 2...")
				LevelData.start_level(2)
			KEY_3:
				print("\nЗапуск превью уровня 3...")
				LevelData.start_level(3)
			KEY_H:
				print("\n=== Справка ===")
				print("Нажмите 1, 2 или 3 для запуска превью соответствующего уровня")
				print("Нажмите H для показа этой справки")
