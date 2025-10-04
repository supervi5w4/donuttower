extends Control
## Тестовый скрипт для проверки кнопки дополнительной жизни

func _ready() -> void:
	
	# Создаем кнопку для тестирования
	var test_button = Button.new()
	test_button.text = "Test GameOverPanel"
	test_button.position = Vector2(50, 50)
	test_button.custom_minimum_size = Vector2(200, 50)
	add_child(test_button)
	test_button.pressed.connect(_test_game_over_panel)

func _test_game_over_panel() -> void:
	"""Тестирует отображение GameOverPanel с кнопкой дополнительной жизни"""
	
	# Ищем GameOverPanel в сцене
	var game_over_panel = get_node_or_null("/root/Game/UI/UIRoot/GameOverPanel")
	if not game_over_panel:
		return
	
	
	# Вызываем show_game_over с параметрами проигрыша
	if game_over_panel.has_method("show_game_over"):
		game_over_panel.show_game_over(100, false, "", "res://scenes/Game.tscn")
	elif game_over_panel.has_method("show_game_over_fallback"):
		game_over_panel.show_game_over_fallback(100, false)
	else:
	
	# Проверяем кнопку дополнительной жизни
	var extra_life_button = game_over_panel.get_node_or_null("MainContainer/ExtraLifeButton")
	if extra_life_button:
	else:
