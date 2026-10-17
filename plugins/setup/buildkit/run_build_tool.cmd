@echo off
setlocal

if /I not "%~1"=="ohos" (
  echo Unsupported native build target: %~1 1>&2
  exit /b 2
)
if /I not "%~3"=="arm64" (
  echo HarmonyOS Core build currently supports only arm64. 1>&2
  exit /b 2
)

if not defined OHOS_NDK_HOME (
  if defined HOS_SDK_HOME set "OHOS_NDK_HOME=%HOS_SDK_HOME%\default\openharmony"
  if not defined OHOS_NDK_HOME if defined DEVECO_SDK_HOME set "OHOS_NDK_HOME=%DEVECO_SDK_HOME%\sdk\default\openharmony"
)

set "PROJECT_ROOT=%~dp0..\..\.."
bash "%PROJECT_ROOT%\tool\build_libclash_ohos.sh"
exit /b %ERRORLEVEL%
