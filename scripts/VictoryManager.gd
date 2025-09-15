extends Node
class_name VictoryManager

# Менеджер поздравления с завершением игры
# Отдельный скрипт для переиспользования в разных уровнях

# Ссылки на UI элементы
var ui_root: Control
var victory_container: Control

# Состояние поздравления
var victory_celebration: bool = false
var final_level_effects: Array[Node2D] = []

# Настройки анимации
var auto_return_delay: float = 10.0  # Автоматический возврат в меню через 10 секунд

signal victory_completed  # Сигнал о завершении поздравления

func _ready() -> void:
	"""Инициализация менеджера поздравления"""
	# UI root будет найден при показе поздравления

func show_victory_message(score: int) -> void:
	"""Показывает поздравление с прохождением игры по центру экрана"""
	print("VictoryManager: Показываем поздравление с счетом: ", score)
	
	# Ищем UI root при показе поздравления
	print("VictoryManager: Ищем UI root...")
	
	# Сначала пробуем найти через родительский узел (если VictoryManager добавлен в Game)
	var parent_game = get_parent()
	print("VictoryManager: Родительский узел: ", parent_game.name if parent_game else "НЕТ")
	if parent_game and parent_game.has_method("get_node"):
		ui_root = parent_game.get_node_or_null("UI/UIRoot")
		print("VictoryManager: Попытка 1 - через родителя: ", "НАЙДЕН" if ui_root else "НЕ НАЙДЕН")
	
	# Если не найден, пробуем альтернативные пути
	if not ui_root:
		ui_root = get_node_or_null("../UI/UIRoot")  # Относительный путь
		print("VictoryManager: Попытка 2 - относительный путь: ", "НАЙДЕН" if ui_root else "НЕ НАЙДЕН")
	if not ui_root:
		ui_root = get_tree().get_first_node_in_group("ui_root")
		print("VictoryManager: Попытка 3 - по группе: ", "НАЙДЕН" if ui_root else "НЕ НАЙДЕН")
	if not ui_root:
		# Последняя попытка - поиск по абсолютному пути
		ui_root = get_node_or_null("/root/Game/UI/UIRoot")
		print("VictoryManager: Попытка 4 - абсолютный путь: ", "НАЙДЕН" if ui_root else "НЕ НАЙДЕН")
	
	if not ui_root:
		print("ОШИБКА: UI root не найден для VictoryManager!")
		return
	
	print("VictoryManager: UI root найден, создаем поздравление")
	
	# Создаем контейнер для поздравления
	victory_container = Control.new()
	victory_container.name = "VictoryContainer"
	victory_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_container.z_index = 1000  # Поверх всего
	
	# Создаем фон для поздравления
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.8)  # Полупрозрачный черный фон
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_container.add_child(background)
	
	# Создаем основной контейнер для текста
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Создаем VBoxContainer внутри CenterContainer
	var text_container = VBoxContainer.new()
	text_container.name = "TextContainer"
	text_container.add_theme_constant_override("separation", 30)
	text_container.size = Vector2(600, 300)  # Фиксированный размер
	
	center_container.add_child(text_container)
	
	# Создаем заголовок поздравления
	var victory_label = Label.new()
	victory_label.name = "VictoryLabel"
	# Используем перевод, если доступен, иначе прямой текст
	var victory_text = tr("ui.game.completed")
	if victory_text == "ui.game.completed":  # Если перевод не найден
		victory_text = "Игра пройдена!" if LanguageManager.get_current_language() == "ru" else "Game Completed!"
	victory_label.text = victory_text
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	victory_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	victory_label.add_theme_font_size_override("font_size", 48)
	victory_label.add_theme_color_override("font_color", Color.GOLD)
	victory_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	victory_label.add_theme_constant_override("shadow_offset_x", 3)
	victory_label.add_theme_constant_override("shadow_offset_y", 3)
	text_container.add_child(victory_label)
	
	# Создаем подзаголовок с результатом
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	# Используем перевод, если доступен, иначе прямой текст
	var score_text = tr("ui.gameover.your_score")
	if score_text == "ui.gameover.your_score":  # Если перевод не найден
		score_text = "Ваш результат" if LanguageManager.get_current_language() == "ru" else "Your score"
	score_label.text = score_text + ": " + str(score)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	text_container.add_child(score_label)
	
	# Создаем текст с инструкцией
	var instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	# Используем перевод, если доступен, иначе прямой текст
	var instruction_text = tr("ui.game.victory.instruction")
	if instruction_text == "ui.game.victory.instruction":  # Если перевод не найден
		instruction_text = "Нажмите любую клавишу для возврата в меню" if LanguageManager.get_current_language() == "ru" else "Press any key to return to menu"
	instruction_label.text = instruction_text
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	instruction_label.add_theme_constant_override("shadow_offset_x", 1)
	instruction_label.add_theme_constant_override("shadow_offset_y", 1)
	text_container.add_child(instruction_label)
	
	victory_container.add_child(center_container)
	
	# Добавляем контейнер в UI
	ui_root.add_child(victory_container)
	
	# Запускаем анимацию появления
	_animate_victory_message(victory_container)
	
	# Запускаем финальное празднование
	_start_final_celebration()
	
	# Настраиваем автоматический переход в меню
	_setup_auto_return_to_menu()

func _animate_victory_message(container: Control) -> void:
	"""Анимирует появление поздравления"""
	# Начинаем с прозрачности
	container.modulate = Color.TRANSPARENT
	
	# Создаем анимацию появления
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Анимация прозрачности
	tween.tween_property(container, "modulate", Color.WHITE, 1.0)
	
	# Анимация масштаба для эффекта появления
	container.scale = Vector2(0.5, 0.5)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Анимация текста (поочередное появление)
	var center_container = container.get_node("CenterContainer")
	if center_container:
		var text_container = center_container.get_node("TextContainer")
		if text_container:
			for i in range(text_container.get_child_count()):
				var child = text_container.get_child(i)
				if child is Label:
					child.modulate = Color.TRANSPARENT
					tween.tween_property(child, "modulate", Color.WHITE, 0.5).set_delay(0.5 + i * 0.3)

func _setup_auto_return_to_menu() -> void:
	"""Настраивает автоматический возврат в меню через заданное время"""
	var auto_return_timer = Timer.new()
	auto_return_timer.name = "AutoReturnTimer"
	auto_return_timer.wait_time = auto_return_delay
	auto_return_timer.one_shot = true
	auto_return_timer.timeout.connect(_return_to_menu)
	add_child(auto_return_timer)
	auto_return_timer.start()

func _return_to_menu() -> void:
	"""Возвращает игрока в главное меню"""
	# Очищаем поздравление
	_cleanup_victory_message()
	
	# Переходим в главное меню
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	
	# Отправляем сигнал о завершении
	victory_completed.emit()

func _cleanup_victory_message() -> void:
	"""Очищает сообщение о победе"""
	if victory_container and is_instance_valid(victory_container):
		victory_container.queue_free()
		victory_container = null
	
	# Очищаем все эффекты
	_cleanup_all_effects()

func _start_final_celebration() -> void:
	"""Запускает финальное празднование для завершения игры"""
	if victory_celebration:
		return
	
	victory_celebration = true
	
	# Увеличиваем интенсивность всех эффектов
	for effect in final_level_effects:
		if effect is GPUParticles2D:
			effect.amount = 500
			effect.lifetime = 10.0
	
	# Создаем дополнительные эффекты празднования
	_create_victory_effects()

func _create_victory_effects() -> void:
	"""Создает дополнительные эффекты для празднования победы"""
	# Создаем взрывы частиц в разных местах экрана
	for i in range(5):
		var explosion = GPUParticles2D.new()
		explosion.name = "VictoryExplosion" + str(i)
		explosion.position = Vector2(randf_range(100, 620), randf_range(200, 1000))
		explosion.z_index = -5
		
		var explosion_material = ParticleProcessMaterial.new()
		explosion_material.direction = Vector3(0, 1, 0)
		explosion_material.initial_velocity_min = 50.0
		explosion_material.initial_velocity_max = 150.0
		explosion_material.gravity = Vector3(0, 100, 0)
		explosion_material.scale_min = 0.5
		explosion_material.scale_max = 2.0
		explosion_material.color = Color(1.0, 0.8, 0.2, 0.9)
		explosion_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		explosion_material.emission_box_extents = Vector3(50, 50, 0)
		
		explosion.process_material = explosion_material
		explosion.amount = 100
		explosion.lifetime = 3.0
		explosion.emitting = true
		
		add_child(explosion)
		final_level_effects.append(explosion)
		
		# Удаляем эффект через время
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 5.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(_cleanup_victory_effect.bind(explosion))
		
		# Сначала добавляем таймер в дерево сцены, затем запускаем
		explosion.add_child(cleanup_timer)
		cleanup_timer.start()

func _cleanup_victory_effect(effect: GPUParticles2D) -> void:
	"""Очищает эффект празднования"""
	if is_instance_valid(effect):
		final_level_effects.erase(effect)
		effect.queue_free()

func _cleanup_all_effects() -> void:
	"""Очищает все эффекты празднования"""
	for effect in final_level_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	final_level_effects.clear()

func check_victory_input() -> bool:
	"""Проверяет ввод для возврата в меню после победы. Возвращает true если нужно обработать ввод"""
	# Проверяем, показано ли поздравление
	if not victory_container or not victory_container.visible:
		return false
	
	# Проверяем любое нажатие клавиши
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_anything_pressed():
		_return_to_menu()
		return true
	
	return false

func setup_final_level_effects() -> void:
	"""Настраивает финальные эффекты для последнего уровня"""
	# Создаем дополнительные частицы для финального уровня
	var final_particles = GPUParticles2D.new()
	final_particles.name = "FinalParticles"
	final_particles.position = Vector2(360, 200)
	final_particles.z_index = -5
	
	# Настраиваем материал частиц для финального эффекта
	var final_material = ParticleProcessMaterial.new()
	final_material.direction = Vector3(0, 1, 0)
	final_material.initial_velocity_min = 20.0
	final_material.initial_velocity_max = 80.0
	final_material.gravity = Vector3(0, 50, 0)
	final_material.scale_min = 0.5
	final_material.scale_max = 1.5
	final_material.color = Color(1.0, 0.8, 0.2, 0.8)  # Золотой цвет
	final_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	final_material.emission_box_extents = Vector3(600, 100, 0)
	
	final_particles.process_material = final_material
	final_particles.amount = 100
	final_particles.lifetime = 6.0
	final_particles.emitting = true
	
	add_child(final_particles)
	final_level_effects.append(final_particles)

func set_auto_return_delay(delay: float) -> void:
	"""Устанавливает задержку автоматического возврата в меню"""
	auto_return_delay = delay

func is_victory_active() -> bool:
	"""Проверяет, активно ли поздравление"""
	return victory_container != null and victory_container.visible
