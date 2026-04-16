extends Node

signal ConfigValueChanged(ConfigKey: String, NewValue: Variant)

static var DEFAULT_CONFIG_SETTINGS = {
	"openOnMenu": true,
	"toggleDebugUIKey": Key.KEY_QUOTELEFT,
	"toggleMouseKey": Key.KEY_PERIOD,
	"colorEntireLine": true,
	"defaultColorDebug": Color("#c0c0c0"),
	"defaultColorInfo": Color("#74c0fc"),
	"defaultColorWarning": Color("#f3d963"),
	"defaultColorError": Color("#f54"),
}

const MOD_ID := "DbgUtils"
const MOD_NAME := "DbgUtils"
const FILE_PATH := "user://MCM/DbgUtils"

const gameData := preload("res://Resources/GameData.tres")
const MCM := preload("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
const MCMNotInstalledUI := preload("res://mods/DbgUtils/MCM/mcm_not_installed.tscn")

var dbg := preload("res://mods/DbgUtils/Dbg.gd").new("DbgUtilsModConfig", self , null)

var _localConfig = {
	"openOnMenu" = ["Bool", "openOnMenu", {
		"name" = "Open In Main Menu",
		"tooltip" = "Whether the mod should open in the main menu. The mod is still accessible in-game through the keybind to " +
			"toggle the UI, this only sets if the UI will appear when entering the main menu.",
		"category" = "General",
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

	"colorEntireLine" = ["Bool", "colorEntireLine", {
		"name" = "Color Entire Lines",
		"tooltip" = "Whether the log level colors should apply to the entire line, or just the log level text at the start of the line.",
		"category" = "Logging Colors",
		"menu_pos" = 1
	}],

	"defaultColorDebug" = ["Color", "defaultColorDebug", {
		"name" = "Logging Color: 1. Debug",
		"tooltip" = "The color used for log messages with the level 'DEBUG'.",
		"category" = "Logging Colors",
		"menu_pos" = 2
	}],

	"defaultColorInfo" = ["Color", "defaultColorInfo", {
		"name" = "Logging Color: 2. Info",
		"tooltip" = "The color used for log messages with the level 'INFO'.",
		"category" = "Logging Colors",
		"menu_pos" = 3
	}],

	"defaultColorWarning" = ["Color", "defaultColorWarning", {
		"name" = "Logging Color: 3. Warning",
		"tooltip" = "The color used for log messages with the level 'WARNING'.",
		"category" = "Logging Colors",
		"menu_pos" = 4
	}],

	"defaultColorError" = ["Color", "defaultColorError", {
		"name" = "Logging Color: 4. Error",
		"tooltip" = "The color used for log messages with the level 'ERROR'.",
		"category" = "Logging Colors",
		"menu_pos" = 5
	}],

	"General" = ["Category", "General", {
		"menu_pos" = 1
	}],

	"Keybinds" = ["Category", "Keybinds", {
		"menu_pos" = 2
	}],

	"Logging Colors" = ["Category", "Logging Colors", {
		"menu_pos" = 3
	}]
}

func _ready() -> void:
	dbg.debug("Initializing...")

	for k in _localConfig.keys():
		if (_localConfig[k][0] == "Category"):
			continue
		
		_localConfig[k][2]["default"] = DEFAULT_CONFIG_SETTINGS[k]
		_localConfig[k][2]["value"] = DEFAULT_CONFIG_SETTINGS[k]
	
	var result = _ConnectToMCM()
	var error: Error = result[0]

	if (error == Error.OK):
		dbg.info("%s connected to MCM successfully" % MOD_NAME)

		for k in _localConfig.keys():
			if (_localConfig[k][0] == "Category"):
				continue

			ConfigValueChanged.emit(k, _localConfig[k][2]["value"])
	else:
		dbg.error("%s failed to connect to MCM with the error: %s" % [MOD_NAME, error_string(error)])
		
		var _notInstalledUI = MCMNotInstalledUI.instantiate()
		_notInstalledUI.find_child("Link").pressed.connect(func():
			OS.shell_open("https://modworkshop.net/mod/53713")
		)
		_notInstalledUI.find_child("Quit").pressed.connect(func():
			Loader.Quit()
		)
		_notInstalledUI.find_child("Description").text = (
			("Mod Configuration Menu must be installed to use %s. " % MOD_NAME) +
			"The button below will take you to the MCM ModWorkshop page."
		)
			
		for _element in get_parent().get_children():
			if _element.name == "Menu":
				_element.find_child("Main").hide()
				_element.add_child(_notInstalledUI)
				return

	#dbg.debug("Initialization complete.")

func _ConnectToMCM() -> Array: # returns [Error, ConfigFile?]
	var result = [Error.OK, null]

	if (!MCM):
		result[0] = Error.ERR_FILE_MISSING_DEPENDENCIES
		dbg.warning("MCM is not installed, but DbgUtils needs it as a dependency!")
		return result

	result = _LoadConfigFile()
	if (result[0] != Error.OK):
		return result

	_UpdateConfigProperties(result[1])
	_RegisterConfig()

	return result

func _RegisterConfig():
	MCM.RegisterConfiguration(
		MOD_ID,
		MOD_NAME,
		FILE_PATH,
		"Allows for changing of nearly every setting in the game possible.",
		{
			"config.ini" = _UpdateConfigProperties
		},
		self
	)

func _LoadConfigFile() -> Array:
	var configPath = FILE_PATH + "/config.ini"
	var result = [Error.OK, ConfigFile.new()] # [error, ConfigFile?]
		
	for k in _localConfig.keys():
		result[1].set_value(_localConfig[k][0], k, _localConfig[k][2])

	if !FileAccess.file_exists(configPath):
		result[0] = DirAccess.open("user://").make_dir(FILE_PATH)

		if (result[0] != Error.OK):
			return result
		
		result[0] = result[1].save(configPath)

		dbg.info("Thanks for using DbgUtils! A config file has been created at %s. " +
			"These settings can be changed via MCM (if installed). Enjoy!!" % configPath)

	else:
		MCM.CheckConfigurationHasUpdated(MOD_ID, result[1], configPath)
		result[0] = result[1].load(configPath)

	return result

func _UpdateConfigProperties(config: ConfigFile):
	#dbg.debug("_UpdateConfigProperties called, updates:")
	for key in _localConfig.keys():
		var section = _localConfig[key][0]
		
		if (_localConfig[key][0] == "Category"):
			continue

		var newValue = config.get_value(section, key)["value"]
		SetLocalConfigValue(key, newValue)
		
	#dbg.debug("-> _UpdateConfigProperties ended")

func GetLocalConfig(key: String) -> Variant:
	return _localConfig[key]

func GetLocalConfigValue(key: String) -> Variant:
	return _localConfig[key][2]["value"]

func SetLocalConfigValue(key: String, value: Variant) -> void:
	var oldValue = GetLocalConfigValue(key)
	if (value != oldValue):
		_localConfig[key][2]["value"] = value
		ConfigValueChanged.emit(key, value)
