#!/usr/bin/env bash
# This file contains the launcher every Shrine Waybar button goes through
# It reads settings.sh, so the same buttons open the right app or command on any system
#   run.sh store | browser | music | music-pill | update | system-monitor
#   run.sh open-folder <path> | show-file <path> | save-image <path> | downloads-folder | nextcloud-folder

# Section: Settings
ShrineHere="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ShrineHere/settings.sh"

# Section: Icons
IconYouTube=$' '
IconSpotify=$' '
IconMusic=$' '

# The Launch_App function starts an app from its .desktop ID, detached so reloading Waybar can't close it
Launch_App()
{
    local Id="${1%.desktop}"
    local File

    [ -n "$Id" ] || return 1
    File=$(Find_Desktop_File "$Id") || return 1

    if Has gtk-launch
    then
        setsid -f gtk-launch "$Id" >/dev/null 2>&1
    elif Has kstart
    then
        setsid -f kstart --application "$File" >/dev/null 2>&1
    elif Has kioclient
    then
        setsid -f kioclient exec "$File" >/dev/null 2>&1
    elif Has dex
    then
        setsid -f dex "$File" >/dev/null 2>&1
    else
        return 1
    fi
}

# The Open_Path function opens a file, folder or link with its default app, detached
Open_Path()
{
    setsid -f xdg-open "$1" >/dev/null 2>&1
}

# The Open_Folder function opens a folder in Dolphin, or the default file manager
Open_Folder()
{
    mkdir -p "$1" 2>/dev/null

    if Has dolphin
    then
        setsid -f dolphin "$1" >/dev/null 2>&1
    else
        Open_Path "$1"
    fi
}

# The Show_File function opens the file's folder with the file highlighted where the file manager allows it
Show_File()
{
    if Has dolphin
    then
        setsid -f dolphin --select "$1" >/dev/null 2>&1
    else
        Open_Path "$(dirname "$1")"
    fi
}

# The Run_In_Terminal function opens the chosen terminal running a command
Run_In_Terminal()
{
    local Title="$1"
    shift

    case "$SHRINE_TERMINAL" in
        kitty) setsid -f kitty --title "$Title" "$@" >/dev/null 2>&1 ;;
        konsole) setsid -f konsole -p tabtitle="$Title" -e "$@" >/dev/null 2>&1 ;;
        alacritty) setsid -f alacritty --title "$Title" -e "$@" >/dev/null 2>&1 ;;
        foot) setsid -f foot --title "$Title" "$@" >/dev/null 2>&1 ;;
        wezterm) setsid -f wezterm start -- "$@" >/dev/null 2>&1 ;;
        xterm) setsid -f xterm -T "$Title" -e "$@" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# The Open_Discover_Updates function falls back to KDE Discover's update page
Open_Discover_Updates()
{
    if Has plasma-discover
    then
        setsid -f plasma-discover --mode update >/dev/null 2>&1
    else
        Launch_App org.kde.discover
    fi
}

# The Update function runs the system's update in a terminal, or opens Discover if there's no command or terminal
Update()
{
    if [ -z "$SHRINE_UPDATE_COMMAND" ] || ! Run_In_Terminal "System update" bash "$ShrineHere/run.sh" update-run
    then
        Open_Discover_Updates
    fi
}

# The Update_Run function is what the update terminal runs: the update, then a ping to the island
Update_Run()
{
    local Start=$SECONDS
    local Code

    printf '\033[1;33m==> %s\033[0m\n\n' "$SHRINE_UPDATE_COMMAND"
    bash -c "$SHRINE_UPDATE_COMMAND"
    Code=$?

    if Has qs
    then
        qs ipc call island commandDone "System update" "$Code" "$(( SECONDS - Start ))" >/dev/null 2>&1
    fi

    echo
    read -rp "Press Enter to close…"
}

# The Music_Pill function prints the music pill: an icon and name to match the chosen app
Music_Pill()
{
    local Id="$SHRINE_MUSIC_APP"
    local File
    local Name=""
    local Icon="$IconMusic"

    case "${Id,,}" in
        *ytm*|*youtube*) Icon="$IconYouTube"; Name="YouTube Music" ;;
        *spotify*) Icon="$IconSpotify"; Name="Spotify" ;;
    esac

    if [ -z "$Name" ] && File=$(Find_Desktop_File "$Id")
    then
        Name=$(grep -m 1 '^Name=' "$File" | cut -d= -f2-)
    fi

    # No app chosen means the link opens in the browser
    if [ -z "$Id" ]
    then
        case "$SHRINE_MUSIC_URL" in
            *youtube*) Icon="$IconYouTube"; Name="YouTube Music (web)" ;;
            *) Name="Music (web)" ;;
        esac
    fi

    Name="${Name//\\/}"
    Name="${Name//\"/}"
    printf '{"text": "%s", "tooltip": "%s"}\n' "$Icon" "${Name:-Music}"
}

# The System_Monitor function opens KDE's System Monitor, or a terminal monitor if it's missing
System_Monitor()
{
    if Has plasma-systemmonitor
    then
        setsid -f plasma-systemmonitor >/dev/null 2>&1
    elif Has btop
    then
        Run_In_Terminal "System monitor" btop
    else
        Run_In_Terminal "System monitor" top
    fi
}

# Section: Actions
case "${1:-}" in
    store) Launch_App "$SHRINE_STORE_APP" || Launch_App org.kde.discover || { Has plasma-discover && setsid -f plasma-discover >/dev/null 2>&1; } ;;
    # With no browser found, opening any web page starts whatever the system uses
    browser) Launch_App "$SHRINE_BROWSER_APP" || Open_Path "https://duckduckgo.com" ;;
    music) Launch_App "$SHRINE_MUSIC_APP" || Open_Path "$SHRINE_MUSIC_URL" ;;
    music-pill) Music_Pill ;;
    update) Update ;;
    update-run) Update_Run ;;
    system-monitor) System_Monitor ;;
    open-folder) Open_Folder "$2" ;;
    show-file) Show_File "$2" ;;
    downloads-folder) Open_Folder "$SHRINE_DOWNLOADS_DIR" ;;
    nextcloud-folder) Open_Folder "$SHRINE_NEXTCLOUD_DIR" ;;
    save-image)
        mkdir -p "$SHRINE_SCREENSHOTS_DIR" && cp "$2" "$SHRINE_SCREENSHOTS_DIR/"
        ;;
    *)
        echo "Usage: run.sh store | browser | music | music-pill | update | system-monitor | open-folder <path> | show-file <path> | save-image <path> | downloads-folder | nextcloud-folder" >&2
        exit 1
        ;;
esac
