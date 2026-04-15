extends Resource

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
}

#region Settings
@export_group("Settings")

## The minimum log level to output. Messages with a lower level will be ignored.
## This used to be an enum, but due to the lack of class_name support in modding,
## 	it was changed to a string. It will be validated to ensure it's a valid log level.
@export var level: String = "DEBUG"

## Whether to convert the timestamp to UTC before formatting it. If false, local time will be used.
@export var useUTC: bool = false

## The maximum stack depth to include in the log message. 0 for unlimited.
@export var maxDepth: int = 0

## The maximum number of messages to keep in the log. 0 for unlimited.
@export var maxMessageCount: int = 0
#endregion Settings

#region Formatting
@export_group("Formatting")

## Whether to include the time for when the log message was generated (e.g. [12:34:56])
@export var includeTime: bool = true
## Whether to include the date for when the log message was generated (e.g. [2024-01-01])
@export var includeDate: bool = false
## Whether to include the file source for the current stack frame
@export var includeFileSource: bool = true
## Whether to include the line number for the current stack frame.
@export var includeLine: bool = true
#endregion Formatting

static func FromDict(dict: Dictionary):
	var settings := new()
	settings.level = dict.get("level", settings.level)
	settings.useUTC = dict.get("useUTC", settings.useUTC)
	settings.maxDepth = dict.get("maxDepth", settings.maxDepth)
	settings.includeTime = dict.get("includeTime", settings.includeTime)
	settings.includeDate = dict.get("includeDate", settings.includeDate)
	settings.includeFileSource = dict.get("includeFileSource", settings.includeFileSource)
	settings.includeLine = dict.get("includeLine", settings.includeLine)
	return settings

func LoadDict(dict: Dictionary) -> void:
	level = dict.get("level", level)
	useUTC = dict.get("useUTC", useUTC)
	maxDepth = dict.get("maxDepth", maxDepth)
	includeTime = dict.get("includeTime", includeTime)
	includeDate = dict.get("includeDate", includeDate)
	includeFileSource = dict.get("includeFileSource", includeFileSource)
	includeLine = dict.get("includeLine", includeLine)

func LoadSettings(settings) -> void:
	level = settings.level
	useUTC = settings.useUTC
	maxDepth = settings.maxDepth
	includeTime = settings.includeTime
	includeDate = settings.includeDate
	includeFileSource = settings.includeFileSource
	includeLine = settings.includeLine

func Duplicate():
	return FromDict(ToDict())

func ToDict() -> Dictionary:
	return {
		"level": level,
		"useUTC": useUTC,
		"maxDepth": maxDepth,
		"includeTime": includeTime,
		"includeDate": includeDate,
		"includeFileSource": includeFileSource,
		"includeLine": includeLine,
	}
