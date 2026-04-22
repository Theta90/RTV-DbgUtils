extends Node

signal ConfigValueChanged(ConfigKey: String, NewValue: Variant)

static var DEFAULT_CONFIG_SETTINGS = {
	# General
	"openOnMenu": true,

	# Log Trimming
	"enableMaxLogCount": true,
	"maxLogCount": 1000,
	"maxLogTrimPercent": 0.25,

	# Keybinds
	"toggleDebugUIKey": Key.KEY_QUOTELEFT,
	"toggleMouseKey": Key.KEY_PERIOD,

	# Logging Colors
	"colorEntireMessage": true,
	"defaultColorDebug": Color("#c0c0c0"),
	"defaultColorInfo": Color("#74c0fc"),
	"defaultColorWarning": Color("#f3d963"),
	"defaultColorError": Color("#f54"),

	# Filtering
	"filterHighlightEnabled": true,
	"filterRemoveNonMatches": true,
	"filterHighlightColor": Color("#ffff00"),
	"filterTextColor": Color("black"),
}

const MOD_ID := "DbgUtils"
const MOD_NAME := "DbgUtils"
const FILE_PATH := "user://MCM/DbgUtils"
const FILE_NAME := "config.ini"

const gameData := preload("res://Resources/GameData.tres")

var MCM

var _localConfig: Dictionary[String, Array] = {

	#region General

	"General" = ["Category", "General", {
		"menu_pos" = 1
	}],

	"openOnMenu" = ["Bool", "openOnMenu", {
		"name" = "Open In Main Menu",
		"tooltip" = "Whether the mod should open in the main menu. The mod is still accessible in-game through the keybind to " +
			"toggle the UI, this only sets if the UI will appear when entering the main menu.",
		"category" = "General",
		"menu_pos" = 1
	}],

	#endregion General

	#region Log Trimming

	"Log Trimming" = ["Category", "Log Trimming", {
		"menu_pos" = 2
	}],

	"enableMaxLogCount" = ["Bool", "enableMaxLogCount", {
		"name" = "Enable Max Log Count",
		"tooltip" = "Whether to enable the maximum log count limit. When the number of logs exceeds the max log count, old logs will be removed to prevent performance issues.",
		"category" = "Log Trimming",
		"menu_pos" = 1
	}],

	"maxLogCount" = ["Int", "maxLogCount", {
		"name" = "Max Log Count",
		"tooltip" = "The maximum number of log messages that the log viewer will store. Setting this to a low number will help with performance. " +
			"Setting it to 0 will allow for unlimited log messages.",
		"category" = "Log Trimming",
		"menu_pos" = 2,
		"minRange" = 50,
		"maxRange" = 10000
	}],

	# The "soft target" means that this is just the goal of the trimming, but it may remove more or less depending on a few things.
	# If, when removing, the current logs minus the trimmed percentage is still greater than the max, this will be overridden to trim 
	#	enough logs to get under said max.
	"maxLogTrimPercent" = ["Float", "maxLogTrimPercent", {
		"name" = "Trim Percent Target",
		"tooltip" = "A soft target for the number of logs to remove when the max is exceeded. If the number of current logs minus the trim percentage is still " +
			"greater than the max, this will be overridden.",
		"category" = "Log Trimming",
		"menu_pos" = 3,
		"minRange" = 0.1,
		"maxRange" = 1.0,
		"step" = 0.05
	}],

	#endregion Log Trimming

	# openOnError

	#region Keybinds

	"Keybinds" = ["Category", "Keybinds", {
		"menu_pos" = 3
	}],

	"toggleDebugUIKey" = ["Keycode", "toggleDebugUIKey", {
		"name" = "Toggle UI Key",
		"tooltip" = "The key used to show and hide the UI layer for all the debug tools.",
		"defaultType" = "Key",
		"type" = "Key",
		"category" = "Keybinds",
		"menu_pos" = 1
	}],

	"toggleMouseKey" = ["Keycode", "toggleMouseKey", {
		"name" = "Toggle Mouse Key",
		"tooltip" = "The key used to toggle the mouse mode. The two primary mouse modes are; Input.MouseMode.MOUSE_MODE_CAPTURED, " +
			"where the mouse is locked to the center of the screen and hidden, and Input.MouseMode.MOUSE_MODE_CONFINED, where the " +
			"mouse is free and visible, but locked to the game window.",
		"defaultType" = "Key",
		"type" = "Key",
		"category" = "Keybinds",
		"menu_pos" = 2
	}],

	#endregion Keybinds

	#region Logging Colors

	"Logging Colors" = ["Category", "Logging Colors", {
		"menu_pos" = 4
	}],

	"colorEntireMessage" = ["Bool", "colorEntireMessage", {
		"name" = "Color Entire Lines",
		"tooltip" = "Whether the log level colors should apply to the entire line, or just the log level text at the start of the line.",
		"category" = "Logging Colors",
		"menu_pos" = 1
	}],

	"defaultColorDebug" = ["Color", "defaultColorDebug", {
		"name" = "Debug",
		"tooltip" = "The color used for log messages with the level 'DEBUG'.",
		"category" = "Logging Colors",
		"menu_pos" = 2
	}],

	"defaultColorInfo" = ["Color", "defaultColorInfo", {
		"name" = "Info",
		"tooltip" = "The color used for log messages with the level 'INFO'.",
		"category" = "Logging Colors",
		"menu_pos" = 3
	}],

	"defaultColorWarning" = ["Color", "defaultColorWarning", {
		"name" = "Warning",
		"tooltip" = "The color used for log messages with the level 'WARNING'.",
		"category" = "Logging Colors",
		"menu_pos" = 4
	}],

	"defaultColorError" = ["Color", "defaultColorError", {
		"name" = "Error",
		"tooltip" = "The color used for log messages with the level 'ERROR'.",
		"category" = "Logging Colors",
		"menu_pos" = 5
	}],

	#endregion Logging Colors

	#region Filtering

	"Filtering" = ["Category", "Filtering", {
		"menu_pos" = 5
	}],

	"filterHighlightEnabled" = ["Bool", "filterHighlightEnabled", {
		"name" = "Highlight Filter Matches",
		"tooltip" = "Whether to highlight the text that matches the filter in the log viewer. The color used for highlighting is determined by the 'Filter Highlight Color' setting.",
		"category" = "Filtering",
		"menu_pos" = 1
	}],

	"filterRemoveNonMatches" = ["Bool", "filterRemoveNonMatches", {
		"name" = "Remove Non-Matches",
		"tooltip" = "Whether to hide log messages that don't match the filter in the log viewer. If disabled, non-matching messages will remain. " +
			"If 'Highlight Filter Matches' is also disabled, filtering will be essentially disabled.",
		"category" = "Filtering",
		"menu_pos" = 2
	}],

	"filterHighlightColor" = ["Color", "filterHighlightColor", {
		"name" = "Filter Highlight Color",
		"tooltip" = "The color used to highlight the text that matches the filter in the log viewer.",
		"category" = "Filtering",
		"menu_pos" = 3
	}],

	"filterTextColor" = ["Color", "filterTextColor", {
		"name" = "Filter Text Color",
		"tooltip" = "The color used to color the text that matches the filter in the log viewer.",
		"category" = "Filtering",
		"menu_pos" = 4
	}],

	#endregion Filtering
}

var connectionError: Error = Error.OK
var isFirstUse: bool = true

func _ready() -> void:
	var keys = _localConfig.keys()
	for k in _localConfig.keys():
		if (_localConfig[k][0] == "Category"):
			continue
		
		_localConfig[k][2]["default"] = DEFAULT_CONFIG_SETTINGS[k]
		_localConfig[k][2]["value"] = DEFAULT_CONFIG_SETTINGS[k]
	
	const MCM_PATH := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"
	if (!ResourceLoader.exists(MCM_PATH)):
		connectionError = Error.ERR_FILE_MISSING_DEPENDENCIES
		return

	MCM = load(MCM_PATH)

	var result = _ConnectToMCM()
	connectionError = result[0]

	if (connectionError == Error.OK):
		for k in _localConfig.keys():
			if (_localConfig[k][0] == "Category"):
				continue

			ConfigValueChanged.emit(k, _localConfig[k][2]["value"])

func _ConnectToMCM() -> Array: # returns [Error, ConfigFile?]
	var result = [Error.OK, null]

	if (!MCM):
		connectionError = Error.ERR_FILE_MISSING_DEPENDENCIES
		return [connectionError, null]

	result = _LoadConfigFile()
	if (result[0] != Error.OK):
		return result

	_UpdateConfigProperties(result[1])
	_RegisterConfig()

	return result

func _RegisterConfig():
	var fileOnSaveCallbacks = {}
	fileOnSaveCallbacks[FILE_NAME] = _UpdateConfigProperties

	MCM.RegisterConfiguration(
		MOD_ID,
		MOD_NAME,
		FILE_PATH,
		"Allows for changing of nearly every setting in the game possible.",
		fileOnSaveCallbacks,
		self
	)

func _LoadConfigFile() -> Array:
	var configPath = "%s/%s" % [FILE_PATH, FILE_NAME]
	var result = [Error.OK, ConfigFile.new()] # [error, ConfigFile?]
		
	for k in _localConfig.keys():
		result[1].set_value(_localConfig[k][0], k, _localConfig[k][2])

	# If the config file doesn't exist, create it with the default settings. 
	# If it does exist, load it and update the config values.
	if !FileAccess.file_exists(configPath):
		if (!DirAccess.dir_exists_absolute(FILE_PATH)):
			result[0] = DirAccess.open("user://").make_dir(FILE_PATH)

		if (result[0] != Error.OK):
			return result
		
		result[0] = result[1].save(configPath)

	else:
		isFirstUse = false
		MCM.CheckConfigurationHasUpdated(MOD_ID, result[1], configPath)
		result[0] = result[1].load(configPath)

	return result

func _UpdateConfigProperties(config: ConfigFile):
	for key in _localConfig.keys():
		var section = _localConfig[key][0]
		
		if (_localConfig[key][0] == "Category"):
			continue

		var newValue = config.get_value(section, key)["value"]
		SetConfigValue(key, newValue)

func HasConfigKey(key: String) -> bool:
	return key in _localConfig

func GetLocalConfig(key: String) -> Variant:
	if (key in _localConfig):
		return _localConfig[key]
	return null

func GetConfigValue(key: String) -> Variant:
	return _localConfig[key][2]["value"]

func GetConfigValueOrDefault(key: String) -> Variant:
	if (key in _localConfig):
		return GetConfigValue(key)
	return DEFAULT_CONFIG_SETTINGS[key]

func SetConfigValue(key: String, value: Variant) -> void:
	if (!(key in _localConfig)):
		push_error("DbgUtilsModConfig Error: Tried to set a config value with an invalid key '%s'" % key)
		return

	var oldValue = GetConfigValue(key)
	if (value != oldValue):
		_localConfig[key][2]["value"] = value
		ConfigValueChanged.emit(key, value)
