===============================================================================
               AIVISTA STUDIO - WINDOWS RELEASE INSTRUCTIONS
===============================================================================

HOW TO GENERATE WINDOWS SETUP (.EXE) WITH 1 CLICK:
--------------------------------------------------
1. Simply double-click:
   BUILD_WINDOWS_SETUP.bat

What this 1-click script does automatically:
--------------------------------------------
- Automatically locates pubspec.yaml (no more "pubspec.yaml nahi mila" errors).
- Runs 'flutter config --enable-windows-desktop'.
- Runs 'flutter pub get' and downloads all dependencies.
- Runs 'flutter build windows --release' to generate the 100% native Windows AOT binaries.
- Collects all DLLs, engine files, and data assets into a standalone folder:
  'AIVistaStudio_Windows_Release_Files'
- Uses Inno Setup (iscc.exe) to create the installer:
  'AIVistaStudio_Setup_x64.exe'
- Creates Desktop & Start Menu shortcuts and a clean uninstaller.
- Sets the working directory properly so the installed software runs immediately without errors.

WHY THE PREVIOUS ISS FILE GENERATED SOFTWARE DID NOT RUN:
---------------------------------------------------------
1. Inno Setup was run before running 'flutter build windows --release', meaning the
   Flutter engine, DLLs, and compiled executable were missing.
2. Inno Setup was missing the 'WorkingDir: "{app}"' parameter in [Icons] and [Run],
   causing the executable to look for assets in the wrong folder.
Both issues are now 100% fixed.

ONLINE / GITHUB ACTIONS BUILD (WITHOUT WINDOWS MACHINE):
--------------------------------------------------------
If you are on Mac and want to generate the Windows Setup.exe in the cloud:
1. Push your code to GitHub.
2. In GitHub, go to the 'Actions' tab.
3. Click 'Build & Package Windows Release' -> 'Run workflow'.
4. Download the ready 'AIVistaStudio_Setup_x64.exe' directly from GitHub Artifacts or Releases.
===============================================================================
