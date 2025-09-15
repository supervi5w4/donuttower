# Тест инициализации SDK Яндекс Игр

## Проверка последовательности инициализации

### 1. HTML файл (index.html)
✅ **Правильно**: `/sdk.js` подключен до `yandex_sdk.js` и `index.js`
```html
<script src="/sdk.js"></script>
<script src="yandex_sdk.js"></script>
```

### 2. Последовательность инициализации в StartMenu.gd
✅ **Исправлено**: Правильная последовательность согласно документации:

1. `YandexSDK.init_game()` - инициализация игры
2. `await YandexSDK.game_initialized` - ожидание инициализации
3. `YandexSDK.init_player()` - инициализация игрока
4. `await YandexSDK.player_initialized` - ожидание инициализации игрока
5. `YandexSDK.loading_ready()` - **LoadingAPI.ready()** - уведомление о готовности
6. Настройка обработчиков событий

### 3. GameplayAPI
✅ **Добавлено**: Вызов `gameplay_started()` при нажатии кнопки "Начать играть"

## Логи для отладки

При запуске игры в консоли браузера должны появиться следующие логи:

```
StartMenu: инициализируем Yandex SDK...
YandexSDK: начинаем инициализацию игры...
YandexSDK: вызываем window.InitGame()...
YandexSDK: получен callback _game_initialized
YandexSDK: игра инициализирована, испускаем сигнал game_initialized
StartMenu: игра инициализирована
YandexSDK: вызываем LoadingAPI.ready()...
StartMenu: LoadingAPI.ready() вызван - игра готова к взаимодействию
StartMenu: обработчики SDK настроены
StartMenu: готов к работе
```

При нажатии кнопки "Начать играть":
```
StartMenu: GameplayAPI.start() вызван
YandexSDK: вызываем GameplayAPI.start()...
```

## Проверка работы SDK

### В консоли браузера должно быть:
1. `Yandex SDK start initialization`
2. `Yandex SDK initialized`
3. `Game initialized`
4. `Environment [объект с данными окружения]`
5. `Loading API ready`
6. `Gameplay started (js)` - при нажатии кнопки

### Проверка доступности YaGames:
Откройте консоль браузера (F12) и выполните:
```javascript
console.log(typeof YaGames); // должно быть "function"
console.log(YaGames); // должен показать объект YaGames
```

## Возможные проблемы и решения

### 1. Ошибка "YaGames is not defined"
**Причина**: `/sdk.js` не загрузился или загрузился после инициализации
**Решение**: Убедитесь, что `/sdk.js` подключен первым в HTML

### 2. Ошибка "Game initialization error"
**Причина**: Проблемы с инициализацией SDK
**Решение**: Проверьте логи в консоли браузера

### 3. SDK не инициализируется
**Причина**: Не на платформе Яндекс Игр
**Решение**: Проверьте `YandexSDK.is_working()` - должно возвращать `true` на платформе Яндекс Игр

## Тестирование на платформе Яндекс Игр

1. Загрузите игру на платформу Яндекс Игр
2. Откройте консоль разработчика (F12)
3. Проверьте логи инициализации
4. Убедитесь, что все API работают корректно

## Дополнительные проверки

### Проверка переменных окружения:
```javascript
// В консоли браузера
console.log(ysdk.environment);
```

### Проверка LoadingAPI:
```javascript
// В консоли браузера
console.log(ysdk.features.LoadingAPI);
```

### Проверка GameplayAPI:
```javascript
// В консоли браузера
console.log(ysdk.features.GameplayAPI);
```
