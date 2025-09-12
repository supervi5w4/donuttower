extends Control

# Тестовый скрипт для проверки работы рекламы Yandex Games SDK
# Используйте этот скрипт для тестирования рекламы в редакторе

func _ready() -> void:
	# Подключаемся к сигналам YandexSDK
	if YandexSDK:
		YandexSDK.rewarded_ad.connect(_on_rewarded_ad_result)
		YandexSDK.interstitial_ad.connect(_on_interstitial_ad_result)
		print("AdTester: Подключились к сигналам YandexSDK")
	else:
		print("AdTester: YandexSDK недоступен")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Нажатие Enter
		_test_rewarded_ad()
	elif event.is_action_pressed("ui_cancel"):  # Нажатие Escape
		_test_interstitial_ad()

func _test_rewarded_ad() -> void:
	"""Тестирует рекламу за вознаграждение"""
	print("AdTester: Тестируем рекламу за вознаграждение...")
	if YandexSDK:
		YandexSDK.show_rewarded_ad()
	else:
		print("AdTester: YandexSDK недоступен")

func _test_interstitial_ad() -> void:
	"""Тестирует обычную рекламу"""
	print("AdTester: Тестируем обычную рекламу...")
	if YandexSDK:
		YandexSDK.show_interstitial_ad()
	else:
		print("AdTester: YandexSDK недоступен")

func _on_rewarded_ad_result(result: String) -> void:
	"""Обработчик результата рекламы за вознаграждение"""
	print("AdTester: Результат рекламы за вознаграждение: ", result)
	
	match result:
		"rewarded":
			print("AdTester: ✅ Игрок получил награду!")
		"closed":
			print("AdTester: ❌ Реклама закрыта без награды")
		"opened":
			print("AdTester: 📺 Реклама открыта")
		"error":
			print("AdTester: ⚠️ Ошибка при показе рекламы")

func _on_interstitial_ad_result(result: String) -> void:
	"""Обработчик результата обычной рекламы"""
	print("AdTester: Результат обычной рекламы: ", result)
	
	match result:
		"opened":
			print("AdTester: 📺 Обычная реклама открыта")
		"closed":
			print("AdTester: ❌ Обычная реклама закрыта")
		"error":
			print("AdTester: ⚠️ Ошибка при показе обычной рекламы")