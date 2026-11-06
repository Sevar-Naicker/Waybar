#!/bin/bash
# This file contains the control centre's status feed
# Prints one line of JSON every few seconds: Wi-Fi, wired network, Bluetooth and night light
# Usage: controls.sh [seconds between checks, default 3]

# Section: Settings
Interval=${1:-3}

# The has function says whether a command is installed
has()
{
    command -v "$1" >/dev/null 2>&1
}

# The json_text function makes text safe to put inside JSON quotes
json_text()
{
    local Text="${1//\\/\\\\}"
    Text="${Text//\"/\\\"}"
    printf '%s' "$Text"
}

# The check_network function sets the Wi-Fi and wired variables from NetworkManager
check_network()
{
    WifiAvailable=false
    WifiOn=false
    WifiName=""
    WiredConnected=false

    has nmcli || return

    [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ] && WifiOn=true

    # Lines look like  wlp3s0:wifi:connected:Home_5G  (colons inside names come escaped as \:)
    while IFS= read -r Line
    do
        Line="${Line//\\:/$'\x1f'}"
        IFS=: read -r _ Type State Connection <<< "$Line"
        Connection="${Connection//$'\x1f'/:}"

        case "$Type" in
            wifi)
                WifiAvailable=true
                [ "$State" = "connected" ] && WifiName="$Connection"
                ;;
            ethernet)
                [ "$State" = "connected" ] && WiredConnected=true
                ;;
        esac
    done < <(timeout 3 nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null)
}

# The check_bluetooth function sets the Bluetooth variables from bluetoothctl
check_bluetooth()
{
    BluetoothAvailable=false
    BluetoothOn=false
    BluetoothDevice=""

    has bluetoothctl || return

    local Show
    Show=$(timeout 3 bluetoothctl show 2>/dev/null)

    # No adapter means no "Controller" line
    grep -q "^Controller" <<< "$Show" || return
    BluetoothAvailable=true
    grep -q "Powered: yes" <<< "$Show" && BluetoothOn=true

    # Lines look like  Device AA:BB:CC:DD:EE:FF JBL Tune 720BT
    BluetoothDevice=$(timeout 3 bluetoothctl devices Connected 2>/dev/null | head -n 1 | cut -d' ' -f3-)
}

# The check_night_light function asks night-light.sh whether the screen is warmed
check_night_light()
{
    NightLight=false
    local Script="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/night-light.sh"

    [ -r "$Script" ] && bash "$Script" 2>/dev/null | grep -q '"class": "on"' && NightLight=true
}

# Section: Main loop
while true
do
    check_network
    check_bluetooth
    check_night_light

    printf '{"wifiAvailable": %s, "wifiOn": %s, "wifiName": "%s", "wiredConnected": %s, "bluetoothAvailable": %s, "bluetoothOn": %s, "bluetoothDevice": "%s", "nightLight": %s}\n' \
        "$WifiAvailable" "$WifiOn" "$(json_text "$WifiName")" "$WiredConnected" \
        "$BluetoothAvailable" "$BluetoothOn" "$(json_text "$BluetoothDevice")" "$NightLight"

    sleep "$Interval"
done
