#!/usr/bin/env bash
# This file contains the shared settings for Shrine Waybar
# It works out which system it's running on, fills in sensible defaults, then applies your own choices from shrine.conf
#   source it from bash      . ~/.config/shrine-waybar/settings.sh
#   read one setting         settings.sh --get SHRINE_TASKS_FILE
#   see every setting        settings.sh --print
#   create your shrine.conf  settings.sh --write-conf

# Section: Paths
ShrineDir="${XDG_CONFIG_HOME:-$HOME/.config}/shrine-waybar"
ShrineConf="$ShrineDir/shrine.conf"

# These two can be pointed elsewhere for testing
OsReleaseFile="${SHRINE_OS_RELEASE:-/etc/os-release}"
OstreeMarker="${SHRINE_OSTREE_MARKER:-/run/ostree-booted}"

# Every setting, in the order shrine.conf lists them
ShrineKeys=(
    SHRINE_SYSTEM SHRINE_UPDATE_COMMAND SHRINE_TERMINAL
    SHRINE_STORE_APP SHRINE_BROWSER_APP SHRINE_MUSIC_APP SHRINE_MUSIC_URL
    SHRINE_TASKS_FILE SHRINE_NEXTCLOUD_DIR SHRINE_DOWNLOADS_DIR SHRINE_SCREENSHOTS_DIR
    SHRINE_WEATHER_LOCATION SHRINE_WALLPAPER_DIR
)

# The Os_Release_Field function reads one field (like ID or ID_LIKE) from os-release
Os_Release_Field()
{
    [ -r "$OsReleaseFile" ] || return
    ( . "$OsReleaseFile" 2>/dev/null; eval "printf '%s' \"\${$1:-}\"" )
}

# The Detect_System function sorts the system into a family: atomic, fedora, arch, debian, opensuse or unknown
Detect_System()
{
    local Ids

    if [ -e "$OstreeMarker" ] && command -v rpm-ostree >/dev/null 2>&1
    then
        echo "atomic"
        return
    fi

    Ids=" $(Os_Release_Field ID) $(Os_Release_Field ID_LIKE) "

    case "$Ids" in
        *" fedora "*|*" rhel "*|*" centos "*) echo "fedora" ;;
        *" arch "*) echo "arch" ;;
        *" debian "*|*" ubuntu "*) echo "debian" ;;
        *suse*) echo "opensuse" ;;
        *) echo "unknown" ;;
    esac
}

# The Has function says whether a command is installed
Has()
{
    command -v "$1" >/dev/null 2>&1
}

# The Find_Desktop_File function finds where an app's .desktop file lives, if the app is installed
Find_Desktop_File()
{
    local Id="${1%.desktop}"
    local Dir

    for Dir in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
               "$HOME/.local/share/flatpak/exports/share/applications" \
               /var/lib/flatpak/exports/share/applications \
               /usr/local/share/applications \
               /usr/share/applications
    do
        if [ -f "$Dir/$Id.desktop" ]
        then
            echo "$Dir/$Id.desktop"
            return 0
        fi
    done

    return 1
}

# The First_Installed_App function returns the first app in the list that's installed
First_Installed_App()
{
    local Id

    for Id in "$@"
    do
        if Find_Desktop_File "$Id" >/dev/null
        then
            echo "$Id"
            return
        fi
    done
}

# The Default_Update_Command function picks the right update command for this system
Default_Update_Command()
{
    local Command=""
    local FlatpakPart=""

    Has flatpak && FlatpakPart=" && flatpak update -y"

    case "$SHRINE_SYSTEM" in
        atomic)
            if Has ujust
            then
                # ujust update already covers Flatpaks
                Command="ujust update"
            else
                Command="sudo rpm-ostree upgrade$FlatpakPart"
            fi
            ;;
        fedora)
            Command="sudo dnf upgrade --refresh$FlatpakPart"
            ;;
        arch)
            if Has paru
            then
                Command="paru -Syu$FlatpakPart"
            elif Has yay
            then
                Command="yay -Syu$FlatpakPart"
            else
                Command="sudo pacman -Syu$FlatpakPart"
            fi
            ;;
        debian)
            Command="sudo apt update && sudo apt full-upgrade$FlatpakPart"
            ;;
        opensuse)
            # Tumbleweed upgrades with dup, Leap with up
            if [ "$(Os_Release_Field ID)" = "opensuse-tumbleweed" ]
            then
                Command="sudo zypper dup$FlatpakPart"
            else
                Command="sudo zypper up$FlatpakPart"
            fi
            ;;
    esac

    echo "$Command"
}

# The Default_Terminal function picks the first terminal that's installed
Default_Terminal()
{
    local Terminal

    for Terminal in kitty konsole alacritty foot wezterm xterm
    do
        if Has "$Terminal"
        then
            echo "$Terminal"
            return
        fi
    done
}

# The Default_Browser_App function prefers Brave, then whatever the system's default browser is
Default_Browser_App()
{
    local App

    App=$(First_Installed_App com.brave.Browser brave-browser brave)

    if [ -z "$App" ] && Has xdg-settings
    then
        App=$(xdg-settings get default-web-browser 2>/dev/null)
        App="${App%.desktop}"
    fi

    echo "$App"
}

# The User_Dir function asks for a standard folder (like DOWNLOAD or PICTURES), with a fallback
User_Dir()
{
    local Dir=""

    Has xdg-user-dir && Dir=$(xdg-user-dir "$1" 2>/dev/null)

    # xdg-user-dir answers with the home folder itself when the folder isn't set up
    if [ -z "$Dir" ] || [ "$Dir" = "$HOME" ]
    then
        Dir="$HOME/$2"
    fi

    echo "$Dir"
}

# The Default_Screenshots_Dir function uses Spectacle's save folder if it has one, otherwise Pictures/Screenshots
Default_Screenshots_Dir()
{
    local SpectacleConf="${XDG_CONFIG_HOME:-$HOME/.config}/spectaclerc"
    local Saved=""

    if [ -r "$SpectacleConf" ]
    then
        Saved=$(grep -m 1 -E '^(imageSaveLocation|defaultSaveLocation)=' "$SpectacleConf" | cut -d= -f2-)
        Saved="${Saved#file://}"
    fi

    if [ -n "$Saved" ]
    then
        echo "${Saved%/}"
    else
        echo "$(User_Dir PICTURES Pictures)/Screenshots"
    fi
}

# Section: Your choices
# shrine.conf is read first, so anything it sets wins; only what it leaves out gets a default below
if [ -r "$ShrineConf" ]
then
    . "$ShrineConf"
fi

# Section: Defaults
# "${NAME=value}" only fills in a setting that shrine.conf didn't set (an empty value in shrine.conf is kept)
: "${SHRINE_SYSTEM=$(Detect_System)}"
: "${SHRINE_UPDATE_COMMAND=$(Default_Update_Command)}"
: "${SHRINE_TERMINAL=$(Default_Terminal)}"
: "${SHRINE_STORE_APP=$(First_Installed_App io.github.kolunmi.Bazaar org.kde.discover org.manjaro.pamac.manager octopi)}"
: "${SHRINE_BROWSER_APP=$(Default_Browser_App)}"
: "${SHRINE_MUSIC_APP=$(First_Installed_App app.ytmdesktop.ytmdesktop ytmdesktop youtube-music com.spotify.Client spotify)}"
: "${SHRINE_MUSIC_URL=https://music.youtube.com}"
: "${SHRINE_NEXTCLOUD_DIR=$HOME/Nextcloud}"
: "${SHRINE_DOWNLOADS_DIR=$(User_Dir DOWNLOAD Downloads)}"
: "${SHRINE_SCREENSHOTS_DIR=$(Default_Screenshots_Dir)}"
: "${SHRINE_WEATHER_LOCATION=}"
: "${SHRINE_WALLPAPER_DIR=$(User_Dir PICTURES Pictures)/Wallpapers}"

if [ -z "${SHRINE_TASKS_FILE+set}" ]
then
    if [ -d "$SHRINE_NEXTCLOUD_DIR" ]
    then
        SHRINE_TASKS_FILE="$SHRINE_NEXTCLOUD_DIR/Tasks.txt"
    else
        SHRINE_TASKS_FILE="$HOME/Tasks.txt"
    fi
fi

# The Write_Conf function saves the current settings as a commented shrine.conf, without replacing an existing one
Write_Conf()
{
    if [ -e "$ShrineConf" ]
    then
        echo "  $ShrineConf already exists, leaving it as it is."
        return
    fi

    mkdir -p "$ShrineDir"

    # Home-folder paths are written with $HOME so the file still works if your username changes
    Q()
    {
        local Value="${1//\\/\\\\}"
        Value="${Value//\"/\\\"}"
        Value="${Value//\$/\\\$}"
        case "$Value" in
            "$HOME"/*) Value="\$HOME${Value#"$HOME"}" ;;
        esac
        printf '"%s"' "$Value"
    }

    cat > "$ShrineConf" <<EOF
# This file contains your own Shrine Waybar choices
# It was filled in for your system by the installer. Change anything you like, then reload Waybar.
# Delete a line to go back to the automatic choice. See the README's "Settings" section for details.

# Section: System
# Family the updates section uses: atomic, fedora, arch, debian, opensuse or unknown
SHRINE_SYSTEM=$(Q "$SHRINE_SYSTEM")
# What the island's "Update now" button runs (leave empty to open Discover instead)
SHRINE_UPDATE_COMMAND=$(Q "$SHRINE_UPDATE_COMMAND")
# Terminal for "Update now": kitty, konsole, alacritty, foot, wezterm or xterm
SHRINE_TERMINAL=$(Q "$SHRINE_TERMINAL")

# Section: Apps
# App IDs are .desktop file names without ".desktop" (e.g. org.kde.discover, com.brave.Browser)
# Torii pill: your app store
SHRINE_STORE_APP=$(Q "$SHRINE_STORE_APP")
# Globe pill: your browser
SHRINE_BROWSER_APP=$(Q "$SHRINE_BROWSER_APP")
# Music pill: your music app; leave empty to open the link below in your browser
SHRINE_MUSIC_APP=$(Q "$SHRINE_MUSIC_APP")
SHRINE_MUSIC_URL=$(Q "$SHRINE_MUSIC_URL")

# Section: Folders
# Today's task pill reads this list (keep it in a synced folder to edit it from your phone)
SHRINE_TASKS_FILE=$(Q "$SHRINE_TASKS_FILE")
# Opened by the island's sync card
SHRINE_NEXTCLOUD_DIR=$(Q "$SHRINE_NEXTCLOUD_DIR")
# Watched by the island's downloads section and pop-ups
SHRINE_DOWNLOADS_DIR=$(Q "$SHRINE_DOWNLOADS_DIR")
SHRINE_SCREENSHOTS_DIR=$(Q "$SHRINE_SCREENSHOTS_DIR")

# Section: Weather
# Town or city for the island's weather (e.g. "Johannesburg"); leave empty to use your connection's location
SHRINE_WEATHER_LOCATION=$(Q "$SHRINE_WEATHER_LOCATION")

# Section: Wallpapers
# Folder the wallpaper picker shows (jpg, png and webp)
SHRINE_WALLPAPER_DIR=$(Q "$SHRINE_WALLPAPER_DIR")
EOF

    echo "  Created $ShrineConf"
}

# Section: Command line
# Only runs when this file is run directly, not when it's sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]
then
    case "${1:-}" in
        --get)
            Key="${2:-}"
            if [[ " ${ShrineKeys[*]} " == *" $Key "* ]]
            then
                printf '%s\n' "${!Key}"
            else
                echo "Unknown setting: $Key" >&2
                exit 1
            fi
            ;;
        --print)
            for Key in "${ShrineKeys[@]}"
            do
                printf '%s=%s\n' "$Key" "${!Key}"
            done
            ;;
        --write-conf)
            Write_Conf
            ;;
        *)
            echo "Usage: settings.sh --get KEY | --print | --write-conf" >&2
            exit 1
            ;;
    esac
fi
