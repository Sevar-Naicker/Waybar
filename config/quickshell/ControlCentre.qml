// This file contains the control centre: Wi-Fi, Bluetooth, night light and keep awake toggles, plus volume and mic sliders
// Left-click a tile to switch it; right-click Wi-Fi or Bluetooth for KDE's full settings

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Section: Control centre
MenuWindow
{
    id: controlCentre

    panelWidth: 330
    side: "right"

    // Section: State
    // The latest status from controls.sh
    property var status: ({
        "wifiAvailable": false, "wifiOn": false, "wifiName": "", "wiredConnected": false,
        "bluetoothAvailable": false, "bluetoothOn": false, "bluetoothDevice": "", "nightLight": false
    })

    // Speakers and microphone, from PipeWire
    property var speaker: Pipewire.defaultAudioSink
    property var microphone: Pipewire.defaultAudioSource

    // Section: Functions

    // The setStatus function changes one value straight away, so a tile responds before the next check
    function setStatus(Key, Value)
    {
        const Updated = Object.assign({}, status);
        Updated[Key] = Value;
        status = Updated;
    }

    // The recheck function asks for fresh status a moment after something was switched
    function recheck()
    {
        recheckTimer.restart();
    }

    // The tileSubtitle function words the small line under each tile's name
    function tileSubtitle(Name)
    {
        if (Name === "wifi")
        {
            if (!status.wifiAvailable)
            {
                return status.wiredConnected ? "Ethernet connected" : "No Wi-Fi";
            }

            if (!status.wifiOn)
            {
                return "Off";
            }

            return status.wifiName || "Not connected";
        }

        if (Name === "bluetooth")
        {
            if (!status.bluetoothAvailable)
            {
                return "Not available";
            }

            if (!status.bluetoothOn)
            {
                return "Off";
            }

            return status.bluetoothDevice || "On";
        }

        if (Name === "night")
        {
            return status.nightLight ? "On" : "Off";
        }

        return ShellState.keepAwake ? "On" : "Off";
    }

    // The tileActive function says whether a tile shows as switched on
    function tileActive(Name)
    {
        if (Name === "wifi")
        {
            return status.wifiAvailable ? status.wifiOn : status.wiredConnected;
        }

        if (Name === "bluetooth")
        {
            return status.bluetoothAvailable && status.bluetoothOn;
        }

        if (Name === "night")
        {
            return status.nightLight;
        }

        return ShellState.keepAwake;
    }

    // The toggleTile function switches a tile on or off
    function toggleTile(Name)
    {
        if (Name === "wifi")
        {
            if (!status.wifiAvailable)
            {
                openSettings("wifi");
                return;
            }

            Quickshell.execDetached(["nmcli", "radio", "wifi", status.wifiOn ? "off" : "on"]);
            setStatus("wifiOn", !status.wifiOn);
        }
        else if (Name === "bluetooth")
        {
            if (!status.bluetoothAvailable)
            {
                return;
            }

            Quickshell.execDetached(["bluetoothctl", "power", status.bluetoothOn ? "off" : "on"]);
            setStatus("bluetoothOn", !status.bluetoothOn);
        }
        else if (Name === "night")
        {
            Quickshell.execDetached(["sh", "-c", "bash \"${XDG_CONFIG_HOME:-$HOME/.config}/waybar/night-light.sh\" --toggle >/dev/null; pkill -RTMIN+9 -x waybar"]);
            setStatus("nightLight", !status.nightLight);
        }
        else
        {
            ShellState.keepAwake = !ShellState.keepAwake;
        }

        recheck();
    }

    // The openSettings function opens KDE's settings page for Wi-Fi or Bluetooth
    function openSettings(Name)
    {
        const Page = Name === "bluetooth" ? "kcm_bluetooth" : "kcm_networkmanagement";
        Quickshell.execDetached(["sh", "-c", "setsid -f systemsettings " + Page + " >/dev/null 2>&1"]);
        closeMenu();
    }

    // Section: Status feed
    // Only runs while the control centre is open
    Process
    {
        id: statusProcess

        command: ["sh", "-c", "exec bash \"$HOME/.config/quickshell/controls.sh\" 3"]
        running: controlCentre.shown

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    controlCentre.status = JSON.parse(Line);
                }
                catch (Problem)
                {
                }
            }
        }
    }

    // Restarts the feed shortly after a switch, so the tiles confirm the real state
    Timer
    {
        id: recheckTimer
        interval: 1200
        onTriggered:
        {
            statusProcess.running = false;
            statusProcess.running = controlCentre.shown;
        }
    }

    // PipeWire only fills in volume and mute once something tracks the device
    PwObjectTracker
    {
        objects: [controlCentre.speaker, controlCentre.microphone].filter(Node => Node)
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 12

        // Section: Tiles
        Grid
        {
            width: parent.width
            columns: 2
            spacing: 8

            Repeater
            {
                model: [
                    { "name": "wifi", "label": "Wi-Fi", "icon": "" },
                    { "name": "bluetooth", "label": "Bluetooth", "icon": "" },
                    { "name": "night", "label": "Night light", "icon": "" },
                    { "name": "awake", "label": "Keep awake", "icon": "" }
                ]

                Rectangle
                {
                    id: tile

                    required property var modelData

                    property bool active: controlCentre.tileActive(modelData.name)

                    width: (parent.width - 8) / 2
                    height: 58
                    radius: 14
                    color: active ? Theme.accent : (tileArea.containsMouse ? Theme.softHover : Theme.soft)

                    Behavior on color
                    {
                        ColorAnimation { duration: 150 }
                    }

                    Text
                    {
                        id: tileIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        text: tile.modelData.icon
                        color: tile.active ? Theme.accentText : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                    }

                    Column
                    {
                        anchors.left: tileIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text
                        {
                            width: parent.width
                            text: tile.modelData.label
                            elide: Text.ElideRight
                            color: tile.active ? Theme.accentText : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text
                        {
                            width: parent.width
                            text: controlCentre.tileSubtitle(tile.modelData.name)
                            elide: Text.ElideRight
                            color: tile.active ? Theme.accentText : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    MouseArea
                    {
                        id: tileArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (Mouse) =>
                        {
                            const Name = tile.modelData.name;

                            if (Mouse.button === Qt.RightButton && (Name === "wifi" || Name === "bluetooth"))
                            {
                                controlCentre.openSettings(Name);
                            }
                            else if (Mouse.button === Qt.LeftButton)
                            {
                                controlCentre.toggleTile(Name);
                            }
                        }
                    }
                }
            }
        }

        // Section: Sliders
        Repeater
        {
            model: [
                { "label": "Volume", "icon": "", "mutedIcon": "" },
                { "label": "Microphone", "icon": "", "mutedIcon": "" }
            ]

            Item
            {
                id: sliderRow

                required property var modelData
                required property int index

                // The device this slider controls, and its audio controls once PipeWire has filled them in
                property var device: index === 0 ? controlCentre.speaker : controlCentre.microphone
                property var audio: device && device.audio ? device.audio : null
                property real level: audio ? audio.volume : 0
                property bool muted: audio ? audio.muted : false

                // The setLevel function sets the volume (0 to 1) and unmutes
                function setLevel(Value)
                {
                    if (audio)
                    {
                        audio.muted = false;
                        audio.volume = Math.max(0, Math.min(1, Value));
                    }
                }

                width: parent.width
                height: 24
                visible: device !== null

                // Click the icon to mute or unmute
                Text
                {
                    id: sliderIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: sliderRow.muted ? sliderRow.modelData.mutedIcon : sliderRow.modelData.icon
                    color: sliderRow.muted ? Theme.outline : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked:
                        {
                            if (sliderRow.audio)
                            {
                                sliderRow.audio.muted = !sliderRow.muted;
                            }
                        }
                    }
                }

                Text
                {
                    id: sliderValue

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: sliderRow.muted ? "Off" : Math.round(sliderRow.level * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                // Click or drag anywhere on the track; scroll over it for 5% steps
                Rectangle
                {
                    id: sliderTrack

                    anchors.left: sliderIcon.right
                    anchors.right: sliderValue.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Theme.soft

                    Rectangle
                    {
                        height: parent.height
                        radius: 3
                        width: parent.width * sliderRow.level
                        color: sliderRow.muted ? Theme.outline : Theme.accent
                    }

                    Rectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * sliderRow.level - width / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.text
                    }

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.topMargin: -8
                        anchors.bottomMargin: -8
                        cursorShape: Qt.PointingHandCursor

                        onPressed: (Mouse) => sliderRow.setLevel(Mouse.x / sliderTrack.width)
                        onPositionChanged: (Mouse) => sliderRow.setLevel(Mouse.x / sliderTrack.width)
                        onWheel: (Wheel) => sliderRow.setLevel(sliderRow.level + (Wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }
            }
        }

        // Section: Hint
        Text
        {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Right-click Wi-Fi or Bluetooth for settings"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
