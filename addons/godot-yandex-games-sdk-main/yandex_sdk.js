let ysdk;
function InitGame(params, callback) {
	console.log("Yandex SDK start initialization");
	YaGames.init(params)
		.then((_sdk) => {
			ysdk = _sdk;
			console.log("Yandex SDK initialized");

			console.log("Game initialized");
			console.log("Environment", ysdk.environment);

			// Настраиваем обработчики паузы и возобновления
			setupPauseResumeHandlers();

			callback(ysdk.environment);
		})
		.catch((err) => {
			console.log(err);
			console.log("Game initialization error");
		});
}

function GameReady() {
	ysdk.features.LoadingAPI?.ready();
	console.log("Game ready");
}

// LoadingAPI - уведомление о готовности игры
function LoadingReady() {
	ysdk.features.LoadingAPI?.ready();
	console.log("Loading API ready");
}

// Обработка событий паузы и возобновления игры
function setupPauseResumeHandlers() {
	if (ysdk && ysdk.on) {
		// Обработка события паузы игры
		ysdk.on('game_api_pause', () => {
			console.log("Game paused");
			// Здесь можно добавить логику паузы игры
		});
		
		// Обработка события возобновления игры
		ysdk.on('game_api_resume', () => {
			console.log("Game resumed");
			// Здесь можно добавить логику возобновления игры
		});
	}
}

let player;
function InitPlayer(full, callback) {
	console.log("Player start initialization");
	ysdk
		.getPlayer(full)
		.then((_player) => {
			player = _player;
			console.log("Player initialized");

			callback();
		})
		.catch((err) => {
			console.log(err);
			console.log("Player initialization error");
		});
}

function OpenAuthDialog() {
	if (player.getMode() === "lite") {
		// Игрок не авторизован.
		ysdk.auth
			.openAuthDialog()
			.then(() => {
				// Игрок успешно авторизован
				player.catch((err) => {
					// Ошибка при инициализации объекта Player.
				});
			})
			.catch(() => {
				// Игрок не авторизован.
			});
	}
}

// Yandex SDK analytics
function GameplayStarted() {
	ysdk.features.GameplayAPI.start();
	console.log("Gameplay started (js)");
}

function GameplayStopped() {
	ysdk.features.GameplayAPI.stop();
	console.log("Gameplay stopped (js)");
}

// Leader boards
function GetLeaderboardDescription(leaderboardName, callback) {
	ysdk.getLeaderboards()
		.then(lb => lb.getDescription(leaderboardName))
		.then((result) => {
			console.log("Leaderboard description:");
			console.log(result);
			callback("loaded", result);
		})
		.catch((error) => {
			console.error("Error loading leaderboard description:", error);
			callback("error");
		});
}

function CheckAuth(callback) {
	ysdk.isAvailableMethod("leaderboards.setLeaderboardScore").then(
		(result) => {
			console.log(result);
			callback(result);
		},
		(error) => {
			console.log("isAvailableMethod setLeaderboardScore error");
			callback(false);
		},
	);
}

function SaveLeaderboardScore(leaderboardName, score, extraData, callback) {
	console.log(
		"Save leaderboard score",
		score,
		"on",
		leaderboardName,
		"with",
		extraData,
	);
	ysdk.getLeaderboards()
		.then(lb => lb.setScore(leaderboardName, score, extraData))
		.then(() => {
			console.log("Leaderboard score saved");
			if (callback) callback("saved");
		})
		.catch(err => {
			console.error("Error saving leaderboard score:", err);
			if (callback) callback("error");
		});
}

function LoadLeaderboardPlayerEntry(leaderboardName, callback) {
	ysdk.getLeaderboards()
		.then(lb => lb.getPlayerEntry(leaderboardName))
		.then((res) => {
			console.log("Loaded leaderboard player entry:", res);
			callback("loaded", JSON.stringify(res));
		})
		.catch((err) => {
			console.error("Error loading leaderboard player entry:", err);
			if (err.code === "LEADERBOARD_PLAYER_NOT_PRESENT") {
				console.log("У игрока нет записи в лидерборде");
			}
			callback("error");
		});
}

function LoadLeaderboardEntries(
	leaderboardName,
	includeUser,
	quantityAround,
	quantityTop,
	callback,
) {
	ysdk.getLeaderboards()
		.then(lb => lb.getEntries(leaderboardName, {
			includeUser: includeUser,
			quantityAround: quantityAround,
			quantityTop: quantityTop,
		}))
		.then((res) => {
			console.log("Loaded leaderboard entries:", res);
			callback("loaded", JSON.stringify(res));
		})
		.catch((err) => {
			console.error("Error loading leaderboard entries:", err);
			if (err.code === "LEADERBOARD_NOT_FOUND") {
				console.log("Лидерборд не найден.");
			}
			callback("error");
		});
}

function ShowAd(callback) {
	console.log("Show ad");
	ysdk.adv.showFullscreenAdv({
		callbacks: {
			onClose: function (wasShown) {
				callback("closed");
				console.log("Ad shown");
			},
			onError: function (error) {
				callback("error");
				console.log("Ad error", error);
			},
			onOpen: function () {
				callback("opened");
				console.log("Ad open");
			},
			onOffline: function () {
				callback("offline");
				console.log("Ad offline");
			},
		},
	});
}

function ShowAdRewardedVideo(callback) {
	console.log("Show rewarded video");
	ysdk.adv.showRewardedVideo({
		callbacks: {
			onOpen: () => {
				callback("opened");
				console.log("Rewarded video open.");
			},
			onRewarded: () => {
				callback("rewarded");
				console.log("Rewarded!");
			},
			onClose: () => {
				callback("closed");
				console.log("Rewarded video ad closed.");
			},
			onError: (e) => {
				callback("error");
				console.log("Error while open rewarded video ad:", e);
			},
		},
	});
}

function SaveData(data, force) {
	console.log("Data save ", data);
	player.setData(data, force).then((result) => {
		console.log("Data saved ", result, " ", data);
	});
}

function SaveStats(data) {
	console.log("Stats save ", data);
	player.setStats(data).then((result) => {
		console.log("Stats saved ", result, " ", data);
	});
}

function loadAllData(callback) {
	player.getData().then((result) => {
		console.log("Data loaded ", result);
		callback(result);
	});
}

function LoadData(keys, callback) {
	console.log("Data load ", keys);
	player.getData(keys).then((result) => {
		console.log("Data loaded ", result);
		callback(result);
	});
}

function loadAllStats(callback) {
	console.log("All stats load");
	player.getStats().then((result) => {
		console.log("Stats loaded ", result);
		callback(result);
	});
}

function LoadStats(keys, callback) {
	console.log("Stats load ", keys);
	player.getStats(keys).then((result) => {
		console.log("Stats loaded ", result);
		callback(result);
	});
}

function incrementStats(increments, callback) {
	player.incrementStats(increments).then((result) => {
		console.log("Stats incremented ", result);
		callback(result);
	});
}

// Переменные окружения
function LoadEnvironmentVariables(callback) {
	console.log("Loading environment variables");
	if (ysdk && ysdk.environment) {
		callback(ysdk.environment);
	} else {
		callback({});
	}
}

// Серверное время
function GetServerTime(callback) {
	console.log("Getting server time");
	if (ysdk && ysdk.features && ysdk.features.ServerTimeAPI) {
		ysdk.features.ServerTimeAPI.getServerTime().then((time) => {
			callback(time);
		}).catch((error) => {
			console.error("Error getting server time:", error);
			callback(0);
		});
	} else {
		// Fallback на локальное время
		callback(Date.now());
	}
}

// Ярлык на рабочий стол
function CreateShortcut(callback) {
	console.log("Creating shortcut");
	if (ysdk && ysdk.features && ysdk.features.ShortcutAPI) {
		ysdk.features.ShortcutAPI.canPrompt().then((canPrompt) => {
			if (canPrompt) {
				ysdk.features.ShortcutAPI.prompt().then(() => {
					console.log("Shortcut created");
					callback();
				}).catch((error) => {
					console.error("Error creating shortcut:", error);
					callback();
				});
			} else {
				console.log("Shortcut prompt not available");
				callback();
			}
		}).catch((error) => {
			console.error("Error checking shortcut availability:", error);
			callback();
		});
	} else {
		console.log("Shortcut API not available");
		callback();
	}
}

// Оценка игры
function RequestRating(callback) {
	console.log("Requesting rating");
	if (ysdk && ysdk.features && ysdk.features.FeedbackAPI) {
		ysdk.features.FeedbackAPI.canReview().then((canReview) => {
			if (canReview) {
				ysdk.features.FeedbackAPI.requestReview().then(() => {
					console.log("Rating requested");
					callback();
				}).catch((error) => {
					console.error("Error requesting rating:", error);
					callback();
				});
			} else {
				console.log("Rating not available");
				callback();
			}
		}).catch((error) => {
			console.error("Error checking rating availability:", error);
			callback();
		});
	} else {
		console.log("Feedback API not available");
		callback();
	}
}

// Ссылки на другие игры
function LoadGameLinks(callback) {
	console.log("Loading game links");
	if (ysdk && ysdk.features && ysdk.features.GameplayAPI) {
		// Получаем ссылки на другие игры через GameplayAPI
		ysdk.features.GameplayAPI.getGameLinks().then((links) => {
			console.log("Game links loaded:", links);
			callback(links || []);
		}).catch((error) => {
			console.error("Error loading game links:", error);
			callback([]);
		});
	} else {
		console.log("Game links API not available");
		callback([]);
	}
}
