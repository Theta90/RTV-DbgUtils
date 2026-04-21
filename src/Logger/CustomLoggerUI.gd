extends CanvasLayer

signal MenuCreated(newMenu: LoggerMenu)
signal MenuDestroyed(destroyedMenu: LoggerMenu)
signal MenuExpandedChanged(isExpanded: bool, menu: LoggerMenu)
signal MenuVisibilityChanged(isVisible: bool, menu: LoggerMenu)

static var ScenePath: String = "res://mods/DbgUtils/Logger/CustomLoggerUI.tscn"

const ModConfig := preload("res://mods/DbgUtils/MCM/ModConfig.gd")
const LoggerMenu := preload("res://mods/DbgUtils/Logger/LoggerMenu.gd")

var _visibilityDisabled: bool = false
var _loggerMenus: Array[LoggerMenu] = []

var dbg := preload("res://mods/DbgUtils/Dbg.gd").new("CustomLoggerUI", self , null)

func _ready() -> void:
	pass

func CreateMenu(modConfig: ModConfig) -> LoggerMenu:
	var newMenu = load(LoggerMenu.LoggerMenuPath).instantiate() as LoggerMenu

	_loggerMenus.append(newMenu)

	add_child(newMenu)

	newMenu.SetModConfig(modConfig)
	newMenu.ChangeVisibility(modConfig.GetConfigValueOrDefault("openOnMenu"))
	newMenu.UpdateWindowRect(newMenu.MENU_RECT)

	MenuCreated.emit(newMenu)

	return newMenu

# todo: allow for a lot of windows
func GetMenu(index: int = 0) -> LoggerMenu:
	if (_loggerMenus.size() > index):
		return _loggerMenus[index]
	else:
		return null

func ToggleVisibility(isVisible: bool = !_visibilityDisabled):
	ForEach(func(menu): menu.ChangeVisibility(isVisible))
	_visibilityDisabled = !isVisible

func MoveMenu(newPos: Vector2, index: int = 0):
	var menu = GetMenu(index)
	if (menu != null):
		menu.UpdateWindow(menu.size, newPos)

func HasAnyMenus() -> bool:
	return _loggerMenus.size() > 0

func HasAnyVisibleMenus() -> bool:
	return !_visibilityDisabled and Any(func(menu): return menu.visible)

func HasAnyHiddenMenus() -> bool:
	return _visibilityDisabled or Any(func(menu): return !menu.visible)

func HideAllMenus():
	ForEach(func(menu): menu.ChangeVisibility(false))
	_visibilityDisabled = true

func ShowAllMenus():
	ForEach(func(menu): menu.ChangeVisibility(true))
	_visibilityDisabled = false

func ClearAllMenus():
	ForEach(func(menu): menu.DisplayTextBox.text = "")

func DestroyAllMenus():
	ForEach(func(menu):
		menu.queue_free()
		emit_signal("MenuDestroyed", menu)
	)
	_loggerMenus.clear()
	_visibilityDisabled = false

func AddLog(msgData: Dictionary):
	ForEach(func(menu): (menu as LoggerMenu).AddLog(msgData))

#region "LINQ"

func First() -> LoggerMenu:
	return GetMenu(0)

func Last() -> LoggerMenu:
	return GetMenu(_loggerMenus.size() - 1)

## fn: (LoggerMenu) -> Variant
func Select(fn: Callable) -> Array[Variant]:
	var result: Array[Variant] = []
	for menu in _loggerMenus.duplicate():
		result.append(fn.call(menu))
	return result

## fn: (LoggerMenu) -> bool
func Where(fn: Callable) -> Array[LoggerMenu]:
	return _loggerMenus.filter(fn)

## fn: (LoggerMenu) -> void
func ForEach(fn: Callable) -> void:
	for menu in _loggerMenus.duplicate():
		fn.call(menu)

## fn: (LoggerMenu) -> bool
func Any(fn: Callable) -> bool:
	return _loggerMenus.any(func(menu): return fn.call(menu))

## fn: (LoggerMenu) -> bool
func All(fn: Callable) -> bool:
	return _loggerMenus.all(func(menu): return fn.call(menu))

#endregion "LINQ"

func _on_open_menu_pressed() -> void:
	pass

func _on_close_menu_pressed() -> void:
	pass

func _on_logger_menu_expanded_changed(isExpanded: bool, _window: LoggerMenu) -> void:
	emit_signal("MenuExpandedChanged", _window, isExpanded)

func _on_logger_menu_visibility_changed(isVisible: bool, _window: LoggerMenu) -> void:
	if (_visibilityDisabled and isVisible):
		_visibilityDisabled = false
	elif (!_visibilityDisabled and !isVisible):
		var hasVisibleMenus = Any(func(menu): return menu.visible)
		if (!hasVisibleMenus):
			_visibilityDisabled = true
	emit_signal("MenuVisibilityChanged", _window, isVisible)

#func _on_logger_menu_moved(_newPos: Vector2, _window: LoggerMenu) -> void:
#	emit_signal("MenuRectChanged", _window, _window.get_global_rect())
#
#func _on_logger_menu_resized(_newSize: Vector2, _window: LoggerMenu) -> void:
#	emit_signal("MenuRectChanged", _window, _window.get_global_rect())

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		DestroyAllMenus()