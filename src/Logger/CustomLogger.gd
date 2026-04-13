extends Node

var _customLoggerNode = CustomLoggerNode.new()

func GetNewLogger(customLoggerUI: Control) -> CustomLoggerNode.CustomLogger:
	return _customLoggerNode.GetNewLogger(customLoggerUI)

class CustomLoggerNode extends Node:
	func GetNewLogger(customLoggerUI: Control) -> CustomLogger:
		return CustomLogger.GetNewLogger(customLoggerUI)

	class CustomLogger extends Logger:
		var _customLoggerUI: Control = null

		static func GetNewLogger(customLoggerUI: Control) -> CustomLogger:
			var logger = CustomLogger.new()
			logger._customLoggerUI = customLoggerUI
			return logger

		func _init() -> void:
			OS.add_logger(self )
		
		func _log_message(message: String, _error: bool) -> void:
			if (!_customLoggerUI or !_customLoggerUI.is_node_ready()):
				return
			_customLoggerUI.DisplayTextBox.call_deferred(&"append_text", "[code]%s[/code]" % message)

		func _log_error(
				function: String,
				file: String,
				line: int,
				code: String,
				rationale: String,
				_editor_notify: bool,
				error_type: int,
				script_backtraces: Array[ScriptBacktrace]
		) -> void:
			if (!_customLoggerUI or !_customLoggerUI.is_node_ready()):
				return

			var prefix: String = ""

			# The column at which to print the trace. Should match the length of the
			# unformatted text above it.
			var trace_indent := 0

			match error_type:
				ERROR_TYPE_ERROR:
					prefix = "[color=#f54][b]ERROR:[/b]"
					trace_indent = 6
				ERROR_TYPE_WARNING:
					prefix = "[color=#fd4][b]WARNING:[/b]"
					trace_indent = 8
				ERROR_TYPE_SCRIPT:
					prefix = "[color=#f4f][b]SCRIPT ERROR:[/b]"
					trace_indent = 13
				ERROR_TYPE_SHADER:
					prefix = "[color=#4bf][b]SHADER ERROR:[/b]"
					trace_indent = 13
				
			var trace: String = "%*s %s (%s:%s)" % [trace_indent, "at:", function, file, line]
			var script_backtraces_text: String = ""

			for backtrace in script_backtraces:
				script_backtraces_text += backtrace.format(trace_indent - 3) + "\n"

			_customLoggerUI.DisplayTextBox.call_deferred(
					&"append_text",
					"[code]%s %s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
							prefix,
							code,
							rationale,
							trace,
							script_backtraces_text,
						]
				)

		func _notification(what: int) -> void:
			if (what == NOTIFICATION_PREDELETE):
				OS.remove_logger(self )