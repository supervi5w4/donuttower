# Полноценная реализация SDK Яндекс Игр для Godot

## Обзор

Данная реализация предоставляет полный набор API для интеграции с платформой Яндекс Игр согласно официальной документации.

## Реализованные API

### 1. LoadingAPI
- **`loading_ready()`** - уведомляет платформу о готовности игры к взаимодействию с пользователем
- Вызывается когда все ресурсы загружены и нет экранов загрузки

### 2. GameplayAPI  
- **`gameplay_started()`** - сообщает о начале/возобновлении игрового процесса
- **`gameplay_stopped()`** - сообщает о приостановке/завершении игрового процесса
- Используется для отслеживания метрик и улучшения рекомендаций

### 3. Переменные окружения
- **`load_environment_variables()`** - загружает переменные окружения
- Сигнал: `environment_variables_loaded(variables: Dictionary)`

### 4. Серверное время
- **`get_server_time()`** - получает серверное время для синхронизации
- Сигнал: `server_time_loaded(time: int)`

### 5. Ярлык на рабочий стол
- **`create_shortcut()`** - создает ярлык игры на рабочий стол
- Сигнал: `shortcut_created()`

### 6. Оценка игры
- **`request_rating()`** - запрашивает оценку игры у пользователя
- Сигнал: `rating_requested()`

### 7. Ссылки на другие игры
- **`load_game_links()`** - загружает ссылки на другие игры
- Сигнал: `game_links_loaded(links: Array)`

## Существующие API (улучшены)

### Реклама
- **`show_interstitial_ad()`** - показ межстраничной рекламы
- **`show_rewarded_ad()`** - показ рекламы за награду
- Сигналы: `interstitial_ad(result: String)`, `rewarded_ad(result: String)`

### Данные игрока
- **`save_data(data: Dictionary, flush: bool)`** - сохранение данных
- **`load_all_data()`** - загрузка всех данных
- **`load_data(keys: Array)`** - загрузка конкретных данных
- Сигнал: `data_loaded(data: Dictionary)`

### Статистика
- **`save_stats(stats: Dictionary)`** - сохранение статистики
- **`load_all_stats()`** - загрузка всей статистики
- **`load_stats(keys: Array)`** - загрузка конкретной статистики
- **`increment_stats(increments: Dictionary)`** - увеличение статистики
- Сигнал: `stats_loaded(stats: Dictionary)`

### Лидерборды
- **`save_leaderboard_score(leaderboard_name, score, extra_data)`** - сохранение результата
- **`load_leaderboard_player_entry(leaderboard_name)`** - загрузка записи игрока
- **`load_leaderboard_entries(leaderboard_name, include_user, quantity_around, quantity_top)`** - загрузка записей
- Сигналы: `leaderboard_player_entry_loaded(data)`, `leaderboard_entries_loaded(data)`, `leaderboard_error()`

### Авторизация
- **`open_auth_dialog()`** - открытие диалога авторизации
- **`check_is_authorized()`** - проверка авторизации
- Сигнал: `check_auth(answer: bool)`

## Новые сигналы

```gdscript
signal environment_variables_loaded(variables: Dictionary)
signal server_time_loaded(time: int)
signal shortcut_created()
signal rating_requested()
signal game_links_loaded(links: Array)
```

## Использование

### Базовая инициализация

```gdscript
func _ready():
    if YandexSDK.is_working():
        # Инициализируем игру
        YandexSDK.init_game()
        await YandexSDK.game_initialized
        
        # Сообщаем о готовности
        YandexSDK.loading_ready()
        
        # Настраиваем обработчики
        _setup_handlers()
```

### Отслеживание геймплея

```gdscript
# При начале уровня
func start_level():
    YandexSDK.gameplay_started()

# При паузе
func pause_game():
    YandexSDK.gameplay_stopped()

# При возобновлении
func resume_game():
    YandexSDK.gameplay_started()
```

### Работа с переменными окружения

```gdscript
func load_environment():
    YandexSDK.load_environment_variables()
    YandexSDK.environment_variables_loaded.connect(_on_environment_loaded)

func _on_environment_loaded(variables: Dictionary):
    print("Переменные окружения: ", variables)
    # Используем переменные для настройки игры
```

### Синхронизация времени

```gdscript
func sync_time():
    YandexSDK.get_server_time()
    YandexSDK.server_time_loaded.connect(_on_server_time_loaded)

func _on_server_time_loaded(time: int):
    print("Серверное время: ", time)
    # Синхронизируем время игры
```

## JavaScript интерфейс

Все новые функции также реализованы в `yandex_sdk.js`:

- `LoadingReady()` - LoadingAPI.ready()
- `LoadEnvironmentVariables(callback)` - загрузка переменных окружения
- `GetServerTime(callback)` - получение серверного времени
- `CreateShortcut(callback)` - создание ярлыка
- `RequestRating(callback)` - запрос оценки
- `LoadGameLinks(callback)` - загрузка ссылок на игры

## Соответствие документации

Реализация полностью соответствует официальной документации Яндекс Игр:

- [Загрузка игры и разметка геймплея](https://yandex.ru/dev/games/doc/ru/sdk/sdk-game-events)
- [Установка и использование](https://yandex.ru/dev/games/doc/ru/sdk/sdk-about)

## Требования

- Godot 4.x
- Платформа Яндекс Игр (определяется через `OS.has_feature("yandex")`)
- Подключенный скрипт `/sdk.js` в HTML

## Установка

1. Скопируйте файлы в папку `addons/godot-yandex-games-sdk-main/`
2. Включите плагин в настройках проекта
3. Добавьте `YandexSDK` как автозагрузку
4. Используйте API согласно примерам

## Отладка

Все функции содержат подробное логирование для отладки. Проверьте консоль браузера для диагностики проблем.

## Поддержка

При возникновении проблем проверьте:
1. Правильность подключения `/sdk.js` в HTML
2. Наличие функции `YaGames` в глобальной области
3. Корректность инициализации SDK
4. Логи в консоли браузера
