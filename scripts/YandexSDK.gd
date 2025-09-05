extends Node
## Скрипт для интеграции с SDK Яндекс Игр
## Обрабатывает показ рекламы: Interstitial и Rewarded

signal interstitial_closed(was_shown: bool)
signal rewarded_completed()
signal rewarded_closed()
signal ad_error(error_message: String)

var _last_interstitial_time: float = 0.0
const INTERSTITIAL_COOLDOWN: float = 50.0  # 50 секунд между показами

func _ready() -> void:
	# Подключаемся к JavaScript API
	if OS.has_feature("web"):
		_initialize_yandex_sdk()

func _initialize_yandex_sdk() -> void:
	# Регистрируем callback функции для JavaScript
	var js_code = """
		// Регистрируем функции для вызова из JavaScript
		window.godotCallbacks = {
			_on_interstitial_closed: function(wasShown) {
				if (window.godot && window.godot.call) {
					window.godot.call('_on_interstitial_closed', wasShown);
				}
			},
			_on_rewarded_completed: function() {
				if (window.godot && window.godot.call) {
					window.godot.call('_on_rewarded_completed');
				}
			},
			_on_rewarded_closed: function() {
				if (window.godot && window.godot.call) {
					window.godot.call('_on_rewarded_closed');
				}
			},
			_on_ad_error: function(error) {
				if (window.godot && window.godot.call) {
					window.godot.call('_on_ad_error', error);
				}
			}
		};
	"""
	
	JavaScriptBridge.eval(js_code)

func is_sdk_ready() -> bool:
	if not OS.has_feature("web"):
		print("YandexSDK: не веб-платформа")
		return false
	
	var js_code = "window.yandexSDKReady ? window.yandexSDKReady() : false"
	var result = JavaScriptBridge.eval(js_code)
	print("YandexSDK готов: ", result)
	return result

func show_interstitial() -> void:
	"""Показывает Interstitial рекламу при Game Over (не чаще 50 сек)"""
	if not OS.has_feature("web"):
		print("Interstitial: не веб-платформа, пропускаем")
		interstitial_closed.emit(false)
		return
	
	# Проверяем кулдаун
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_interstitial_time < INTERSTITIAL_COOLDOWN:
		print("Interstitial: кулдаун активен, пропускаем")
		interstitial_closed.emit(false)
		return
	
	# Проверяем готовность SDK
	if not is_sdk_ready():
		print("Interstitial: SDK не готов, пропускаем")
		interstitial_closed.emit(false)
		return
	
	print("Показываем Interstitial рекламу")
	_last_interstitial_time = current_time
	
	var js_code = """
		if (window.ysdk && window.ysdk.adv) {
			window.ysdk.adv.showFullscreenAdv({
				callbacks: {
					onClose: function(wasShown) {
						console.log('Interstitial closed, wasShown:', wasShown);
						window.godotCallbacks._on_interstitial_closed(wasShown);
					},
					onError: function(error) {
						console.error('Interstitial error:', error);
						window.godotCallbacks._on_ad_error('Interstitial: ' + error);
					}
				}
			});
		} else {
			console.log('Interstitial: SDK или adv не доступен');
			window.godotCallbacks._on_interstitial_closed(false);
		}
	"""
	
	JavaScriptBridge.eval(js_code)

func show_rewarded() -> void:
	"""Показывает Rewarded рекламу по кнопке Continue"""
	if not OS.has_feature("web"):
		print("Rewarded: не веб-платформа, даем награду")
		rewarded_completed.emit()
		rewarded_closed.emit()
		return
	
	# Проверяем готовность SDK
	if not is_sdk_ready():
		print("Rewarded: SDK не готов, даем награду")
		rewarded_completed.emit()
		rewarded_closed.emit()
		return
	
	print("Показываем Rewarded рекламу")
	
	var js_code = """
		if (window.ysdk && window.ysdk.adv) {
			window.ysdk.adv.showRewardedVideo({
				callbacks: {
					onOpen: function() {
						console.log('Rewarded ad opened');
					},
					onRewarded: function() {
						console.log('Rewarded ad completed');
						window.godotCallbacks._on_rewarded_completed();
					},
					onClose: function() {
						console.log('Rewarded ad closed');
						window.godotCallbacks._on_rewarded_closed();
					},
					onError: function(error) {
						console.error('Rewarded ad error:', error);
						window.godotCallbacks._on_ad_error('Rewarded: ' + error);
					}
				}
			});
		} else {
			console.log('Rewarded: SDK или adv не доступен, даем награду');
			window.godotCallbacks._on_rewarded_completed();
			window.godotCallbacks._on_rewarded_closed();
		}
	"""
	
	JavaScriptBridge.eval(js_code)

# Callback функции для JavaScript
func _on_interstitial_closed(was_shown: bool) -> void:
	print("Interstitial закрыта, показана: ", was_shown)
	interstitial_closed.emit(was_shown)

func _on_rewarded_completed() -> void:
	print("Rewarded реклама завершена, награда получена")
	rewarded_completed.emit()

func _on_rewarded_closed() -> void:
	print("Rewarded реклама закрыта")
	rewarded_closed.emit()

func _on_ad_error(error_message: String) -> void:
	print("Ошибка рекламы: ", error_message)
	ad_error.emit(error_message)
