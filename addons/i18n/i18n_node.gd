extends Node
## Скрипт для автоматической локализации узлов интерфейса
## Добавляется к узлам с текстом для автоматического перевода

@export var translation_key: String = ""
@export var property_name: String = "text"

func _ready() -> void:
	if translation_key != "":
		_translate_node()
		# Подключаемся к сигналу смены языка
		if LanguageManager:
			LanguageManager.language_changed.connect(_on_language_changed)
		else:
			pass

func _on_language_changed(_language_code: String) -> void:
	"""Обработчик смены языка - обновляем текст"""
	if translation_key != "":
		_translate_node()

func _translate_node() -> void:
	var target_node = get_parent()
	if target_node.has_method("set") and target_node.has_method("get"):
		var current_value = target_node.get(property_name)
		if current_value is String:
			var translated_text = tr(translation_key)
			target_node.set(property_name, translated_text)
