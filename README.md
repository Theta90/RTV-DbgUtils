# DbgUtils - Road to Vostok Debug Utilities

A debugging utility mod that provides an in-game UI menu and logging tools
to assist with mod development and runtime diagnostics.

## Overview

DbgUtils is designed to enhance the modding experience by offering a convenient way to view logs and debug information directly within the game. It includes a custom logger that integrates with the UI, allowing mod developers to easily track events, errors, and other relevant data without needing to rely solely on external log files.

I made this due to the issue of Godot not flushing the log file until the game exits, which makes it difficult to see logs in real-time while testing mods. With DbgUtils, you can see your logs immediately in the in-game UI, making the development process smoother and more efficient.

## Features

- In-game debug UI menu overlay
- Custom runtime logger with UI integration
- Resizable debug panel
- Monospaced font rendering for clean log output
