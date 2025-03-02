@echo off
setlocal enabledelayedexpansion

:: Define download URL and target folder
set "ZIP_URL=https://github.com/Alchemy-AOE-Community/CHEM-Random-Map-Scripts/raw/refs/heads/Space_Maps/Space_Maps/ALS5_Maps.zip"
set "ZIP_FILE=%TEMP%\ALS5_Maps.zip"
set "TARGET_FOLDER=resources\_common\random-map-scripts\Current_Alchemy_League_Maps"
set "GITHUB_URL=https://raw.githubusercontent.com/Alchemy-AOE-Community/CHEM-Competition-Map-Packs/main/ALCS.md"

call :findAoEPath
call :open_maps_folder
call :download
call :download_about
call :delete_temp_files
exit

:download
call :findAoEPath
echo Downloading and installing latest maps to: !DEST_PATH!

:: Create target directory
if not exist "%DEST_PATH%" mkdir "%DEST_PATH%"

:: Download ALCS.md
echo Downloading ALCS.md...
curl -L "%GITHUB_URL%" -o "%MD_FILE_PATH%"

:: Delete previous lists if they exist
if exist "%DOWNLOAD_LIST_PATH%" del "%DOWNLOAD_LIST_PATH%"

for /f "delims=" %%A in ('type "%MD_FILE_PATH%" ^| findstr "https://github.com/Alchemy-AOE-Community/CHEM-Random-Map-Scripts/"') do (
    set "input_url=%%A"
    
    echo Found URL: !input_url!

    :: Convert to raw GitHub URL format
    set "output_url=!input_url:https://github.com/=https://raw.githubusercontent.com/!"
    set "output_url=!output_url:/tree/=/!"

    :: Extract last folder name (map name)
    for %%I in (!input_url!) do set "filename=%%~nxI"

    :: Ensure filename is properly extracted
    echo Extracted filename: !filename!

    :: Append filename again with .rms extension
    set "output_url=!output_url!/!filename!.rms"
    
    echo Converted URL: !output_url!
    
    :: Write transformed URL to DOWNLOAD_LIST_PATH
    echo !output_url! >> "%DOWNLOAD_LIST_PATH%"
)

echo Process completed! URLs saved to %DOWNLOAD_LIST_PATH%.

for /f "usebackq delims=" %%L in ("%DOWNLOAD_LIST_PATH%") do (
    set "map_url=%%L"

    :: Extract filename from URL (last segment before .rms)
    for %%F in (!map_url!) do (
        set "filename=%%~nxF"
        set "map_file=!DEST_PATH!\!filename!"
    )

    echo Downloading !map_url! to !map_file!... 
    curl -L !map_url! --output "!map_file!"

    :: Check if download was successful
    if !errorlevel! neq 0 (
        echo Download failed: !map_url!
    ) else (
        findstr /C:"404: Not Found" "!map_file!" >nul 2>&1 && (
            echo File contains 404 error, deleting !map_file!...
            del "!map_file!"
        )
        echo Download successful: !map_file!
    )
)
exit /b

:open_maps_folder
call :findAoEPath

:: Create target directory
if not exist "%DEST_PATH%" mkdir "%DEST_PATH%"

set "PARENT_PATH=!DEST_PATH!\.."

echo Opening maps folder: !PARENT_PATH!
explorer "!PARENT_PATH!"
exit /b

:findAoEPath
:: Check Steam installation
set "REG_PATH_STEAM=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 813780"
for /f "tokens=2*" %%A in ('reg query "%REG_PATH_STEAM%" /v InstallLocation 2^>nul') do set "AOE2_PATH=%%B"

:: Check Microsoft Store installation using PowerShell if Steam version not found
if not defined AOE2_PATH (
    for /f "tokens=*" %%I in ('powershell -command "Get-AppxPackage -Name \"Microsoft.MSPhoenix\" | Select-Object -ExpandProperty InstallLocation"') do set "AOE2_PATH=%%I"
)

:: If AoE2 installation is found
if defined AOE2_PATH (
    echo AoE2 installation found at: !AOE2_PATH!
    set "DEST_PATH=!AOE2_PATH!\%TARGET_FOLDER%"
    set "MD_FILE_PATH=!DEST_PATH!\ALCS.md"
    set "DOWNLOAD_LIST_PATH=%DEST_PATH%\download_links.txt"
    echo Target directory: !DEST_PATH!
) else (
    echo AoE2 installation not found.
)
exit /b

:delete_temp_files
if exist "%DOWNLOAD_LIST_PATH%" del "%DOWNLOAD_LIST_PATH%"
if exist "%MD_FILE_PATH%" del "%MD_FILE_PATH%"
exit /b

:download_about
echo Downloading about.txt...
curl -L "https://raw.githubusercontent.com/f-istvan/aoe2-Custom-Map-Downloader/main/about.txt" -o "!DEST_PATH!\about.txt"

if !errorlevel! neq 0 (
    echo Download failed: about.txt
) else (
    echo Download successful: !DEST_PATH!\about.txt
)
exit /b