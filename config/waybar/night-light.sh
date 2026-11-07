#!/bin/bash
# This file contains the night light module for the Shrine Waybar
# Run with no arguments for the pill's status, --toggle to switch KDE's night light on or off, or --settings to open its settings

# Section: Settings
# Anything warmer than this counts as night light being on (6500K is normal daylight)
WarmThreshold=6400
# A solid crescent (Nerd Font md-moon_waning_crescent), so it fills with colour like the coffee pill
MoonIcon=$'\xf3\xb0\xbd\xa5 '

# The read_temperature function asks KWin for the screen's colour temperature
# It prefers the temperature KWin is heading towards, so the pill reacts as soon as night light is toggled
# instead of waiting for the screen's gradual fade; newer Plasma uses /org/kde/KWin/NightLight, older /ColorCorrect
read_temperature()
{
    local Reply
    local Property

    for Property in targetTemperature currentTemperature
    do
        Reply=$(gdbus call --session --dest org.kde.KWin --object-path /org/kde/KWin/NightLight \
            --method org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "$Property" 2>/dev/null)

        if [[ -z "$Reply" ]]
        then
            Reply=$(gdbus call --session --dest org.kde.KWin --object-path /ColorCorrect \
                --method org.freedesktop.DBus.Properties.Get org.kde.kwin.ColorCorrect "$Property" 2>/dev/null)
        fi

        # The reply looks like "(<uint32 4500>,)"; keep just the number
        Reply=$(echo "$Reply" | grep -oE '[0-9]{3,5}' | tail -n 1)

        if [[ -n "$Reply" ]]
        then
            echo "$Reply"
            return
        fi
    done
}

# The read_flag function reads a true/false property from KWin's Night Light (prints "true", "false" or nothing)
#   enabled: switched on in System Settings; inhibited: paused (what clicking the moon toggles)
read_flag()
{
    gdbus call --session --dest org.kde.KWin --object-path /org/kde/KWin/NightLight \
        --method org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "$1" 2>/dev/null | grep -oE 'true|false'
}

# The open_settings function opens KDE's Night Light settings page
open_settings()
{
    setsid -f systemsettings kcm_nightlight >/dev/null 2>&1
}

# Section: Settings page
if [[ "$1" == "--settings" ]]
then
    open_settings
    exit 0
fi

Enabled=$(read_flag enabled)

# Section: Toggle
# With Night Light switched off in System Settings, KDE's toggle does nothing, so open its settings instead
if [[ "$1" == "--toggle" && "$Enabled" == "false" ]]
then
    open_settings
elif [[ "$1" == "--toggle" ]]
then
    gdbus call --session --dest org.kde.kglobalaccel --object-path /component/kwin \
        --method org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color" >/dev/null 2>&1
    sleep 0.3
fi

# Section: Status
# The pill is coloured while Night Light is on, whether it's warming the screen yet or waiting for sunset (like the coffee pill)
Temperature=$(read_temperature)
Inhibited=$(read_flag inhibited)

if [[ "$Enabled" == "false" ]]
then
    printf '{"text": "%s", "tooltip": "Night light is turned off in System Settings\\nClick to open its settings and turn it on", "class": "disabled"}\n' "$MoonIcon"
elif [[ "$Inhibited" == "true" ]]
then
    printf '{"text": "%s", "tooltip": "Night light paused\\nClick to turn it back on", "class": "off"}\n' "$MoonIcon"
elif [[ "$Inhibited" == "false" ]]
then
    if [[ -n "$Temperature" ]] && (( Temperature < WarmThreshold ))
    then
        printf '{"text": "%s", "tooltip": "Night light on (%sK)\\nClick to pause", "class": "on"}\n' "$MoonIcon" "$Temperature"
    else
        printf '{"text": "%s", "tooltip": "Night light on\\nWarms the screen on its schedule (like sunset)\\nClick to pause", "class": "on"}\n' "$MoonIcon"
    fi
elif [[ -z "$Temperature" ]]
then
    printf '{"text": "%s", "tooltip": "Night light\\nClick to toggle", "class": "unknown"}\n' "$MoonIcon"
elif (( Temperature < WarmThreshold ))
then
    # Older Plasma without "inhibited": go by how warm the screen is
    printf '{"text": "%s", "tooltip": "Night light on (%sK)\\nClick to turn off", "class": "on"}\n' "$MoonIcon" "$Temperature"
else
    printf '{"text": "%s", "tooltip": "Night light off\\nClick to turn on", "class": "off"}\n' "$MoonIcon"
fi
