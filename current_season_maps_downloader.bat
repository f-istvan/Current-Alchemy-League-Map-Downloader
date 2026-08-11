@echo off
setlocal enabledelayedexpansion

:: ---------------------------------------------------------------------------
::  Alchemy League Map Downloader — Windows Edition (ZIP-based, validated)
:: ---------------------------------------------------------------------------

:: --- Configuration ----------------------------------------------------------

set "TARGET_FOLDER=resources\_common\random-map-scripts\Current_Alchemy_League_Maps_DO_NOT_DISTRIBUTE"
set "BASE_URL=https://raw.githubusercontent.com/Alchemy-AOE-Community/Alchemy-AOE-Community.github.io/main/site/resources"
set "ABOUT_URL=https://raw.githubusercontent.com/f-istvan/aoe2-Custom-Map-Downloader/main/about.txt"

call :find_aoe_path
call :open_maps_folder
call :delete_all_files
call :download_zip_maps
call :download_about
exit /b

:: ---------------------------------------------------------------------------
:download_zip_maps
call :find_aoe_path

echo Downloading and installing latest maps to: !DEST_PATH!
if not exist "!DEST_PATH!" mkdir "!DEST_PATH!"

echo Scanning for latest season ZIP...

set latest=0
set season=9

:scan_loop
set "TEST_URL=%BASE_URL%/ALS!season!/Map_Archive.zip"
set "TEST_ZIP=%TEMP%\als_test.zip"

echo Checking !TEST_URL! ...

:: Download the ZIP
powershell -command ^
    "Invoke-WebRequest -Uri '!TEST_URL!' -OutFile '!TEST_ZIP!' -UseBasicParsing" ^
    >nul 2>nul

:: If file does not exist → invalid
if not exist "!TEST_ZIP!" (
    goto scan_done
)

:: If file is zero bytes → invalid
for %%A in ("!TEST_ZIP!") do if %%~zA==0 (
    del "!TEST_ZIP!"
    goto scan_done
)

:: Validate ZIP using .NET (reliable)
powershell -command ^
    "try { Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::OpenRead('%TEST_ZIP%') | Out-Null; exit 0 } catch { exit 1 }" ^
    >nul 2>nul

if errorlevel 1 (
    del "!TEST_ZIP!"
    goto scan_done
)

:: ZIP is valid → record season
set latest=!season!
set /a season+=1

del "!TEST_ZIP!"
goto scan_loop

:scan_done

if %latest%==0 (
    echo ERROR: No valid season ZIPs found.
    pause
    exit /b 1
)

set "ZIP_URL=%BASE_URL%/ALS%latest%/Map_Archive.zip"
echo Latest season detected: ALS%latest%
echo ZIP URL: %ZIP_URL%
echo.

set "TMP_ZIP=%TEMP%\alchemy_maps.zip"

echo Downloading ZIP...
powershell -command ^
    "Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%TMP_ZIP%' -UseBasicParsing" ^
    >nul 2>nul

if not exist "%TMP_ZIP%" (
    echo ERROR: ZIP download failed.
    pause
    exit /b 1
)

echo Extracting ZIP...
powershell -command ^
    "Expand-Archive -LiteralPath '%TMP_ZIP%' -DestinationPath '%DEST_PATH%' -Force" ^
    >nul 2>nul

echo Flattening folder structure...
for /r "%DEST_PATH%" %%F in (*.rms) do (
    move "%%F" "%DEST_PATH%" >nul
)

for /d %%D in ("%DEST_PATH%\*") do (
    rmdir /s /q "%%D"
)

echo Maps installed successfully.
exit /b

:: ---------------------------------------------------------------------------
:open_maps_folder
call :find_aoe_path

if not exist "!DEST_PATH!" mkdir "!DEST_PATH!"

set "PARENT_PATH=!DEST_PATH!\.."
echo Opening maps folder: !PARENT_PATH!
explorer "!PARENT_PATH!"
exit /b

:: ---------------------------------------------------------------------------
:find_aoe_path
set "REG_PATH_STEAM=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 813780"

for /f "tokens=2*" %%A in ('reg query "%REG_PATH_STEAM%" /v InstallLocation 2^>nul') do set "AOE2_PATH=%%B"

if not defined AOE2_PATH (
    for /f "tokens=*" %%I in ('powershell -command "Get-AppxPackage -Name \"Microsoft.MSPhoenix\" | Select-Object -ExpandProperty InstallLocation"') do set "AOE2_PATH=%%I"
)

if defined AOE2_PATH (
    echo AoE2 installation found at: !AOE2_PATH!
    set "DEST_PATH=!AOE2_PATH!\%TARGET_FOLDER%"
    echo Target directory: !DEST_PATH!
) else (
    echo ERROR: AoE2 installation not found.
)
exit /b

:: ---------------------------------------------------------------------------
:download_about
echo Downloading about.txt...
powershell -command ^
    "Invoke-WebRequest -Uri '%ABOUT_URL%' -OutFile '%DEST_PATH%\about.txt' -UseBasicParsing" ^
    >nul 2>nul

if !errorlevel! neq 0 (
    echo Download failed: about.txt
) else (
    echo Download successful: !DEST_PATH!\about.txt
)
exit /b

:: ---------------------------------------------------------------------------
:delete_all_files
call :find_aoe_path

if exist "!DEST_PATH!" (
    echo Deleting all files in !DEST_PATH!...
    del /q "!DEST_PATH!\*.*"
    echo All files deleted.
) else (
    echo Target folder does not exist.
)
exit /b

