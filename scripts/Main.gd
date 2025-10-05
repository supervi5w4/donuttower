extends Node

func _ready() -> void:
	print("Main: _ready() начал выполнение")
	
	# Инициализируем SDK Яндекс Игр сразу после загрузки главной сцены
	if YandexSDK and YandexSDK.is_working():
		print("Main: инициализируем Yandex SDK...")
		
		# 1. Инициализируем игру
		YandexSDK.init_game()
		await YandexSDK.game_initialized
		print("Main: игра инициализирована")
		
		# 2. Инициализируем игрока для работы с лидербордом
		YandexSDK.init_player()
		await YandexSDK.player_initialized
		print("Main: игрок инициализирован")
		
		# 3. Сообщаем о готовности игры к взаимодействию
		YandexSDK.game_ready()
		print("Main: game_ready() вызван - игра готова к взаимодействию")
		
		# 4. Загружаем данные сохранения из облака
		YandexSDK.load_data(["save"])
		print("Main: запрошена загрузка данных сохранения из облака")
		
		# 5. Настраиваем обработчики событий
		_setup_sdk_handlers()
	else:
		print("Main: не на платформе Yandex, работаем в режиме разработки")
	
	print("Main: инициализация завершена")

# Обработчики событий SDK
func _setup_sdk_handlers():
	"""Настраивает обработчики событий SDK"""
	if YandexSDK:
		# Подключаем обработчики для отладки
		YandexSDK.data_loaded.connect(_on_data_loaded)
		YandexSDK.stats_loaded.connect(_on_stats_loaded)
		YandexSDK.check_auth.connect(_on_auth_checked)
		YandexSDK.interstitial_ad.connect(_on_interstitial_result)
		YandexSDK.rewarded_ad.connect(_on_rewarded_result)
		print("Main: обработчики SDK настроены")


func _on_data_loaded(data: Dictionary):
	"""Обработчик загрузки данных игрока"""
	print("Main: данные игрока загружены: ", data)
	
	# Передаем данные сохранения в GameStateManager для обработки
	if data.has("save"):
		print("Main: передаем данные сохранения в GameStateManager")
		GameStateManager.apply_cloud_save(data["save"])
	else:
		print("Main: данные сохранения не найдены в загруженных данных")

func _on_stats_loaded(stats: Dictionary):
	"""Обработчик загрузки статистики"""
	print("Main: статистика загружена: ", stats)

func _on_auth_checked(is_authorized: bool):
	"""Обработчик проверки авторизации"""
	print("Main: авторизация: ", is_authorized)

func _on_interstitial_result(result: String):
	"""Обработчик результата межстраничной рекламы"""
	print("Main: межстраничная реклама: ", result)

func _on_rewarded_result(result: String):
	"""Обработчик результата рекламы за награду"""
	print("Main: реклама за награду: ", result)
