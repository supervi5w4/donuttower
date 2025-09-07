extends Node
## Тестовый скрипт для проверки работы Яндекс рекламы
## Добавьте этот узел в сцену для тестирования

func _ready() -> void:
	# Подключаем сигналы от официального YandexSDK для тестирования
	# Проверяем, не подключены ли уже сигналы
	if not YandexSDK.interstitial_ad.is_connected(_on_test_interstitial_ad):
		YandexSDK.interstitial_ad.connect(_on_test_interstitial_ad)
	if not YandexSDK.rewarded_ad.is_connected(_on_test_rewarded_ad):
		YandexSDK.rewarded_ad.connect(_on_test_rewarded_ad)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				YandexSDK.show_interstitial_ad()
			KEY_R:
				YandexSDK.show_rewarded_ad()
			KEY_S:
				pass

func _on_test_interstitial_ad(result: String) -> void:
	print("AdTester: Interstitial ad result: ", result)

func _on_test_rewarded_ad(result: String) -> void:
	print("AdTester: Rewarded ad result: ", result)

func _exit_tree() -> void:
	# Отключаем сигналы при удалении узла
	if YandexSDK.interstitial_ad.is_connected(_on_test_interstitial_ad):
		YandexSDK.interstitial_ad.disconnect(_on_test_interstitial_ad)
	if YandexSDK.rewarded_ad.is_connected(_on_test_rewarded_ad):
		YandexSDK.rewarded_ad.disconnect(_on_test_rewarded_ad)
