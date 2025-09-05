extends Node
## Тестовый скрипт для проверки работы Яндекс рекламы
## Добавьте этот узел в сцену для тестирования

@onready var yandex_sdk: Node = get_node("../YandexSDK")

func _ready() -> void:
	if yandex_sdk == null:
		print("AdTester: YandexSDK не найден!")
		return
	
	# Подключаем сигналы для тестирования
	yandex_sdk.interstitial_closed.connect(_on_test_interstitial_closed)
	yandex_sdk.rewarded_completed.connect(_on_test_rewarded_completed)
	yandex_sdk.rewarded_closed.connect(_on_test_rewarded_closed)
	yandex_sdk.ad_error.connect(_on_test_ad_error)
	
	print("AdTester: готов к тестированию рекламы")
	print("Нажмите I для Interstitial, R для Rewarded")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				print("AdTester: Тестируем Interstitial рекламу")
				if yandex_sdk:
					yandex_sdk.show_interstitial()
			KEY_R:
				print("AdTester: Тестируем Rewarded рекламу")
				if yandex_sdk:
					yandex_sdk.show_rewarded()
			KEY_S:
				print("AdTester: Проверяем готовность SDK: ", yandex_sdk.is_sdk_ready() if yandex_sdk else false)

func _on_test_interstitial_closed(was_shown: bool) -> void:
	print("AdTester: Interstitial закрыта, показана: ", was_shown)

func _on_test_rewarded_completed() -> void:
	print("AdTester: Rewarded завершена, награда получена!")

func _on_test_rewarded_closed() -> void:
	print("AdTester: Rewarded закрыта")

func _on_test_ad_error(error_message: String) -> void:
	print("AdTester: Ошибка рекламы: ", error_message)
