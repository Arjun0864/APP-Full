@echo off
setlocal enabledelayedexpansion
title AIVista Studio - 1-Click Windows Release & Installer Builder

echo ===============================================================================
echo                AIVISTA STUDIO - 1-CLICK WINDOWS RELEASE BUILDER
echo ===============================================================================
echo.

set "SCRIPT_DIR=%~dp0"
echo [1/6] Finding Flutter project directory...

set "PROJECT_DIR="
if exist "%SCRIPT_DIR%pubspec.yaml" (
    set "PROJECT_DIR=%SCRIPT_DIR%"
) else if exist "%SCRIPT_DIR%ai_video_generator_source\pubspec.yaml" (
    set "PROJECT_DIR=%SCRIPT_DIR%ai_video_generator_source\"
) else if exist "%CD%\pubspec.yaml" (
    set "PROJECT_DIR=%CD%\"
) else if exist "%CD%\ai_video_generator_source\pubspec.yaml" (
    set "PROJECT_DIR=%CD%\ai_video_generator_source\"
)

if "%PROJECT_DIR%"=="" (
    echo [ERROR] Could not find pubspec.yaml!
    echo Please make sure this script is in the project folder or the root folder.
    pause
    exit /b 1
)

echo [OK] Project directory located at: %PROJECT_DIR%
cd /d "%PROJECT_DIR%"

echo.
echo [2/6] Checking Flutter environment...
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Flutter not found in system PATH. Searching standard paths...
    if exist "C:\src\flutter\bin\flutter.bat" (
        set "PATH=C:\src\flutter\bin;%PATH%"
    ) else if exist "C:\flutter\bin\flutter.bat" (
        set "PATH=C:\flutter\bin;%PATH%"
    ) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
        set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
    ) else if exist "%USERPROFILE%\src\flutter\bin\flutter.bat" (
        set "PATH=%USERPROFILE%\src\flutter\bin;%PATH%"
    ) else if exist "C:\Program Files\flutter\bin\flutter.bat" (
        set "PATH=C:\Program Files\flutter\bin;%PATH%"
    ) else if exist "D:\flutter\bin\flutter.bat" (
        set "PATH=D:\flutter\bin;%PATH%"
    ) else (
        echo [ERROR] Flutter SDK is not installed or not in PATH.
        echo Please install Flutter or add it to PATH (e.g. C:\flutter\bin)
        pause
        exit /b 1
    )
)

echo [OK] Flutter SDK detected.
call flutter config --enable-windows-desktop

echo.
echo [3/6] Getting Flutter dependencies (pub get)...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] flutter pub get failed. Check your internet connection.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [4/6] Building Windows Release Native Executable (Release Mode)...
set "CMAKE_POLICY_VERSION_MINIMUM=3.5"
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] flutter build windows failed! Check build logs above.
    pause
    exit /b %ERRORLEVEL%
)

set "RELEASE_DIR="
if exist "%PROJECT_DIR%build\windows\x64\runner\Release\ai_video_generator.exe" (
    set "RELEASE_DIR=%PROJECT_DIR%build\windows\x64\runner\Release"
) else if exist "%PROJECT_DIR%build\windows\runner\Release\ai_video_generator.exe" (
    set "RELEASE_DIR=%PROJECT_DIR%build\windows\runner\Release"
)

if "%RELEASE_DIR%"=="" (
    echo [ERROR] Compiled Windows binary was not found in build directory!
    pause
    exit /b 1
)

echo [OK] Windows native release built successfully!
echo Binary path: %RELEASE_DIR%\ai_video_generator.exe

echo.
echo [5/6] Creating Standalone Ready-To-Run Portable Folder...
set "PORTABLE_DIR=%SCRIPT_DIR%AIVistaStudio_Windows_Release_Files"
if exist "%PORTABLE_DIR%" rd /s /q "%PORTABLE_DIR%"
mkdir "%PORTABLE_DIR%"
xcopy "%RELEASE_DIR%\*" "%PORTABLE_DIR%\" /E /I /Q /Y >nul
echo [OK] Standalone files copied to: %PORTABLE_DIR%

echo.
echo [6/6] Compiling Inno Setup EXE Installer...
set "ISCC_EXE="
if exist "C:\Program Files (x86)\Inno Setup 6\iscc.exe" (
    set "ISCC_EXE=C:\Program Files (x86)\Inno Setup 6\iscc.exe"
) else if exist "C:\Program Files\Inno Setup 6\iscc.exe" (
    set "ISCC_EXE=C:\Program Files\Inno Setup 6\iscc.exe"
) else if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" (
    set "ISCC_EXE=%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe"
) else (
    where iscc >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        set "ISCC_EXE=iscc"
    )
)

if "%ISCC_EXE%"=="" (
    echo [INFO] Inno Setup compiler (ISCC) not found. Attempting to install via winget...
    winget install --id JRSoftware.InnoSetup -e --silent >nul 2>nul
    if exist "C:\Program Files (x86)\Inno Setup 6\iscc.exe" (
        set "ISCC_EXE=C:\Program Files (x86)\Inno Setup 6\iscc.exe"
    ) else if exist "C:\Program Files\Inno Setup 6\iscc.exe" (
        set "ISCC_EXE=C:\Program Files\Inno Setup 6\iscc.exe"
    )
)

set "ISS_FILE="
if exist "%PROJECT_DIR%AIVistaStudio_Setup.iss" (
    set "ISS_FILE=%PROJECT_DIR%AIVistaStudio_Setup.iss"
) else if exist "%SCRIPT_DIR%AIVistaStudio_Setup.iss" (
    set "ISS_FILE=%SCRIPT_DIR%AIVistaStudio_Setup.iss"
)

if not "%ISCC_EXE%"=="" (
    if not "%ISS_FILE%"=="" (
        echo Compiling installer using: "%ISCC_EXE%" "%ISS_FILE%"
        "%ISCC_EXE%" "%ISS_FILE%"
        if exist "%PROJECT_DIR%AIVistaStudio_Setup_x64.exe" (
            copy /y "%PROJECT_DIR%AIVistaStudio_Setup_x64.exe" "%SCRIPT_DIR%AIVistaStudio_Setup_x64.exe" >nul
            if exist "%USERPROFILE%\Desktop" (
                copy /y "%PROJECT_DIR%AIVistaStudio_Setup_x64.exe" "%USERPROFILE%\Desktop\AIVistaStudio_Setup_x64.exe" >nul
            )
        )
    )
) else (
    echo [WARNING] Inno Setup is not installed. You can install it for free from:
    echo https://jrsoftware.org/isdl.php
    echo But your portable software is already 100%% ready to run in:
    echo %PORTABLE_DIR%\ai_video_generator.exe
)

echo.
echo ===============================================================================
echo                         BUILD COMPLETE - SUCCESS!
echo ===============================================================================
echo.
if exist "%SCRIPT_DIR%AIVistaStudio_Setup_x64.exe" (
    echo [1] Standalone Setup Installer:
    echo     "%SCRIPT_DIR%AIVistaStudio_Setup_x64.exe"
    echo.
)
echo [2] Direct Portable Folder (Double click ai_video_generator.exe to run):
echo     "%PORTABLE_DIR%\"
echo.
echo ===============================================================================
echo Opening output directory...
explorer.exe "%SCRIPT_DIR%"
pause
