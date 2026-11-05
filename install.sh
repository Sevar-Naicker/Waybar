#!/usr/bin/env bash
# This file contains the installer: it checks dependencies, backs up existing configs and symlinks this repo's configs into ~/.config

set -euo pipefail

# Section: Paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.config-backup/shrine-waybar-$(date +%Y%m%d-%H%M%S)"

# Section: Dependencies (command:package)
DEPENDENCIES=(
    "waybar:waybar"
    "rofi:rofi"
    "cava:cava"
    "playerctl:playerctl"
    "kitty:kitty"
    "btop:btop"
    "pavucontrol:pavucontrol"
    "python3:python3"
)

# The Print_Step function prints a coloured heading for each install step
Print_Step()
{
    printf '\n\033[1;33m==> %s\033[0m\n' "$1"
}

# The Print_Warning function prints a highlighted warning line
Print_Warning()
{
    printf '\033[1;31m  ! %s\033[0m\n' "$1"
}

# The Check_Dependencies function lists missing programs and fonts, and the command to install them
Check_Dependencies()
{
    local MISSING=()
    local ENTRY

    for ENTRY in "${DEPENDENCIES[@]}"
    do
        if ! command -v "${ENTRY%%:*}" >/dev/null 2>&1
        then
            MISSING+=("${ENTRY##*:}")
        fi
    done

    if [ ${#MISSING[@]} -eq 0 ]
    then
        echo "  All programs found."
    else
        Print_Warning "Missing: ${MISSING[*]}"
        echo "    On Bazzite / Fedora Atomic, install them with:"
        echo "      rpm-ostree install ${MISSING[*]}"
        echo "    then reboot. On regular Fedora: sudo dnf install ${MISSING[*]}"
    fi

    if command -v fc-list >/dev/null 2>&1 && ! fc-list | grep -qi "JetBrainsMono Nerd"
    then
        Print_Warning "JetBrainsMono Nerd Font not found. Icons will show as boxes until it's installed (see README)."
    fi
}

# The Link_Item function backs up whatever is at a target path, then replaces it with a symlink into the repo
Link_Item()
{
    local SOURCE="$1"
    local TARGET="$2"

    if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$(readlink -f "$SOURCE")" ]
    then
        echo "  Already linked: $TARGET"
        return
    fi

    if [ -e "$TARGET" ] || [ -L "$TARGET" ]
    then
        mkdir -p "$BACKUP_DIR"
        mv "$TARGET" "$BACKUP_DIR/"
        echo "  Backed up: $TARGET -> $BACKUP_DIR/$(basename "$TARGET")"
    fi

    mkdir -p "$(dirname "$TARGET")"
    ln -s "$SOURCE" "$TARGET"
    echo "  Linked: $TARGET -> $SOURCE"
}

# The Check_Extras function warns about a missing header image or a second Waybar autostart entry
Check_Extras()
{
    local FILE

    if [ ! -f "$REPO_DIR/config/rofi/shrine_header.png" ]
    then
        Print_Warning "config/rofi/shrine_header.png is missing. The rofi menus will open without their header image."
    fi

    for FILE in "$CONFIG_DIR"/autostart/*
    do
        [ -e "$FILE" ] || continue
        [ "$(basename "$FILE")" = "waybar.desktop" ] && continue
        if grep -qi "waybar" "$FILE"
        then
            Print_Warning "$FILE also starts Waybar. Remove it or you'll get two bars."
        fi
    done
}

# The Restart_Waybar function reloads the bar so the new config shows straight away
Restart_Waybar()
{
    if ! command -v waybar >/dev/null 2>&1 || [ -z "${WAYLAND_DISPLAY:-}" ]
    then
        echo "  Skipped (Waybar not installed or not in a Wayland session). It will start on next login."
        return
    fi

    pkill -x waybar 2>/dev/null || true
    sleep 0.5
    setsid -f waybar >/dev/null 2>&1
    echo "  Waybar restarted."
}

# Section: Run
echo "Shrine Waybar installer"
echo "Repo: $REPO_DIR"

Print_Step "Checking dependencies"
Check_Dependencies

Print_Step "Making scripts executable"
chmod +x "$REPO_DIR"/config/waybar/*.sh "$REPO_DIR"/config/waybar/*.py "$REPO_DIR"/config/rofi/*.sh
echo "  Done."

Print_Step "Linking configs"
Link_Item "$REPO_DIR/config/waybar" "$CONFIG_DIR/waybar"
Link_Item "$REPO_DIR/config/rofi" "$CONFIG_DIR/rofi"
Link_Item "$REPO_DIR/config/autostart/waybar.desktop" "$CONFIG_DIR/autostart/waybar.desktop"

Print_Step "Checking extras"
Check_Extras

Print_Step "Restarting Waybar"
Restart_Waybar

printf '\n\033[1;32mInstalled.\033[0m'
if [ -d "$BACKUP_DIR" ]
then
    printf ' Your old configs are in %s' "$BACKUP_DIR"
fi
printf '\nKeep this folder where it is: the configs in ~/.config now point here.\n'
