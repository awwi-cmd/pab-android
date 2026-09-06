@echo off
REM ============================================================
REM  ARENA - rebuild & reinstall debug APK
REM  Double-click to run. Deletes old debug APK, rebuilds,
REM  installs on running emulator (launches Pixel_10 if needed).
REM ============================================================
setlocal enabledelayedexpansion
cd /d "%~dp0arena"

REM --- always use the known full path (avoids PATH ambiguity between the
REM     extensionless posix "flutter" shim and "flutter.bat" that "where"
REM     turns up together, which breaks quoted %VAR% calls below) ---
set FLUTTER=C:\src\flutter\bin\flutter.bat

set "APK=build\app\outputs\flutter-apk\app-debug.apk"

echo.
echo === 1. Delete old debug APK ===
if exist "%APK%" (
    del /f /q "%APK%"
    echo Deleted %APK%
) else (
    echo No existing APK found, skipping.
)

echo.
echo === 2. Check for running emulator ===
adb devices | findstr /r /c:"device$" >nul
if %errorlevel%==0 goto deviceready

echo No device/emulator online. Launching Pixel_10...
start "" "%FLUTTER%" emulators --launch Pixel_10
echo Waiting for emulator to come online, can take 30 to 90 seconds...

:waitloop
timeout /t 5 >nul
adb devices | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 goto waitloop
echo Emulator online.
goto afterdevice

:deviceready
echo Device/emulator already online.

:afterdevice

echo.
echo === 3. Build debug APK ===
call "%FLUTTER%" build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo BUILD FAILED. See errors above.
    pause
    exit /b 1
)

echo.
echo === 4. Install on emulator ===
call "%FLUTTER%" install --debug
if %errorlevel% neq 0 (
    echo.
    echo INSTALL FAILED. See errors above.
    pause
    exit /b 1
)

echo.
echo === Done. com.awwwi.arena installed and ready. ===
pause
