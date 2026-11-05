#!/usr/bin/env bash
# This file contains the installer: it checks dependencies, backs up existing configs and symlinks this repo's configs (Waybar, rofi and the dynamic island) into ~/.config

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
    "python3:python3"
    "qs:quickshell"
    "wl-paste:wl-clipboard"
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

        if [[ " ${MISSING[*]} " == *" quickshell "* ]]
        then
            echo "    Quickshell isn't in the normal Fedora repos. Add its COPR first (see README, step 1):"
            echo '      sudo curl -Lo /etc/yum.repos.d/quickshell.repo \'
            echo '        "https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/repo/fedora-$(rpm -E %fedora)/errornointernet-quickshell-fedora-$(rpm -E %fedora).repo"'
        fi
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
        if grep -qiE "^Exec=.*waybar" "$FILE"
        then
            Print_Warning "$FILE also starts Waybar. Remove it or you'll get two bars."
        fi
    done
}

# The Add_Island_Command function loads the "island" terminal command in every new bash terminal
Add_Island_Command()
{
    local SOURCE_LINE="source $CONFIG_DIR/quickshell/island-command.sh"

    if [ -f "$HOME/.bashrc" ] && grep -qF "$SOURCE_LINE" "$HOME/.bashrc"
    then
        echo "  Already in ~/.bashrc."
        return
    fi

    printf '\n# Shrine Waybar: "island <command>" pings the dynamic island when a command finishes\n%s\n' "$SOURCE_LINE" >> "$HOME/.bashrc"
    echo "  Added to ~/.bashrc. Open a new terminal to use it."
}

# The Restart_Island function restarts the dynamic island so the new config shows straight away
Restart_Island()
{
    if ! command -v qs >/dev/null 2>&1 || [ -z "${WAYLAND_DISPLAY:-}" ]
    then
        echo "  Skipped (Quickshell not installed or not in a Wayland session). It will start on next login."
        return
    fi

    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
    sleep 0.5
    setsid -f qs >/dev/null 2>&1
    echo "  Dynamic island restarted."
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
chmod +x "$REPO_DIR"/config/waybar/*.sh "$REPO_DIR"/config/waybar/*.py "$REPO_DIR"/config/rofi/*.sh \
         "$REPO_DIR"/config/quickshell/*.sh "$REPO_DIR"/config/quickshell/*.py
echo "  Done."

Print_Step "Linking configs"
Link_Item "$REPO_DIR/config/waybar" "$CONFIG_DIR/waybar"
Link_Item "$REPO_DIR/config/rofi" "$CONFIG_DIR/rofi"
Link_Item "$REPO_DIR/config/autostart/waybar.desktop" "$CONFIG_DIR/autostart/waybar.desktop"
Link_Item "$REPO_DIR/config/quickshell" "$CONFIG_DIR/quickshell"
Link_Item "$REPO_DIR/config/autostart/dynamic-island.desktop" "$CONFIG_DIR/autostart/dynamic-island.desktop"

Print_Step "Adding the island terminal command"
Add_Island_Command

Print_Step "Checking extras"
Check_Extras

Print_Step "Restarting Waybar"
Restart_Waybar

# Waybar first, so the island comes up after it
Print_Step "Restarting the dynamic island"
Restart_Island

printf '\n\033[1;32mInstalled.\033[0m'
if [ -d "$BACKUP_DIR" ]
then
    printf ' Your old configs are in %s' "$BACKUP_DIR"
fi
printf '\nKeep this folder where it is: the configs in ~/.config now point here.\n'
