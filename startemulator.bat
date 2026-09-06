@echo off
REM ============================================================
REM  ARENA - start the Pixel_10 emulator
REM  Double-click to run. This window IS the emulator process --
REM  closing this window (or Ctrl+C) closes the emulator with it.
REM  Leave it open while you build/install/play; close it when done.
REM ============================================================
setlocal enabledelayedexpansion

set EMULATOR=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe
set AVD=Pixel_10

if not exist "%EMULATOR%" (
    echo Emulator not found at %EMULATOR%
    echo Check the Android SDK install location.
    pause
    exit /b 1
)

echo.
echo === Checking for an already-running device/emulator ===
adb devices | findstr /r /c:"device$" >nul
if %errorlevel%==0 (
    echo A device/emulator is already online. Not starting a second one.
    echo Close this window, or run "adb devices" to see what is connected.
    pause
    exit /b 0
)

echo.
echo === Starting %AVD% ===
echo This window is the emulator. Closing it shuts the emulator down.
echo.
"%EMULATOR%" -avd %AVD%

echo.
echo === Emulator process ended ===
pause
