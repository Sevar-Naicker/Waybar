#!/usr/bin/env bash
# This file contains the installer: it works out which system it's on, installs missing programs (after asking), backs up existing configs,
# symlinks this repo's configs (Waybar, rofi, the dynamic island and shared settings) into ~/.config and creates your shrine.conf
#   ./install.sh            asks before installing anything
#   ./install.sh --yes      installs missing programs without asking
#   ./install.sh --no-install   only lists what's missing and the command to install it

set -euo pipefail

# Section: Paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.config-backup/shrine-waybar-$(date +%Y%m%d-%H%M%S)"

# Section: Options
INSTALL_MODE="ask"

for ARGUMENT in "$@"
do
    case "$ARGUMENT" in
        --yes|-y) INSTALL_MODE="yes" ;;
        --no-install) INSTALL_MODE="no" ;;
        *) echo "Unknown option: $ARGUMENT (use --yes or --no-install)"; exit 1 ;;
    esac
done

# Without a terminal to answer in, nothing gets installed unless --yes was given
if [ "$INSTALL_MODE" = "ask" ] && [ ! -t 0 ]
then
    INSTALL_MODE="no"
fi

# Section: System
# settings.sh works out the system family (atomic, fedora, arch, debian, opensuse or unknown) and the default apps
. "$REPO_DIR/config/shrine-waybar/settings.sh"
SYSTEM_NAME="$(Os_Release_Field PRETTY_NAME)"
SYSTEM_NAME="${SYSTEM_NAME:-$(Os_Release_Field NAME)}"
QUICKSHELL_GUIDE="https://quickshell.org/docs/v0.3.0/guide/install-setup"

# Section: Dependencies (command:package)
# Package names are the common ones; Package_Name adjusts the few that differ between systems
DEPENDENCIES=(
    "waybar:waybar"
    "rofi:rofi"
    "cava:cava"
    "python3:python3"
    "qs:quickshell"
    "wl-paste:wl-clipboard"
    "gdbus:glib2"
)

# Arch-based systems also need checkupdates for the island's updates section
if [ "$SHRINE_SYSTEM" = "arch" ]
then
    DEPENDENCIES+=("checkupdates:pacman-contrib")
fi

# Extras (check:package): everything works without them, but these features need them
#   python-gobject holds notifications back during focus rounds, libnotify sends the focus timer's notifications
EXTRAS=(
    "python-gobject:python-gobject"
    "notify-send:libnotify"
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

# The Package_Name function turns a common package name into this system's name for it
Package_Name()
{
    case "$SHRINE_SYSTEM:$1" in
        arch:python3) echo "python" ;;
        debian:glib2) echo "libglib2.0-bin" ;;
        opensuse:glib2) echo "glib2-tools" ;;
        atomic:python-gobject|fedora:python-gobject|opensuse:python-gobject) echo "python3-gobject" ;;
        debian:python-gobject) echo "python3-gi" ;;
        debian:libnotify) echo "libnotify-bin" ;;
        opensuse:libnotify) echo "libnotify-tools" ;;
        *) echo "$1" ;;
    esac
}

# The Is_Present function checks one dependency (most are a command; PyGObject is a Python module)
Is_Present()
{
    case "$1" in
        python-gobject) python3 -c "import gi" >/dev/null 2>&1 ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# The Ask function asks a yes/no question (Enter means yes), or answers by itself with --yes or --no-install
Ask()
{
    local ANSWER

    case "$INSTALL_MODE" in
        yes) return 0 ;;
        no) return 1 ;;
    esac

    printf '  %s [Y/n] ' "$1"
    read -r ANSWER || return 1
    [[ -z "$ANSWER" || "$ANSWER" =~ ^[Yy] ]]
}

# The Install_Packages function installs packages with this system's package manager (it asks for your password)
Install_Packages()
{
    case "$SHRINE_SYSTEM" in
        fedora) sudo dnf install -y "$@" ;;
        arch) sudo pacman -S --needed --noconfirm "$@" ;;
        debian) sudo apt install -y "$@" ;;
        opensuse) sudo zypper --non-interactive install "$@" ;;
        *) return 1 ;;
    esac
}

# The Install_Font function puts JetBrainsMono Nerd Font in your own fonts folder (no password needed)
Install_Font()
{
    local FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerd"
    local TEMP_ZIP

    if [ "$SHRINE_SYSTEM" = "arch" ]
    then
        sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd && return 0
    fi

    if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1
    then
        Print_Warning "curl and unzip are needed to download the font."
        return 1
    fi

    TEMP_ZIP="$(mktemp --suffix=.zip)"

    if curl -fLo "$TEMP_ZIP" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    then
        mkdir -p "$FONT_DIR"
        unzip -oq "$TEMP_ZIP" -d "$FONT_DIR"
        rm -f "$TEMP_ZIP"
        fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        return 0
    fi

    rm -f "$TEMP_ZIP"
    return 1
}

# The Print_Install_Command function prints how to install packages on this system
Print_Install_Command()
{
    case "$SHRINE_SYSTEM" in
        atomic) echo "      rpm-ostree install $*"; echo "    then restart." ;;
        fedora) echo "      sudo dnf install $*" ;;
        arch) echo "      sudo pacman -S --needed $*" ;;
        debian) echo "      sudo apt install $*" ;;
        opensuse) echo "      sudo zypper install $*" ;;
        *) echo "      (use your system's package manager) $*" ;;
    esac
}

# The Print_Quickshell_Help function explains where Quickshell comes from on this system
Print_Quickshell_Help()
{
    case "$SHRINE_SYSTEM" in
        atomic)
            echo "    Quickshell comes from a COPR. Add it before the command above:"
            echo '      sudo curl -Lo /etc/yum.repos.d/quickshell.repo \'
            echo '        "https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/repo/fedora-$(rpm -E %fedora)/errornointernet-quickshell-fedora-$(rpm -E %fedora).repo"'
            ;;
        fedora)
            echo "    Quickshell comes from a COPR. Enable it before the command above:"
            echo "      sudo dnf copr enable errornointernet/quickshell"
            ;;
        arch)
            ;;
        *)
            echo "    Quickshell isn't in this system's main repositories. Install it by following:"
            echo "      $QUICKSHELL_GUIDE"
            ;;
    esac
}

# The Check_Dependencies function finds missing programs and the font, then offers to install them
# (Bazzite and other atomic systems get the command instead: adding packages there needs a restart, so it's your call)
Check_Dependencies()
{
    local MISSING=()
    local MISSING_EXTRAS=()
    local NEEDS_QUICKSHELL=0
    local NEEDS_FONT=0
    local ENTRY
    local PACKAGE
    local CAN_INSTALL=0

    for ENTRY in "${DEPENDENCIES[@]}"
    do
        Is_Present "${ENTRY%%:*}" && continue

        PACKAGE="$(Package_Name "${ENTRY##*:}")"

        # Quickshell is only in the normal repos on some systems, so it gets its own advice
        if [ "$PACKAGE" = "quickshell" ]
        then
            NEEDS_QUICKSHELL=1
            case "$SHRINE_SYSTEM" in
                atomic|fedora|arch) MISSING+=("$PACKAGE") ;;
            esac
        else
            MISSING+=("$PACKAGE")
        fi
    done

    for ENTRY in "${EXTRAS[@]}"
    do
        Is_Present "${ENTRY%%:*}" || MISSING_EXTRAS+=("$(Package_Name "${ENTRY##*:}")")
    done

    # grep without -q reads the whole list; -q would stop early and, with pipefail, wrongly report the font missing
    if command -v fc-list >/dev/null 2>&1 && ! fc-list : family 2>/dev/null | grep -i "JetBrainsMono Nerd" >/dev/null
    then
        NEEDS_FONT=1
    fi

    if [ ${#MISSING[@]} -eq 0 ] && [ $NEEDS_QUICKSHELL -eq 0 ] && [ ${#MISSING_EXTRAS[@]} -eq 0 ] && [ $NEEDS_FONT -eq 0 ]
    then
        echo "  All programs found."
    else
        [ ${#MISSING[@]} -gt 0 ] && Print_Warning "Missing: ${MISSING[*]}"
        [ $NEEDS_QUICKSHELL -eq 1 ] && [[ " ${MISSING[*]} " != *" quickshell "* ]] && Print_Warning "Missing: quickshell"
        [ ${#MISSING_EXTRAS[@]} -gt 0 ] && echo "  Missing extras (focus timer notifications): ${MISSING_EXTRAS[*]}"
        [ $NEEDS_FONT -eq 1 ] && Print_Warning "Missing: JetBrainsMono Nerd Font (icons show as boxes without it)"

        case "$SHRINE_SYSTEM" in
            fedora|arch) CAN_INSTALL=1 ;;
            debian|opensuse) [ $NEEDS_QUICKSHELL -eq 0 ] && CAN_INSTALL=1 ;;
        esac

        # Programs: installed here after asking, or the command to run yourself
        if [ $((${#MISSING[@]} + ${#MISSING_EXTRAS[@]})) -gt 0 ] || [ $NEEDS_QUICKSHELL -eq 1 ]
        then
            if [ $CAN_INSTALL -eq 1 ] && Ask "Install the missing programs now? (asks for your password)"
            then
                # Fedora gets Quickshell from a COPR, so that's switched on first
                if [ "$SHRINE_SYSTEM" = "fedora" ] && [ $NEEDS_QUICKSHELL -eq 1 ]
                then
                    sudo dnf copr enable -y errornointernet/quickshell || Print_Warning "Couldn't enable the Quickshell COPR."
                fi

                if Install_Packages "${MISSING[@]}" "${MISSING_EXTRAS[@]}"
                then
                    echo "  Programs installed."
                else
                    Print_Warning "Installing didn't finish. Run this yourself:"
                    Print_Install_Command "${MISSING[@]}" "${MISSING_EXTRAS[@]}"
                fi
            else
                echo "    Install them with:"
                Print_Install_Command "${MISSING[@]}" "${MISSING_EXTRAS[@]}"
                [ $NEEDS_QUICKSHELL -eq 1 ] && Print_Quickshell_Help
            fi
        fi

        # The font goes in your own fonts folder, so it works the same on every system
        if [ $NEEDS_FONT -eq 1 ]
        then
            if Ask "Install JetBrainsMono Nerd Font now?"
            then
                if Install_Font
                then
                    echo "  Font installed."
                else
                    Print_Warning "Couldn't install the font. See the README (Install section, 'Rather install the programs yourself?')."
                fi
            else
                echo "    See the README (Install section, 'Rather install the programs yourself?') to install it yourself."
            fi
        fi
    fi

    if [ -z "$SHRINE_TERMINAL" ]
    then
        Print_Warning "No supported terminal found (kitty, konsole, alacritty, foot, wezterm, xterm). The island's Update now button will open Discover instead."
    fi
}

# The Check_Desktop function warns when the session isn't KDE Plasma, which several features rely on
Check_Desktop()
{
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ] && [[ "$XDG_CURRENT_DESKTOP" != *KDE* ]]
    then
        Print_Warning "This is made for KDE Plasma, but you're on $XDG_CURRENT_DESKTOP."
        echo "    The bar and island will run, but night light, the restart prompt and some buttons won't work."
    fi
}

# The Create_Settings function creates shrine.conf from what was detected, then shows the main choices
Create_Settings()
{
    bash "$CONFIG_DIR/shrine-waybar/settings.sh" --write-conf
    echo "  Your choices (change them in $CONFIG_DIR/shrine-waybar/shrine.conf):"
    bash "$CONFIG_DIR/shrine-waybar/settings.sh" --print | while IFS= read -r LINE
    do
        # An empty choice means the button uses its fallback (a web page, or Discover)
        [ -z "${LINE#*=}" ] && LINE="${LINE}(none)"
        echo "    ${LINE#SHRINE_}"
    done
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

    # Music EQ: works through Easy Effects (output presets only; your mic presets are left alone)
    if bash "$REPO_DIR/config/shrine-waybar/run.sh" eq-install
    then
        echo "  Easy Effects found: the music menu's equaliser is ready."
    else
        echo "  Easy Effects isn't installed, so the music menu's equaliser is greyed out."

        if Ask "Install Easy Effects now?"
        then
            # Arch and the other non-atomic systems use their own package; Bazzite and the rest get the Flatpak
            if { [ "$SHRINE_SYSTEM" != "atomic" ] && Install_Packages easyeffects; } ||
               { command -v flatpak >/dev/null 2>&1 && flatpak install -y flathub com.github.wwmm.easyeffects; }
            then
                echo "  Easy Effects installed: the equaliser is ready."
            else
                Print_Warning "Couldn't install Easy Effects. Install it from your app store instead."
            fi
        else
            echo "    Install it (Flatpak: com.github.wwmm.easyeffects) to use the equaliser."
        fi
    fi

    # Wallpaper picker: the folder it shows
    echo "  Wallpapers folder: $(bash "$REPO_DIR/config/shrine-waybar/run.sh" wallpaper-dir) (change SHRINE_WALLPAPER_DIR in shrine.conf)"
}

# The Add_Island_Command function loads the "island" terminal command in every new bash terminal
Add_Island_Command()
{
    local SOURCE_LINE="source $CONFIG_DIR/quickshell/island-command.sh"

    # Matches the line however it was written (~/.config, $HOME/.config or the full path)
    if [ -f "$HOME/.bashrc" ] && grep -q "^[[:space:]]*source .*quickshell/island-command.sh" "$HOME/.bashrc"
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
echo "Ukishima installer"
echo "Repo: $REPO_DIR"
echo "System: ${SYSTEM_NAME:-unknown} (family: $SHRINE_SYSTEM)"

Print_Step "Checking your desktop"
Check_Desktop
echo "  Done."

Print_Step "Checking dependencies"
Check_Dependencies

Print_Step "Making scripts executable"
chmod +x "$REPO_DIR"/config/waybar/*.sh "$REPO_DIR"/config/waybar/*.py "$REPO_DIR"/config/rofi/*.sh \
         "$REPO_DIR"/config/quickshell/*.sh "$REPO_DIR"/config/quickshell/*.py "$REPO_DIR"/config/shrine-waybar/*.sh
echo "  Done."

Print_Step "Linking configs"
Link_Item "$REPO_DIR/config/waybar" "$CONFIG_DIR/waybar"
Link_Item "$REPO_DIR/config/rofi" "$CONFIG_DIR/rofi"
Link_Item "$REPO_DIR/config/autostart/waybar.desktop" "$CONFIG_DIR/autostart/waybar.desktop"
Link_Item "$REPO_DIR/config/quickshell" "$CONFIG_DIR/quickshell"
Link_Item "$REPO_DIR/config/shrine-waybar" "$CONFIG_DIR/shrine-waybar"
Link_Item "$REPO_DIR/config/autostart/dynamic-island.desktop" "$CONFIG_DIR/autostart/dynamic-island.desktop"

Print_Step "Creating your settings"
Create_Settings

# Waybar's colours file: the Shrine colours until you pick a wallpaper
bash "$REPO_DIR/config/shrine-waybar/run.sh" ensure-colours

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
