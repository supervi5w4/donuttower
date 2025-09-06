extends Control

@onready var language_button: Button = $LanguageButton
@onready var language_manager: Node = get_node("/root/LanguageManager")

func _ready() -> void:
	# Подключаем сигнал смены языка
	if language_manager:
		language_manager.language_changed.connect(_on_language_changed)
		_update_language_button()

func _on_start_button_pressed():
	# Переход к игровой сцене
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_language_button_pressed():
	"""Обработчик нажатия кнопки смены языка"""
	if language_manager:
		language_manager.switch_language()

func _on_language_changed(language_code: String):
	"""Обработчик смены языка"""
	_update_language_button()
	# Принудительно обновляем все тексты в интерфейсе
	_update_all_texts()

func _update_language_button():
	"""Обновляет текст кнопки языка"""
	if language_button and language_manager:
		var current_lang = language_manager.get_current_language()
		# Показываем следующий язык, на который переключимся
		var next_lang = language_manager.get_next_language()
		var display_name = language_manager.get_language_display_name(next_lang)
		language_button.text = display_name

func _update_all_texts():
	"""Принудительно обновляет все тексты в интерфейсе"""
	
	# Обновляем кнопку "Начать играть"
	var start_button = $MainContainer/StartButton
	if start_button:
		var new_text = tr("ui.start.button")
		start_button.text = new_text
	else:
		pass
	
	# Обновляем описание
	var description_label = $MainContainer/DescriptionLabel
	if description_label:
		var new_text = tr("ui.start.description")
		description_label.text = new_text
	else:
		pass
