# Пример использования полноценного SDK Яндекс Игр

## Инициализация и готовность игры

```gdscript
# В главной сцене игры
func _ready():
    # Инициализируем SDK
    YandexSDK.init_game()
    await YandexSDK.game_initialized
    
    # Сообщаем о готовности игры к взаимодействию
    YandexSDK.loading_ready()
    
    # Загружаем переменные окружения
    YandexSDK.load_environment_variables()
    YandexSDK.environment_variables_loaded.connect(_on_environment_loaded)
    
    # Получаем серверное время
    YandexSDK.get_server_time()
    YandexSDK.server_time_loaded.connect(_on_server_time_loaded)

func _on_environment_loaded(variables: Dictionary):
    print("Переменные окружения: ", variables)
    # Используем переменные для настройки игры

func _on_server_time_loaded(time: int):
    print("Серверное время: ", time)
    # Синхронизируем время игры с сервером
```

## Отслеживание геймплея

```gdscript
# При начале уровня
func start_level():
    YandexSDK.gameplay_started()
    # Логика начала уровня

# При паузе игры
func pause_game():
    YandexSDK.gameplay_stopped()
    # Логика паузы

# При возобновлении игры
func resume_game():
    YandexSDK.gameplay_started()
    # Логика возобновления

# При завершении уровня
func end_level():
    YandexSDK.gameplay_stopped()
    # Логика завершения уровня
```

## Реклама

```gdscript
# Показ межстраничной рекламы
func show_interstitial():
    YandexSDK.show_interstitial_ad()
    YandexSDK.interstitial_ad.connect(_on_interstitial_result)

# Показ рекламы за награду
func show_rewarded_ad():
    YandexSDK.show_rewarded_ad()
    YandexSDK.rewarded_ad.connect(_on_rewarded_result)

func _on_interstitial_result(result: String):
    match result:
        "opened":
            print("Реклама открылась")
        "closed":
            print("Реклама закрылась")
        "error":
            print("Ошибка показа рекламы")

func _on_rewarded_result(result: String):
    match result:
        "opened":
            print("Реклама за награду открылась")
        "rewarded":
            print("Игрок получил награду!")
            # Даем награду игроку
        "closed":
            print("Реклама за награду закрылась")
        "error":
            print("Ошибка показа рекламы за награду")
```

## Сохранение данных

```gdscript
# Сохранение данных игрока
func save_player_data():
    var data = {
        "level": current_level,
        "score": player_score,
        "coins": player_coins
    }
    YandexSDK.save_data(data, true)  # true = принудительное сохранение

# Загрузка данных игрока
func load_player_data():
    YandexSDK.load_all_data()
    YandexSDK.data_loaded.connect(_on_data_loaded)

func _on_data_loaded(data: Dictionary):
    if data.has("level"):
        current_level = data["level"]
    if data.has("score"):
        player_score = data["score"]
    if data.has("coins"):
        player_coins = data["coins"]
```

## Статистика

```gdscript
# Сохранение статистики
func save_stats():
    var stats = {
        "games_played": games_played,
        "total_score": total_score,
        "enemies_killed": enemies_killed
    }
    YandexSDK.save_stats(stats)

# Увеличение статистики
func increment_kills():
    var increments = {"enemies_killed": 1}
    YandexSDK.increment_stats(increments)
```

## Лидерборды

```gdscript
# Сохранение результата в лидерборд
func save_leaderboard_score(score: int):
    YandexSDK.save_leaderboard_score("main_leaderboard", score, "")

# Загрузка лидерборда
func load_leaderboard():
    YandexSDK.load_leaderboard_entries("main_leaderboard", true, 5, 10)
    YandexSDK.leaderboard_entries_loaded.connect(_on_leaderboard_loaded)

func _on_leaderboard_loaded(data):
    print("Лидерборд загружен: ", data)
    # Отображаем лидерборд в UI
```

## Дополнительные функции

```gdscript
# Создание ярлыка на рабочий стол
func create_desktop_shortcut():
    YandexSDK.create_shortcut()
    YandexSDK.shortcut_created.connect(_on_shortcut_created)

func _on_shortcut_created():
    print("Ярлык создан!")

# Запрос оценки игры
func request_game_rating():
    YandexSDK.request_rating()
    YandexSDK.rating_requested.connect(_on_rating_requested)

func _on_rating_requested():
    print("Запрос оценки отправлен!")

# Загрузка ссылок на другие игры
func load_other_games():
    YandexSDK.load_game_links()
    YandexSDK.game_links_loaded.connect(_on_game_links_loaded)

func _on_game_links_loaded(links: Array):
    print("Ссылки на игры: ", links)
    # Показываем ссылки на другие игры в меню
```

## Обработка авторизации

```gdscript
# Проверка авторизации
func check_auth():
    YandexSDK.check_is_authorized()
    YandexSDK.check_auth.connect(_on_auth_checked)

func _on_auth_checked(is_authorized: bool):
    if is_authorized:
        print("Игрок авторизован")
        # Включаем функции для авторизованных пользователей
    else:
        print("Игрок не авторизован")
        # Показываем кнопку авторизации

# Открытие диалога авторизации
func open_auth():
    YandexSDK.open_auth_dialog()
```

## Полный пример инициализации

```gdscript
extends Node

func _ready():
    # Инициализация SDK
    if YandexSDK.is_working():
        print("Инициализируем Yandex SDK...")
        
        # Инициализируем игру
        YandexSDK.init_game()
        await YandexSDK.game_initialized
        print("Игра инициализирована")
        
        # Сообщаем о готовности
        YandexSDK.loading_ready()
        print("Игра готова к взаимодействию")
        
        # Настраиваем обработчики
        _setup_sdk_handlers()
        
        # Загружаем данные игрока
        YandexSDK.load_all_data()
        
        # Загружаем переменные окружения
        YandexSDK.load_environment_variables()
        
        # Получаем серверное время
        YandexSDK.get_server_time()
        
        print("SDK полностью инициализирован!")
    else:
        print("Не на платформе Yandex, работаем в режиме разработки")

func _setup_sdk_handlers():
    # Подключаем обработчики событий
    YandexSDK.data_loaded.connect(_on_data_loaded)
    YandexSDK.environment_variables_loaded.connect(_on_environment_loaded)
    YandexSDK.server_time_loaded.connect(_on_server_time_loaded)
    YandexSDK.interstitial_ad.connect(_on_interstitial_result)
    YandexSDK.rewarded_ad.connect(_on_rewarded_result)
    YandexSDK.check_auth.connect(_on_auth_checked)
    YandexSDK.leaderboard_entries_loaded.connect(_on_leaderboard_loaded)
    YandexSDK.shortcut_created.connect(_on_shortcut_created)
    YandexSDK.rating_requested.connect(_on_rating_requested)
    YandexSDK.game_links_loaded.connect(_on_game_links_loaded)

# Обработчики событий
func _on_data_loaded(data: Dictionary):
    print("Данные загружены: ", data)

func _on_environment_loaded(variables: Dictionary):
    print("Переменные окружения: ", variables)

func _on_server_time_loaded(time: int):
    print("Серверное время: ", time)

func _on_interstitial_result(result: String):
    print("Межстраничная реклама: ", result)

func _on_rewarded_result(result: String):
    print("Реклама за награду: ", result)

func _on_auth_checked(is_authorized: bool):
    print("Авторизация: ", is_authorized)

func _on_leaderboard_loaded(data):
    print("Лидерборд: ", data)

func _on_shortcut_created():
    print("Ярлык создан!")

func _on_rating_requested():
    print("Запрос оценки отправлен!")

func _on_game_links_loaded(links: Array):
    print("Ссылки на игры: ", links)
```

## Важные замечания

1. **LoadingAPI.ready()** - вызывайте когда игра полностью загружена и готова к взаимодействию
2. **GameplayAPI.start()** - вызывайте при начале/возобновлении геймплея
3. **GameplayAPI.stop()** - вызывайте при паузе/завершении геймплея
4. Всегда проверяйте `YandexSDK.is_working()` перед использованием SDK
5. Обрабатывайте ошибки в callback функциях
6. Используйте `await` для ожидания инициализации перед вызовом методов
