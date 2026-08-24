@echo off
setlocal enabledelayedexpansion

:: ---------------------------------------------------------------------------
::  Alchemy League Map Downloader — Windows Edition (ZIP-based)
::  Hardened version with Linux-inspired safety practices
:: ---------------------------------------------------------------------------

:: --- Configuration ----------------------------------------------------------
set "TARGET_FOLDER=resources\_common\random-map-scripts\Current_Alchemy_League_Maps_DO_NOT_DISTRIBUTE"
set "BASE_URL=https://raw.githubusercontent.com/Alchemy-AOE-Community/Alchemy-AOE-Community.github.io/main/site/resources"
set "ABOUT_URL=https://raw.githubusercontent.com/f-istvan/aoe2-Custom-Map-Downloader/main/about.txt"

:: --- Helper: fatal error ----------------------------------------------------
goto :main

:die
echo.
echo ======================================================
echo  ERROR: %*
echo  Aborting for safety.
echo ======================================================
echo.
pause
exit /b 1

:: --- Main -------------------------------------------------------------------
:main
echo Alchemy League Map Downloader (Windows - Safe ZIP version)
echo.

:: Allow override (same idea as Linux AOE2_PATH)
if defined AOE2_PATH (
    echo Using AOE2_PATH override: !AOE2_PATH!
    set "DEST_PATH=!AOE2_PATH!\%TARGET_FOLDER%"
) else (
    call :find_aoe_path
)

call :validate_dest_path

call :open_maps_folder
call :delete_all_files
call :download_zip_maps
call :download_about

echo.
echo Done. Maps installed successfully.
echo Location: !DEST_PATH!
exit /b 0

:: ---------------------------------------------------------------------------
:validate_dest_path
if not defined DEST_PATH (
    call :die "DEST_PATH is not set. Age of Empires 2 installation not found."
)
if "!DEST_PATH!"=="" (
    call :die "DEST_PATH is empty. Aborting to prevent data loss."
)

:: Extra sanity check – path should contain something that looks like AoE2
echo !DEST_PATH! | findstr /i "AoE2DE Age2DE resources" >nul
if errorlevel 1 (
    echo WARNING: DEST_PATH does not look like a typical AoE2 path.
    echo          !DEST_PATH!
    echo.
)

echo Validated target: !DEST_PATH!
echo.
exit /b 0

:: ---------------------------------------------------------------------------
:find_aoe_path
set "REG_PATH_STEAM=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 813780"

for /f "tokens=2*" %%A in ('reg query "%REG_PATH_STEAM%" /v InstallLocation 2^>nul') do set "AOE2_PATH=%%B"

if not defined AOE2_PATH (
    for /f "tokens=*" %%I in ('powershell -NoProfile -command "Get-AppxPackage -Name \"Microsoft.MSPhoenix\" | Select-Object -ExpandProperty InstallLocation"') do set "AOE2_PATH=%%I"
)

if defined AOE2_PATH (
    echo AoE2 installation found at: !AOE2_PATH!
    set "DEST_PATH=!AOE2_PATH!\%TARGET_FOLDER%"
) else (
    set "DEST_PATH="
)
exit /b 0

:: ---------------------------------------------------------------------------
:open_maps_folder
if not exist "!DEST_PATH!" mkdir "!DEST_PATH!" 2>nul

set "PARENT_PATH=!DEST_PATH!\.."
echo Opening maps folder: !PARENT_PATH!
explorer "!PARENT_PATH!"
exit /b 0

:: ---------------------------------------------------------------------------
:delete_all_files
:: This only runs after validate_dest_path has succeeded
if exist "!DEST_PATH!" (
    echo Deleting previous files in !DEST_PATH!...
    del /q "!DEST_PATH!\*.*" 2>nul
    echo Cleanup complete.
) else (
    echo Target folder does not exist yet – nothing to delete.
)
exit /b 0

:: ---------------------------------------------------------------------------
:download_zip_maps
echo Scanning for latest season ZIP...

set latest=0
set season=9

:scan_loop
set "TEST_URL=%BASE_URL%/ALS!season!/Map_Archive.zip"
set "TEST_ZIP=%TEMP%\als_test_!RANDOM!.zip"

echo Checking !TEST_URL! ...

powershell -NoProfile -command ^
    "try { Invoke-WebRequest -Uri '!TEST_URL!' -OutFile '!TEST_ZIP!' -UseBasicParsing -ErrorAction Stop } catch { exit 1 }" ^
    >nul 2>nul

if not exist "!TEST_ZIP!" goto scan_done

for %%A in ("!TEST_ZIP!") do if %%~zA==0 (
    del "!TEST_ZIP!" >nul 2>nul
    goto scan_done
)

powershell -NoProfile -command ^
    "try { Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::OpenRead('!TEST_ZIP!') | Out-Null; exit 0 } catch { exit 1 }" ^
    >nul 2>nul

if errorlevel 1 (
    del "!TEST_ZIP!" >nul 2>nul
    goto scan_done
)

set latest=!season!
set /a season+=1
del "!TEST_ZIP!" >nul 2>nul
goto scan_loop

:scan_done
if !latest!==0 (
    call :die "No valid season ZIPs found."
)

set "ZIP_URL=%BASE_URL%/ALS!latest!/Map_Archive.zip"
echo Latest season detected: ALS!latest!
echo.

set "TMP_ZIP=%TEMP%\alchemy_maps_!RANDOM!.zip"

echo Downloading ZIP...
powershell -NoProfile -command ^
    "Invoke-WebRequest -Uri '!ZIP_URL!' -OutFile '!TMP_ZIP!' -UseBasicParsing" ^
    >nul 2>nul

if not exist "!TMP_ZIP!" (
    call :die "ZIP download failed."
)

echo Extracting ZIP...
powershell -NoProfile -command ^
    "Expand-Archive -LiteralPath '!TMP_ZIP!' -DestinationPath '!DEST_PATH!' -Force" ^
    >nul 2>nul

echo Flattening folder structure...
for /r "!DEST_PATH!" %%F in (*.rms) do (
    move "%%F" "!DEST_PATH!" >nul 2>nul
)

for /d %%D in ("!DEST_PATH!\*") do (
    rmdir /s /q "%%D" >nul 2>nul
)

del "!TMP_ZIP!" >nul 2>nul
echo Maps installed successfully.
exit /b 0

:: ---------------------------------------------------------------------------
:download_about
echo Downloading about.txt...
powershell -NoProfile -command ^
    "Invoke-WebRequest -Uri '%ABOUT_URL%' -OutFile '!DEST_PATH!\about.txt' -UseBasicParsing" ^
    >nul 2>nul

if exist "!DEST_PATH!\about.txt" (
    echo about.txt installed.
) else (
    echo about.txt download failed (non-fatal).
)
exit /b 0
