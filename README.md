# KeyCastOW
keystroke visualizer for Windows, lets you easily display your keystrokes while recording screencasts.

* small footprint (one 100kb executable file)
* green and portable, only depends on windows system dlls
* prenty of settings for keystroke display
* hotkey to turn on/off


## build

  powershell -ExecutionPolicy Bypass -File .\build.ps1
  # Debug build:
  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Configuration Debug
  # Clean build outputs:
  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Clean

The script locates the Visual C++ toolchain, configures CMake and builds
`output/target/<Configuration>/keycastow.exe`.

## package

  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Package
  # custom version:
  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Package -Version 1.0.1

Creates in `output/package/`:

* `KeyCastOW-<version>-portable.zip` - portable ("green") build
* `KeyCastOW-<version>-setup.exe` - NSIS installer, per-user or all-users

The installer requires NSIS (`winget install NSIS.NSIS`). A per-user
install goes to `%LOCALAPPDATA%\Programs\KeyCastOW`; a per-machine install
goes to `Program Files` and keeps settings in `%APPDATA%\KeyCastOW`.

## Author

lijin <princeofdream@outlook.com>

## License

MIT License
