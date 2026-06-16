#!/usr/bin/env bash
#
# Current Alchemy League Map Downloader — Linux / Proton edition
#
# Downloads the current season's custom random map scripts for
# Age of Empires II: Definitive Edition into the game's
# random-map-scripts folder.
#
# Dependencies: bash + curl (or wget). Nothing else.
#
# Linux/Proton note: AoE2:DE runs through Proton, but the maps live in the
# normal Linux filesystem under the Steam library — no Wine prefix involved.
# Original Windows script:
#   https://github.com/f-istvan/Current-Alchemy-League-Map-Downloader

set -u

# --- Configuration -----------------------------------------------------------

# AoE2:DE Steam App ID. Used to locate the install dir.
APP_ID="813780"
# Folder name inside the AoE2:DE install (relative to game root).
GAME_SUBPATH="resources/_common/random-map-scripts"
# Subfolder the maps get installed into.
MAPS_FOLDER="Current_Alchemy_League_Maps"

ALCS_URL="https://raw.githubusercontent.com/Alchemy-AOE-Community/CHEM-Competition-Map-Packs/main/ALCS.md"
ABOUT_URL="https://raw.githubusercontent.com/f-istvan/aoe2-Custom-Map-Downloader/main/about.txt"
# Only lines pointing at this repo are treated as map URLs.
MAP_URL_PREFIX="https://github.com/Alchemy-AOE-Community/CHEM-Random-Map-Scripts/"

# --- Helpers -----------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

# fetch URL OUTPUT_FILE  — download with curl or wget, fail on HTTP error.
fetch() {
    local url="$1" out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$out" "$url"
    else
        die "Neither curl nor wget is installed. Please install one of them."
    fi
}

# --- Auto-discover the AoE2:DE install ---------------------------------------

# Candidate Steam root directories (native, Flatpak, snap, custom symlinks).
steam_roots() {
    cat <<EOF
$HOME/.local/share/Steam
$HOME/.steam/steam
$HOME/.steam/root
$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam
$HOME/snap/steam/common/.local/share/Steam
EOF
}

# Parse every library path out of libraryfolders.vdf for a given Steam root.
library_paths_from_vdf() {
    local steam_root="$1"
    local vdf="$steam_root/steamapps/libraryfolders.vdf"
    [ -f "$vdf" ] || return 0
    # Lines look like:   "path"   "/mnt/games/SteamLibrary"
    grep -oE '"path"[[:space:]]+"[^"]+"' "$vdf" 2>/dev/null \
        | sed -E 's/.*"path"[[:space:]]+"([^"]+)".*/\1/'
}

find_game_root() {
    # 1) Gather every steamapps library we can find.
    local -a libraries=()
    local root path
    while IFS= read -r root; do
        [ -d "$root/steamapps" ] && libraries+=("$root/steamapps")
        while IFS= read -r path; do
            [ -n "$path" ] && [ -d "$path/steamapps" ] && libraries+=("$path/steamapps")
        done < <(library_paths_from_vdf "$root")
    done < <(steam_roots)

    # 2) Look for the AoE2DE install inside each library.
    #    The app manifest tells us the exact install folder name.
    local lib manifest installdir candidate
    for lib in "${libraries[@]}"; do
        manifest="$lib/appmanifest_${APP_ID}.acf"
        if [ -f "$manifest" ]; then
            installdir=$(grep -oE '"installdir"[[:space:]]+"[^"]+"' "$manifest" 2>/dev/null \
                | sed -E 's/.*"installdir"[[:space:]]+"([^"]+)".*/\1/')
            [ -n "$installdir" ] || installdir="AoE2DE"
            candidate="$lib/common/$installdir"
            if [ -d "$candidate/$GAME_SUBPATH" ]; then
                echo "$candidate"
                return 0
            fi
        fi
        # Fallback: probe the conventional folder name even without a manifest.
        candidate="$lib/common/AoE2DE"
        if [ -d "$candidate/$GAME_SUBPATH" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# --- Main --------------------------------------------------------------------

echo "Locating Age of Empires II: Definitive Edition..."

if [ -n "${AOE2_PATH:-}" ]; then
    GAME_ROOT="$AOE2_PATH"
    echo "Using AOE2_PATH override: $GAME_ROOT"
else
    GAME_ROOT="$(find_game_root)" \
        || die "Could not auto-discover AoE2:DE. Set AOE2_PATH to the game root, e.g.:
       AOE2_PATH=\"\$HOME/.local/share/Steam/steamapps/common/AoE2DE\" $0"
fi

SCRIPTS_DIR="$GAME_ROOT/$GAME_SUBPATH"
[ -d "$SCRIPTS_DIR" ] || die "random-map-scripts folder not found at: $SCRIPTS_DIR"

DEST_PATH="$SCRIPTS_DIR/$MAPS_FOLDER"
echo "Game found at:    $GAME_ROOT"
echo "Installing to:    $DEST_PATH"
echo

# Wipe and recreate the maps folder (matches the Windows script behaviour).
rm -rf "$DEST_PATH"
mkdir -p "$DEST_PATH" || die "Cannot create $DEST_PATH (check permissions)."

# Use a temp file for ALCS.md so we don't leave junk in the game folder.
ALCS_FILE="$(mktemp)"
trap 'rm -f "$ALCS_FILE"' EXIT

echo "Downloading map list (ALCS.md)..."
fetch "$ALCS_URL" "$ALCS_FILE" || die "Failed to download ALCS.md"

# --- Parse + download maps ---------------------------------------------------

count=0 ok=0 fail=0

# Pull out the bare github.com URLs (strip surrounding quotes/markdown).
while IFS= read -r input_url; do
    # Trim trailing CR (in case the file has Windows line endings) and quotes.
    input_url="${input_url%$'\r'}"
    input_url="${input_url//\"/}"
    [ -n "$input_url" ] || continue

    count=$((count + 1))

    # filename = last path segment (e.g. "Bear_Valley")
    filename="${input_url##*/}"

    # Transform github.com -> raw.githubusercontent.com, drop "/tree/",
    # then append "<filename>.rms" — identical to the Windows logic.
    raw_url="${input_url/https:\/\/github.com\//https:\/\/raw.githubusercontent.com\/}"
    raw_url="${raw_url//\/tree\//\/}"
    raw_url="$raw_url/$filename.rms"

    map_file="$DEST_PATH/$filename.rms"
    echo "[$count] $filename"
    echo "      -> $raw_url"

    if fetch "$raw_url" "$map_file"; then
        # Guard against GitHub serving a "404: Not Found" body with 200-ish handling.
        if grep -q "404: Not Found" "$map_file" 2>/dev/null; then
            echo "      !! 404 body, removing."
            rm -f "$map_file"
            fail=$((fail + 1))
        else
            ok=$((ok + 1))
        fi
    else
        echo "      !! download failed."
        rm -f "$map_file"
        fail=$((fail + 1))
    fi
done < <(grep -oE "${MAP_URL_PREFIX}[^\"[:space:]]+" "$ALCS_FILE" | sort -u)

# --- about.txt + summary -----------------------------------------------------

echo
echo "Downloading about.txt..."
fetch "$ABOUT_URL" "$DEST_PATH/about.txt" \
    && echo "about.txt installed." \
    || echo "about.txt download failed (non-fatal)."

echo
echo "Done. $ok map(s) installed, $fail failed, out of $count found."
echo "Maps are in: $DEST_PATH"

# Open the folder in the default file manager, if one is available.
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$SCRIPTS_DIR" >/dev/null 2>&1 &
fi
