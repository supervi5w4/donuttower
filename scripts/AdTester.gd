extends Control

# Тестовый скрипт для проверки работы рекламы Yandex Games SDK
# Используйте этот скрипт для тестирования рекламы в редакторе

func _ready() -> void:
	# Подключаемся к сигналам YandexSDK
	if YandexSDK:
		YandexSDK.rewarded_ad.connect(_on_rewarded_ad_result)
		YandexSDK.interstitial_ad.connect(_on_interstitial_ad_result)
	else:
		pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Нажатие Enter
		_test_rewarded_ad()
	elif event.is_action_pressed("ui_cancel"):  # Нажатие Escape
		_test_interstitial_ad()

func _test_rewarded_ad() -> void:
	"""Тестирует рекламу за вознаграждение"""
	if YandexSDK:
		YandexSDK.show_rewarded_ad()
	else:
		pass

func _test_interstitial_ad() -> void:
	"""Тестирует обычную рекламу"""
	if YandexSDK:
		YandexSDK.show_interstitial_ad()
	else:
		pass

func _on_rewarded_ad_result(result: String) -> void:
	"""Обработчик результата рекламы за вознаграждение"""
	match result:
		"rewarded":
			pass
		"closed":
			pass
		"opened":
			pass
		"error":
			pass

func _on_interstitial_ad_result(result: String) -> void:
	"""Обработчик результата обычной рекламы"""
	match result:
		"opened":
			pass
		"closed":
			pass
		"error":
			pass