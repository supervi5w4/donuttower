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
		
		# 3. Загружаем переменные окружения
		YandexSDK.load_environment_variables()
		YandexSDK.environment_variables_loaded.connect(_on_environment_loaded)
		
		# 4. Получаем серверное время
		YandexSDK.get_server_time()
		YandexSDK.server_time_loaded.connect(_on_server_time_loaded)
		
		# 5. ВАЖНО: Сообщаем о готовности игры к взаимодействию (LoadingAPI.ready)
		# Это должно быть вызвано сразу после инициализации игры
		YandexSDK.loading_ready()
		print("Main: LoadingAPI.ready() вызван - игра готова к взаимодействию")
		
		# 6. Настраиваем обработчики событий
		_setup_sdk_handlers()
		
		# 7. Настраиваем обработчики паузы/возобновления
		_setup_pause_resume_handlers()
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

func _on_environment_loaded(variables: Dictionary):
	"""Обработчик загрузки переменных окружения"""
	print("Main: переменные окружения загружены: ", variables)

func _on_server_time_loaded(time: int):
	"""Обработчик получения серверного времени"""
	print("Main: серверное время получено: ", time)

func _on_data_loaded(data: Dictionary):
	"""Обработчик загрузки данных игрока"""
	print("Main: данные игрока загружены: ", data)

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

func _setup_pause_resume_handlers():
	"""Настраивает обработчики паузы и возобновления игры"""
	if YandexSDK and YandexSDK.is_working():
		# Настраиваем обработчики через SDK
		YandexSDK.setup_pause_resume_handlers()
		print("Main: обработчики паузы/возобновления настроены")
