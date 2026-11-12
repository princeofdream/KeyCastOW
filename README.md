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

## Author

lijin <princeofdream@outlook.com>

## License

MIT License
