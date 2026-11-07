// This file contains the control centre: system dials, volume and mic sliders, and Wi-Fi, Bluetooth, night light and keep awake toggles
// Left-click a tile to switch it; right-click Wi-Fi or Bluetooth for KDE's full settings

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Section: Control centre
MenuWindow
{
    id: controlCentre

    panelWidth: 372
    side: "right"

    // Section: State
    // The latest status from controls.sh
    property var status: ({
        "wifiAvailable": false, "wifiOn": false, "wifiName": "", "wiredConnected": false,
        "bluetoothAvailable": false, "bluetoothOn": false, "bluetoothDevice": "", "nightLight": false
    })

    // The island's stats feed (CPU, GPU, memory, temperature), passed in by shell.qml
    property var stats: null

    // Speakers and microphone, from PipeWire
    property var speaker: Pipewire.defaultAudioSink
    property var microphone: Pipewire.defaultAudioSource

    // Section: Functions

    // The dialInfo function gives one dial's label, icon and reading (-1 means that sensor isn't available)
    function dialInfo(Name)
    {
        const Stats = stats;

        if (!Stats)
        {
            return { "label": "", "icon": "", "value": -1, "unit": "", "fill": 0, "hot": false };
        }

        if (Name === "cpu")
        {
            return { "label": "CPU LOAD", "icon": "\uf2db", "value": Stats.cpuUsage, "unit": "%", "fill": Stats.cpuUsage / 100, "hot": false };
        }

        if (Name === "memory")
        {
            const Memory = Stats.ramTotal > 0 ? Math.round(Stats.ramUsed / Stats.ramTotal * 100) : 0;
            return { "label": "MEMORY", "icon": "\uf1c0", "value": Memory, "unit": "%", "fill": Memory / 100, "hot": false };
        }

        if (Name === "gpu")
        {
            return { "label": "GPU", "icon": "\uf108", "value": Stats.gpuUsage, "unit": "%", "fill": Math.max(0, Stats.gpuUsage) / 100, "hot": false };
        }

        return { "label": "TEMP", "icon": "\uf2c9", "value": Stats.cpuTemp, "unit": "°", "fill": Math.max(0, Stats.cpuTemp) / 100, "hot": Stats.cpuTemp >= 80 };
    }

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
        spacing: 14

        // Section: Header
        Item
        {
            width: parent.width
            height: 18

            Text
            {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "CONTROL CENTRE"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.5
            }

            Text
            {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf013"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 13

                // Opens KDE's System Settings
                MouseArea
                {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked:
                    {
                        Quickshell.execDetached(["sh", "-c", "setsid -f systemsettings >/dev/null 2>&1"]);
                        controlCentre.closeMenu();
                    }
                }
            }
        }

        // Section: Dials
        // Arcs that fill as the number rises; the temperature turns red when it runs hot
        Grid
        {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            columnSpacing: 22
            rowSpacing: 10
            visible: controlCentre.stats !== null

            // The four dials stay put; only their numbers change, so they glide instead of being rebuilt
            Repeater
            {
                model: ["cpu", "memory", "gpu", "temp"]

                Item
                {
                    id: dial

                    required property var modelData

                    // This dial's label, icon and reading, worked out from the latest stats
                    property var info: controlCentre.dialInfo(modelData)

                    // The number on screen, which slides to each new reading
                    property real shownValue: Math.max(0, info.value)

                    Behavior on shownValue
                    {
                        NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
                    }

                    width: 128
                    height: 120

                    Canvas
                    {
                        id: dialCanvas

                        // How full the arc is, sliding to each new reading
                        property real fill: Math.max(0, Math.min(1, dial.info.fill))
                        property color fillColour: dial.info.hot ? Theme.accent : Theme.pastel

                        Behavior on fill
                        {
                            NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
                        }

                        Behavior on fillColour
                        {
                            ColorAnimation { duration: 400 }
                        }

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 116
                        height: 116

                        onFillChanged: requestPaint()
                        onFillColourChanged: requestPaint()

                        onPaint:
                        {
                            const Context = getContext("2d");
                            const Middle = width / 2;
                            const Start = Math.PI * 0.75;
                            const Sweep = Math.PI * 1.5;
                            Context.reset();
                            Context.lineWidth = 7;
                            Context.lineCap = "round";

                            // Empty track
                            Context.strokeStyle = Theme.cardHover;
                            Context.beginPath();
                            Context.arc(Middle, Middle, Middle - 6, Start, Start + Sweep);
                            Context.stroke();

                            // Filled part
                            if (fill > 0.005)
                            {
                                Context.strokeStyle = fillColour;
                                Context.beginPath();
                                Context.arc(Middle, Middle, Middle - 6, Start, Start + Sweep * fill);
                                Context.stroke();
                            }
                        }
                    }

                    Column
                    {
                        anchors.centerIn: dialCanvas
                        spacing: 2

                        Row
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Text
                            {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dial.info.icon
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 13
                            }

                            Text
                            {
                                text: dial.info.value < 0 ? "—" : Math.round(dial.shownValue) + dial.info.unit
                                color: dial.info.hot ? Theme.accentHover : Theme.text
                                font.family: Theme.font
                                font.pixelSize: 22
                                font.bold: true
                            }
                        }

                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dial.info.label
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }

        // Section: Sliders
        // Thick bars that fill cream; click or drag anywhere, scroll for 5% steps, click the icon to mute
        Repeater
        {
            model: [
                { "label": "Volume", "icon": "\uf028", "mutedIcon": "\uf026" },
                { "label": "Microphone", "icon": "\uf130", "mutedIcon": "\uf131" }
            ]

            Rectangle
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
                height: 34
                radius: 17
                color: Theme.card
                border.width: 1
                border.color: Theme.cardBorder
                visible: device !== null

                // The filled part (never narrower than the icon, so the icon always sits on it)
                Rectangle
                {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(parent.height, parent.width * Math.min(1, sliderRow.level))
                    color: sliderRow.muted ? Theme.outline : Theme.pastel
                    opacity: sliderRow.muted ? 0.5 : 1

                    Behavior on width
                    {
                        NumberAnimation { duration: 90 }
                    }
                }

                MouseArea
                {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onPressed: (Mouse) => sliderRow.setLevel(Mouse.x / sliderRow.width)
                    onPositionChanged: (Mouse) => sliderRow.setLevel(Mouse.x / sliderRow.width)
                    onWheel: (Wheel) => sliderRow.setLevel(sliderRow.level + (Wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }

                Text
                {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: sliderRow.muted ? sliderRow.modelData.mutedIcon : sliderRow.modelData.icon
                    color: Theme.pastelText
                    font.family: Theme.font
                    font.pixelSize: 14

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.margins: -8
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
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: sliderRow.muted ? "MUTED" : Math.round(sliderRow.level * 100) + "%"
                    color: sliderRow.level > 0.9 && !sliderRow.muted ? Theme.pastelText : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        // Section: Tiles
        // Square toggles that fill cream when on; right-click Wi-Fi or Bluetooth for KDE's settings
        Row
        {
            width: parent.width
            spacing: 8

            Repeater
            {
                model: [
                    { "name": "wifi", "label": "WI-FI", "icon": "\uf1eb" },
                    { "name": "bluetooth", "label": "BLUETOOTH", "icon": "\uf294" },
                    { "name": "night", "label": "NIGHT", "icon": "\udb83\udf65" },
                    { "name": "awake", "label": "AWAKE", "icon": "\uf0f4" }
                ]

                Rectangle
                {
                    id: tile

                    required property var modelData

                    property bool active: controlCentre.tileActive(modelData.name)

                    width: (parent.width - 24) / 4
                    height: 74
                    radius: 14
                    color: active ? Theme.pastel : (tileArea.containsMouse ? Theme.cardHover : Theme.card)
                    border.width: 1
                    border.color: active ? "transparent" : Theme.cardBorder

                    Behavior on color
                    {
                        ColorAnimation { duration: 150 }
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 15
                        text: tile.modelData.icon
                        color: tile.active ? Theme.pastelText : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 20
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 48
                        width: parent.width - 6
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.label
                        color: tile.active ? Theme.pastelText : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.5
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

        // Section: Connections
        // What the network and Bluetooth are connected to
        Rectangle
        {
            width: parent.width
            height: 36
            radius: 12
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Row
            {
                anchors.centerIn: parent
                spacing: 14

                Repeater
                {
                    model: [
                        { "icon": controlCentre.status.wifiAvailable ? "\uf1eb" : "\uf0e8", "text": controlCentre.tileSubtitle("wifi") },
                        { "icon": "\uf294", "text": controlCentre.tileSubtitle("bluetooth") }
                    ]

                    Text
                    {
                        required property var modelData

                        width: Math.min(implicitWidth, 150)
                        elide: Text.ElideRight
                        text: modelData.icon + "  " + modelData.text
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
