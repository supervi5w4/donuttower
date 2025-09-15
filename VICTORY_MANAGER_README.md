# VictoryManager - Менеджер поздравления с завершением игры

## Описание
`VictoryManager` - это отдельный скрипт для показа поздравления с завершением игры. Он был вынесен из `Game_level_6.gd` для переиспользования в будущих уровнях.

## Использование

### 1. Добавление в сцену уровня

```gdscript
# В скрипте уровня (например, Game_level_6.gd)
extends "res://scripts/Game.gd"

var victory_manager: VictoryManager

func _ready() -> void:
    super._ready()
    
    # Создаем менеджер поздравления
    victory_manager = VictoryManager.new()
    add_child(victory_manager)
    
    # Настраиваем финальные эффекты (опционально)
    victory_manager.setup_final_level_effects()

func _process(_delta: float) -> void:
    super._process(_delta)
    
    # Проверяем ввод для возврата в меню после победы
    if victory_manager and victory_manager.check_victory_input():
        return
```

### 2. Показ поздравления при победе

```gdscript
func _show_win_panel() -> void:
    """Переопределяем панель победы для финального уровня"""
    if victory_manager:
        victory_manager.show_victory_message(score)

func _open_win_panel() -> void:
    """Переопределяем открытие панели победы"""
    if victory_manager:
        victory_manager.show_victory_message(score)
```

### 3. Настройка параметров

```gdscript
# Установка задержки автоматического возврата в меню (по умолчанию 10 секунд)
victory_manager.set_auto_return_delay(15.0)

# Проверка, активно ли поздравление
if victory_manager.is_victory_active():
    print("Поздравление активно")
```

## API

### Основные методы

- `show_victory_message(score: int)` - Показывает поздравление с указанным счетом
- `check_victory_input() -> bool` - Проверяет ввод для возврата в меню
- `setup_final_level_effects()` - Настраивает финальные эффекты
- `set_auto_return_delay(delay: float)` - Устанавливает задержку автовозврата
- `is_victory_active() -> bool` - Проверяет, активно ли поздравление

### Сигналы

- `victory_completed` - Вызывается при завершении поздравления

## Особенности

1. **Автоматическая локализация** - Поддерживает переводы через систему i18n
2. **Анимации** - Красивые анимации появления и исчезновения
3. **Эффекты** - Частицы и визуальные эффекты для празднования
4. **Автовозврат** - Автоматический возврат в меню через заданное время
5. **Обработка ввода** - Реагирует на любые нажатия клавиш для возврата

## Пример для 7-го уровня

```gdscript
extends "res://scripts/Game.gd"

var victory_manager: VictoryManager

func _ready() -> void:
    super._ready()
    
    # Создаем менеджер поздравления
    victory_manager = VictoryManager.new()
    add_child(victory_manager)
    
    # Настраиваем задержку автовозврата (12 секунд)
    victory_manager.set_auto_return_delay(12.0)

func _process(_delta: float) -> void:
    super._process(_delta)
    
    # Проверяем ввод для возврата в меню после победы
    if victory_manager and victory_manager.check_victory_input():
        return

func _show_win_panel() -> void:
    """Показываем поздравление с завершением игры"""
    if victory_manager:
        victory_manager.show_victory_message(score)

func _open_win_panel() -> void:
    """Открываем панель победы"""
    if victory_manager:
        victory_manager.show_victory_message(score)
```

## Преимущества

1. **Переиспользование** - Один скрипт для всех финальных уровней
2. **Консистентность** - Одинаковый стиль поздравления во всех уровнях
3. **Легкость поддержки** - Изменения в одном месте влияют на все уровни
4. **Гибкость** - Легко настраивать параметры для каждого уровня
5. **Чистота кода** - Основной скрипт уровня не засорен кодом поздравления
