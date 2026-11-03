@echo off
title CareTimeline Phone Installer
color 0A
echo ==========================================================
echo CareTimeline - Automatic Phone Installer
echo ==========================================================
echo.
echo [STEP 1] Plug your Samsung phone into the PC with USB cable.
echo [STEP 2] Unlock your phone screen.
echo [STEP 3] If asked 'Allow USB Debugging?', tap ALLOW.
echo.
echo Waiting for device connection...
"C:\Users\pooja\AppData\Local\Android\sdk\platform-tools\adb.exe" wait-for-device
echo.
echo [DEVICE CONNECTED!] Installing CareTimeline Release APK...
echo.
"C:\Users\pooja\AppData\Local\Android\sdk\platform-tools\adb.exe" install -r "C:\Users\pooja\ai project care\build\app\outputs\flutter-apk\app-release.apk"
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==========================================================
    echo [SUCCESS!] CareTimeline is now installed on your phone!
    echo Look for 'CareTimeline' on your phone app drawer.
    echo ==========================================================
) else (
    echo.
    echo [FAILED] Could not install. Make sure USB Debugging is ON.
)
echo.
pause
