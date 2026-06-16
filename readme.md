# AoE2 Custom Map Downloader

This script automates the download and installation of the custom maps for Alchemy League Current Season for Age of Empires II: Definitive Edition.

Two versions are provided:
- **Windows:** `current_season_maps_downloader.bat`
- **Linux (Steam Play / Proton):** `current_season_maps_downloader.sh`

## Features
- Automatically detects the AoE2 installation folder.
  - Windows: Steam or Microsoft Store version.
  - Linux: Steam (native, Flatpak, and Snap), including libraries on other drives.
- Downloads the Alchemy League Current Season maps to the AoE2 installation folder.
- Opens the maps folder for easy access.
- Cleans up temporary files after execution.

---

## Windows

### Installation
1. Download `current_season_maps_downloader.bat` from the repository.
2. Place it in any folder of your choice.

### Usage
1. Run the script (`.bat` file) by double-clicking it.

---

## Linux (Proton)

### Requirements
- `bash` and `curl` (or `wget`). Both are present on virtually every distribution, so
  there is nothing extra to install.

### Installation
1. Download `current_season_maps_downloader.sh` from the repository.
2. Place it in any folder of your choice.

### Usage
Run it from a terminal:
```bash
./current_season_maps_downloader.sh
```
