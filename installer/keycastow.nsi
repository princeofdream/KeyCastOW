Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; ---------------------------------------------------------------
; Build-time defines (passed by build.ps1 with /D)
; ---------------------------------------------------------------
!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!ifndef APP_VERSION4
  !define APP_VERSION4 "1.0.0.0"
!endif
!ifndef SOURCE_DIR
  !define SOURCE_DIR "..\output\target\Release"
!endif
!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "..\output\package"
!endif
!ifndef PROJECT_DIR
  !define PROJECT_DIR ".."
!endif

!define APP_NAME "KeyCastOW"
!define APP_PUBLISHER "lijin"
!define APP_EXE "keycastow.exe"
!define APP_REG_KEY "Software\KeyCastOW"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeyCastOW"

; ---------------------------------------------------------------
; Multi-user installation (per-user / all-users choice)
; ---------------------------------------------------------------
!define MULTIUSER_EXECUTIONLEVEL Highest
!define MULTIUSER_MUI
!define MULTIUSER_INSTALLMODE_COMMANDLINE
!define MULTIUSER_INSTALLMODE_INSTDIR "KeyCastOW"
!define MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_KEY "${APP_REG_KEY}"
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME "InstallDir"
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_KEY "${APP_REG_KEY}"
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME "InstallMode"
!include "MultiUser.nsh"

Name "${APP_NAME}"
BrandingText "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTPUT_DIR}\KeyCastOW-${APP_VERSION}-setup.exe"
InstallDir "$PROGRAMFILES\KeyCastOW"
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "${PROJECT_DIR}\keycastow.ico"
!define MUI_UNICON "${PROJECT_DIR}\keycastow.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "运行 ${APP_NAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MULTIUSER_PAGE_INSTALLMODE
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${APP_VERSION4}"
VIAddVersionKey /LANG=2052 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=2052 "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey /LANG=2052 "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey /LANG=2052 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=2052 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=2052 "LegalCopyright" "Copyright (C) 2026 ${APP_PUBLISHER}"
VIAddVersionKey /LANG=1033 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=1033 "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey /LANG=1033 "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (C) 2026 ${APP_PUBLISHER}"

Function .onInit
  !insertmacro MULTIUSER_INIT
FunctionEnd

Function un.onInit
  !insertmacro MULTIUSER_UNINIT
FunctionEnd

Function WriteUninstallRegistry
  ; SHCTX follows SetShellVarContext, which MultiUser.nsh already set
  ; to HKCU (current user) or HKLM (all users).
  WriteRegStr SHCTX "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr SHCTX "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr SHCTX "${UNINST_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr SHCTX "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE},0"
  WriteRegStr SHCTX "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr SHCTX "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr SHCTX "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD SHCTX "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD SHCTX "${UNINST_KEY}" "NoRepair" 1

  ${GetSize} "$INSTDIR" "/S=0K" $1 $2 $3
  WriteRegDWORD SHCTX "${UNINST_KEY}" "EstimatedSize" $1

  ${If} $MultiUser.InstallMode == "AllUsers"
    WriteRegStr HKLM "${APP_REG_KEY}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "${APP_REG_KEY}" "InstallMode" "AllUsers"
  ${Else}
    WriteRegStr HKCU "${APP_REG_KEY}" "InstallDir" "$INSTDIR"
    WriteRegStr HKCU "${APP_REG_KEY}" "InstallMode" "CurrentUser"
  ${EndIf}
FunctionEnd

Section "!${APP_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  SetOverwrite on

  ; Replace a running instance so the executable can be updated.
  nsExec::ExecToLog 'taskkill /IM ${APP_EXE} /F'

  File "${SOURCE_DIR}\${APP_EXE}"
  File "${PROJECT_DIR}\README.md"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  Call WriteUninstallRegistry
SectionEnd

Section "开始菜单快捷方式" SecStartMenu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\卸载 ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section "桌面快捷方式" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

LangString DESC_SecMain ${LANG_SIMPCHINESE} "KeyCastOW 主程序和使用说明。"
LangString DESC_SecStartMenu ${LANG_SIMPCHINESE} "在开始菜单中创建快捷方式。"
LangString DESC_SecDesktop ${LANG_SIMPCHINESE} "在桌面上创建快捷方式。"
LangString DESC_SecMain ${LANG_ENGLISH} "KeyCastOW program files and documentation."
LangString DESC_SecStartMenu ${LANG_ENGLISH} "Create Start Menu shortcuts."
LangString DESC_SecDesktop ${LANG_ENGLISH} "Create a desktop shortcut."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_SecMain)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} $(DESC_SecStartMenu)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} $(DESC_SecDesktop)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  nsExec::ExecToLog 'taskkill /IM ${APP_EXE} /F'

  ${If} $MultiUser.InstallMode == "AllUsers"
    DeleteRegKey HKLM "${UNINST_KEY}"
    DeleteRegKey HKLM "${APP_REG_KEY}"
    SetShellVarContext all
  ${Else}
    DeleteRegKey HKCU "${UNINST_KEY}"
    DeleteRegKey HKCU "${APP_REG_KEY}"
    SetShellVarContext current
  ${EndIf}

  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\卸载 ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"

  ; Remove shortcuts that may have been created for the other user context.
  ${If} $MultiUser.InstallMode == "AllUsers"
    SetShellVarContext current
  ${Else}
    SetShellVarContext all
  ${EndIf}

  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\卸载 ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"

  RMDir /r "$INSTDIR"
SectionEnd
