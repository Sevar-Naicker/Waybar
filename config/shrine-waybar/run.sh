#!/usr/bin/env bash
# This file contains the launcher every Shrine Waybar button goes through
# It reads settings.sh, so the same buttons open the right app or command on any system
#   run.sh store | browser | music | music-pill | keepawake-pill | update | system-monitor | in-terminal <command...>
#   run.sh open-folder <path> | show-file <path> | save-image <path> | downloads-folder | nextcloud-folder
#   run.sh ensure-colours | apply-theme <json> <css> | set-wallpaper <path> | set-login-wallpaper <path> | wallpaper-dir | wallpaper-list
#   run.sh eq-status | eq-apply <preset> <10 gains> | eq-install

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

# The Keep_Awake_Pill function prints the coffee pill from the state the island saves (on or off)
Keep_Awake_Pill()
{
    local State
    local Icon=$'\uf0f4 '

    State=$(cat "$HOME/.local/state/shrine-waybar/keepawake" 2>/dev/null)

    if [ "$State" = "on" ]
    then
        printf '{"text": "%s", "tooltip": "Keeping awake\\nClick to allow sleep", "class": "on"}\n' "$Icon"
    else
        printf '{"text": "%s", "tooltip": "Sleep allowed\\nClick to keep awake", "class": "off"}\n' "$Icon"
    fi
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

# Section: Theme
StateDir="${XDG_STATE_HOME:-$HOME/.local/state}/shrine-waybar"
WaybarDir="$ShrineHere/../waybar"

# The Ensure_Colours function gives Waybar its colours file (the Shrine colours) if it doesn't have one yet
Ensure_Colours()
{
    if [ ! -f "$WaybarDir/colours.css" ] && [ -f "$WaybarDir/colours.default.css" ]
    then
        cp "$WaybarDir/colours.default.css" "$WaybarDir/colours.css"
    fi
}

# The Apply_Theme function saves the island's colours, writes Waybar's, and makes Waybar reload its style
Apply_Theme()
{
    mkdir -p "$StateDir"
    printf '%s\n' "$1" > "$StateDir/theme.json"

    if [ -n "$2" ]
    then
        printf '%s' "$2" > "$WaybarDir/colours.css"

        # Waybar can't fade, so it switches about when the picker's wipe crosses the middle of the screen
        ( sleep 0.6; pkill -USR2 -x waybar ) >/dev/null 2>&1 &
    fi
}

# The Set_Wallpaper function puts an image on every screen's desktop
# KDE's plasma-apply-wallpaperimage quietly fails on names with an apostrophe (like "Hell's Paradise.jpeg"),
# so an image with anything but plain characters in its name is handed over as a copy with a plain name
Set_Wallpaper()
{
    local Image="$1"
    local Extension
    local SafeDir="$StateDir/wallpapers"
    local Safe

    [ -f "$Image" ] || return 1
    Image=$(realpath "$Image")

    if [[ "$Image" =~ [^A-Za-z0-9\ ._/()-] ]]
    then
        Extension="${Image##*.}"
        Safe="$SafeDir/wallpaper-$(printf '%s' "$Image" | md5sum | cut -c1-12).${Extension,,}"
        mkdir -p "$SafeDir"
        cp -f "$Image" "$Safe" || return 1

        # Keep only the newest few copies
        find "$SafeDir" -maxdepth 1 -type f -name 'wallpaper-*' -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n +4 | cut -d' ' -f2- | xargs -r -d '\n' rm -f
        Image="$Safe"
    fi

    [ "$SHRINE_LOCK_WALLPAPER" = 1 ] && Set_Lock_Wallpaper "$Image"

    if Has plasma-apply-wallpaperimage
    then
        plasma-apply-wallpaperimage "$Image" >/dev/null 2>&1 && return 0
    fi

    # Older Plasma without that command: ask the desktop directly (the name is plain by now, so no escaping needed)
    gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.evaluateScript \
        "for (const Desk of desktops()) { Desk.wallpaperPlugin = 'org.kde.image'; Desk.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; Desk.writeConfig('Image', 'file://$Image'); }" >/dev/null 2>&1
}

# The Set_Login_Wallpaper function puts a picture on the login screen; that's a system setting, so it asks for your password
Set_Login_Wallpaper()
{
    local Name

    Name=$(basename "$1")
    Name=${Name%.*}

    if ! Has pkexec
    then
        notify-send -a Wallpapers -i preferences-desktop-wallpaper "Login screen not changed" "pkexec isn't installed, so it can't ask for your password." 2>/dev/null
        return 1
    fi

    pkexec /usr/bin/env bash "$ShrineHere/login-wallpaper.sh" "$1"

    case $? in
        0)
            notify-send -a Wallpapers -i preferences-desktop-wallpaper "Login screen set" "$Name shows when you next log in." 2>/dev/null
            ;;
        3)
            notify-send -a Wallpapers -i preferences-desktop-wallpaper "Login screen not changed" "This only works with Plasma Login Manager. Set it in System Settings → Login Screen instead." 2>/dev/null
            ;;
        126|127)
            # The password box was closed or the password was wrong; nothing changed
            ;;
        *)
            notify-send -a Wallpapers -i preferences-desktop-wallpaper "Login screen not changed" "Something went wrong setting $Name." 2>/dev/null
            ;;
    esac
}

# The Set_Lock_Wallpaper function puts the same picture on KDE's lock screen (it reads this the next time the screen locks)
Set_Lock_Wallpaper()
{
    local Write

    if Has kwriteconfig6
    then
        Write=kwriteconfig6
    elif Has kwriteconfig5
    then
        Write=kwriteconfig5
    else
        return 1
    fi

    "$Write" --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
    "$Write" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$1"
    "$Write" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key PreviewImage "file://$1"
}

# The Wallpaper_List function prints the wallpaper folder, then every image in it (and one folder down), sorted by name
Wallpaper_List()
{
    mkdir -p "$SHRINE_WALLPAPER_DIR" 2>/dev/null
    printf 'DIR\t%s\n' "$SHRINE_WALLPAPER_DIR"

    find "$SHRINE_WALLPAPER_DIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort -f
}

# Section: Music EQ
# The EQ only ever loads output presets named "Shrine ...", so your own presets (like a mic preset for Discord) are left alone
EasyEffectsId="com.github.wwmm.easyeffects"
EqBands=(31 63 125 250 500 1000 2000 4000 8000 16000)

# The Easy_Effects function prints how to run Easy Effects here, or nothing if it isn't installed
Easy_Effects()
{
    if Has easyeffects
    then
        echo "easyeffects"
    elif Has flatpak && flatpak info "$EasyEffectsId" >/dev/null 2>&1
    then
        echo "flatpak run $EasyEffectsId"
    fi
}

# The Eq_Folders function prints Easy Effects' output preset folders (version 8 keeps presets in data, older ones in config)
Eq_Folders()
{
    local Runner
    local Base
    local Bases=()
    local Found=0

    Runner=$(Easy_Effects)
    [ -n "$Runner" ] || return 1

    if [ "${Runner%% *}" = "flatpak" ]
    then
        Bases=("$HOME/.var/app/$EasyEffectsId/data/easyeffects" "$HOME/.var/app/$EasyEffectsId/config/easyeffects")
    else
        Bases=("${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects" "${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects")
    fi

    for Base in "${Bases[@]}"
    do
        if [ -d "$Base" ]
        then
            echo "$Base/output"
            Found=1
        fi
    done

    # Never opened yet: use both, whichever version it turns out to be
    if [ "$Found" = 0 ]
    then
        printf '%s/output\n' "${Bases[@]}"
    fi
}

# The Eq_Json function prints an Easy Effects output preset with a 10-band equaliser set to the given gains
Eq_Json()
{
    local Gains=("$@")
    local Bands=""
    local Index
    local Highest=0
    local Gain

    # Turn the input down by the biggest boost so boosted presets don't clip
    for Gain in "${Gains[@]}"
    do
        if awk -v G="$Gain" -v H="$Highest" 'BEGIN { exit !(G > H) }'
        then
            Highest="$Gain"
        fi
    done

    for Index in "${!EqBands[@]}"
    do
        [ -n "$Bands" ] && Bands+=","
        Bands+=$(printf '"band%d":{"frequency":%s.0,"gain":%s,"mode":"RLC (BT)","mute":false,"q":1.504760237537245,"slope":"x1","solo":false,"type":"Bell","width":4.0}' "$Index" "${EqBands[$Index]}" "${Gains[$Index]:-0}")
    done

    printf '{"output":{"blocklist":[],"equalizer#0":{"balance":0.0,"bypass":false,"input-gain":-%s,"left":{%s},"mode":"IIR","num-bands":10,"output-gain":0.0,"pitch-left":0.0,"pitch-right":0.0,"right":{%s},"split-channels":false},"plugins_order":["equalizer#0"]}}\n' "$Highest" "$Bands" "$Bands"
}

# The Eq_Apply function writes a Shrine preset from 10 gains, loads it in Easy Effects, and remembers it for the music menu
Eq_Apply()
{
    local Key="${1,,}"
    shift
    local Gains=("$@")
    local Gain
    local Name
    local Runner
    local Folder
    local List=""

    [ "${#Gains[@]}" = 10 ] || { echo "eq-apply needs a preset name and 10 gains" >&2; return 1; }

    for Gain in "${Gains[@]}"
    do
        [[ "$Gain" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || { echo "Not a number: $Gain" >&2; return 1; }
        [ -n "$List" ] && List+=","
        List+="$Gain"
    done

    [[ "$Key" =~ ^[a-z]+$ ]] || { echo "Bad preset name: $Key" >&2; return 1; }
    Name="Shrine ${Key^}"

    Runner=$(Easy_Effects)
    [ -n "$Runner" ] || return 1

    while IFS= read -r Folder
    do
        mkdir -p "$Folder" && Eq_Json "${Gains[@]}" > "$Folder/$Name.json"
    done < <(Eq_Folders)

    # shellcheck disable=SC2086
    setsid -f $Runner -l "$Name" >/dev/null 2>&1

    mkdir -p "$StateDir"
    printf '{"preset": "%s", "gains": [%s]}\n' "$Key" "$List" > "$StateDir/eq.json"
}

# The Eq_Status function prints whether the EQ can be used, and the preset and gains last picked
Eq_Status()
{
    local Available=false
    local Saved

    [ -n "$(Easy_Effects)" ] && Available=true
    Saved=$(cat "$StateDir/eq.json" 2>/dev/null)
    [ -n "$Saved" ] || Saved='{"preset": "flat", "gains": [0,0,0,0,0,0,0,0,0,0]}'

    printf '{"available": %s, "saved": %s}\n' "$Available" "$Saved"
}

# Section: Actions
case "${1:-}" in
    store) Launch_App "$SHRINE_STORE_APP" || Launch_App org.kde.discover || { Has plasma-discover && setsid -f plasma-discover >/dev/null 2>&1; } ;;
    # With no browser found, opening any web page starts whatever the system uses
    browser) Launch_App "$SHRINE_BROWSER_APP" || Open_Path "https://duckduckgo.com" ;;
    music) Launch_App "$SHRINE_MUSIC_APP" || Open_Path "$SHRINE_MUSIC_URL" ;;
    music-pill) Music_Pill ;;
    keepawake-pill) Keep_Awake_Pill ;;
    update) Update ;;
    update-run) Update_Run ;;
    system-monitor) System_Monitor ;;
    # Runs a command in your terminal (the launcher uses this for terminal apps like btop)
    in-terminal) shift; Run_In_Terminal "${1##*/}" "$@" ;;
    open-folder) Open_Folder "$2" ;;
    show-file) Show_File "$2" ;;
    downloads-folder) Open_Folder "$SHRINE_DOWNLOADS_DIR" ;;
    nextcloud-folder) Open_Folder "$SHRINE_NEXTCLOUD_DIR" ;;
    ensure-colours) Ensure_Colours ;;
    apply-theme) Ensure_Colours; Apply_Theme "$2" "$3" ;;
    set-wallpaper) Set_Wallpaper "$2" ;;
    set-login-wallpaper) Set_Login_Wallpaper "$2" ;;
    wallpaper-list) Wallpaper_List ;;
    wallpaper-dir) mkdir -p "$SHRINE_WALLPAPER_DIR" 2>/dev/null; printf '%s\n' "$SHRINE_WALLPAPER_DIR" ;;
    eq-status) Eq_Status ;;
    eq-apply) shift; Eq_Apply "$@" ;;
    # Kept for the installer: succeeds when Easy Effects is installed
    eq-install) [ -n "$(Easy_Effects)" ] ;;
    save-image)
        mkdir -p "$SHRINE_SCREENSHOTS_DIR" && cp "$2" "$SHRINE_SCREENSHOTS_DIR/"
        ;;
    *)
        echo "Usage: run.sh store | browser | music | music-pill | update | system-monitor | open-folder <path> | show-file <path> | save-image <path> | downloads-folder | nextcloud-folder | ensure-colours | apply-theme <json> <css> | set-wallpaper <path> | wallpaper-dir | eq-status | eq-apply <preset> <10 gains> | eq-install" >&2
        exit 1
        ;;
esac
