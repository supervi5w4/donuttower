extends Node
## Тестовый скрипт для проверки работы Яндекс рекламы
## Добавьте этот узел в сцену для тестирования

@onready var yandex_sdk: Node = get_node("../YandexSDK")

func _ready() -> void:
	if yandex_sdk == null:
		return
	
	# Подключаем сигналы для тестирования
	yandex_sdk.interstitial_closed.connect(_on_test_interstitial_closed)
	yandex_sdk.rewarded_completed.connect(_on_test_rewarded_completed)
	yandex_sdk.rewarded_closed.connect(_on_test_rewarded_closed)
	yandex_sdk.ad_error.connect(_on_test_ad_error)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				if yandex_sdk:
					yandex_sdk.show_interstitial()
			KEY_R:
				if yandex_sdk:
					yandex_sdk.show_rewarded()
			KEY_S:
				pass

func _on_test_interstitial_closed(was_shown: bool) -> void:
	pass

func _on_test_rewarded_completed() -> void:
	pass

func _on_test_rewarded_closed() -> void:
	pass

func _on_test_ad_error(error_message: String) -> void:
	pass
