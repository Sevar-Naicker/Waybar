// This file contains the music menu: a spinning disc of the album art, the track, controls, and a 10-band equaliser
// It opens from the island's music section; the equaliser goes through Easy Effects (output presets only, so mic presets are left alone)

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// Section: Music menu
MenuWindow
{
    id: musicMenu

    side: "centre"
    panelWidth: 540

    // Section: Player
    // The last player that was playing, so pausing doesn't hand the menu to another app
    property var lastPlayed: null

    // Prefer what's playing, then what was last playing, then anything
    property var player:
    {
        const Players = Mpris.players.values;
        const Playing = Players.find(Player => Player.isPlaying);

        if (Playing)
        {
            return Playing;
        }

        if (lastPlayed && Players.includes(lastPlayed))
        {
            return lastPlayed;
        }

        return Players.length > 0 ? Players[0] : null;
    }

    property bool playing: player ? player.isPlaying : false
    property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    onPlayingChanged:
    {
        if (playing)
        {
            lastPlayed = player;
        }
    }

    // The formatTime function turns seconds into mm:ss
    function formatTime(Seconds)
    {
        const Whole = Math.max(0, Math.floor(Seconds || 0));
        const Minutes = Math.floor(Whole / 60);
        const Rest = Whole % 60;
        return (Minutes < 10 ? "0" : "") + Minutes + ":" + (Rest < 10 ? "0" : "") + Rest;
    }

    // Players don't push their position, so ask every second while the menu is open
    Timer
    {
        interval: 1000
        repeat: true
        running: musicMenu.shown && musicMenu.playing
        onTriggered: musicMenu.player.positionChanged()
    }

    // Section: Backdrop
    // The album art, blurred and dimmed behind everything (moved into the panel's rounded backdrop layer)
    Item
    {
        parent: musicMenu.backdropLayer
        anchors.fill: parent
        visible: musicMenu.artUrl !== ""

        Image
        {
            id: backdropArt

            anchors.fill: parent
            source: musicMenu.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            asynchronous: true
            visible: false
        }

        MultiEffect
        {
            anchors.fill: parent
            source: backdropArt
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
            opacity: 0.35
        }

        // Darker towards the bottom so the equaliser stays easy to read
        Rectangle
        {
            anchors.fill: parent

            gradient: Gradient
            {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.panel }
            }
        }
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 16

        // Section: Now playing
        Item
        {
            width: parent.width
            height: 150

            // Section: Disc
            // The cover as a record: it turns while music plays and glows round the edge
            Item
            {
                id: disc

                width: 140
                height: 140
                anchors.verticalCenter: parent.verticalCenter

                // Soft glow ring while playing
                Rectangle
                {
                    anchors.centerIn: parent
                    width: parent.width + 14
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 6
                    border.color: Theme.pastel
                    opacity: musicMenu.playing ? 0.35 : 0

                    Behavior on opacity
                    {
                        NumberAnimation { duration: 400 }
                    }
                }

                Item
                {
                    id: record

                    anchors.fill: parent

                    // Turns once every 8 seconds while music plays, and stops where it is when it pauses
                    FrameAnimation
                    {
                        running: musicMenu.shown && musicMenu.playing
                        onTriggered: record.rotation = (record.rotation + frameTime * 45) % 360
                    }

                    Rectangle
                    {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.card
                    }

                    // No art: a music note in the middle
                    Text
                    {
                        anchors.centerIn: parent
                        visible: musicMenu.artUrl === ""
                        text: ""
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 40
                    }

                    // The cover, cut to a circle
                    ClippingRectangle
                    {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        visible: musicMenu.artUrl !== ""

                        Image
                        {
                            anchors.fill: parent
                            source: musicMenu.artUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 280
                            sourceSize.height: 280
                            asynchronous: true
                        }
                    }

                    // The hole in the middle and the white rim
                    Rectangle
                    {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: "#0B0B0B"
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                    }

                    Rectangle
                    {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }
            }

            // Section: Track
            Column
            {
                anchors.left: disc.right
                anchors.leftMargin: 22
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text
                {
                    width: parent.width
                    elide: Text.ElideRight
                    text: musicMenu.player ? (musicMenu.player.trackTitle || "Unknown track") : "Nothing playing"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                }

                Text
                {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: musicMenu.player !== null
                    text: "BY " + (musicMenu.player && musicMenu.player.trackArtist ? musicMenu.player.trackArtist : "Unknown artist")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                // Which app is playing
                Rectangle
                {
                    visible: musicMenu.player !== null
                    width: viaText.implicitWidth + 16
                    height: 20
                    radius: 6
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.cardBorder

                    Text
                    {
                        id: viaText

                        anchors.centerIn: parent
                        text: "VIA " + (musicMenu.player ? musicMenu.player.identity : "")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                        font.italic: true
                    }
                }

                // Progress: click or drag to jump
                Item
                {
                    id: progress

                    property real fraction: musicMenu.player && musicMenu.player.length > 0 ? Math.min(1, musicMenu.player.position / musicMenu.player.length) : 0

                    width: parent.width
                    height: 16
                    visible: musicMenu.player !== null

                    Rectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.cardHover

                        Rectangle
                        {
                            width: parent.width * progress.fraction
                            height: parent.height
                            radius: 3
                            color: Theme.pastel
                        }
                    }

                    Rectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * progress.fraction - width / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.text
                    }

                    MouseArea
                    {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: musicMenu.player !== null && musicMenu.player.canSeek

                        // The seek function jumps to where the mouse is along the bar
                        function seek(X)
                        {
                            const Player = musicMenu.player;
                            Player.position = Math.max(0, Math.min(1, X / width)) * Player.length;
                        }

                        onPressed: (Mouse) => seek(Mouse.x)
                        onPositionChanged: (Mouse) => seek(Mouse.x)
                    }
                }

                Item
                {
                    width: parent.width
                    height: 14
                    visible: musicMenu.player !== null

                    Text
                    {
                        text: musicMenu.formatTime(musicMenu.player ? musicMenu.player.position : 0)
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    Text
                    {
                        anchors.right: parent.right
                        text: musicMenu.formatTime(musicMenu.player ? musicMenu.player.length : 0)
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                // Previous, play or pause, next
                Row
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 26
                    visible: musicMenu.player !== null

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Theme.text
                        opacity: musicMenu.player && musicMenu.player.canGoPrevious ? 1 : 0.4
                        font.family: Theme.font
                        font.pixelSize: 15

                        MouseArea
                        {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: musicMenu.player.previous()
                        }
                    }

                    Rectangle
                    {
                        width: 44
                        height: 44
                        radius: 22
                        color: playHover.containsMouse ? Theme.text : Theme.pastel

                        Behavior on color
                        {
                            ColorAnimation { duration: 120 }
                        }

                        Text
                        {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: musicMenu.playing ? 0 : 2
                            text: musicMenu.playing ? "" : ""
                            color: Theme.pastelText
                            font.family: Theme.font
                            font.pixelSize: 16
                        }

                        MouseArea
                        {
                            id: playHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:
                            {
                                if (musicMenu.player && musicMenu.player.canTogglePlaying)
                                {
                                    musicMenu.player.togglePlaying();
                                }
                            }
                        }
                    }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Theme.text
                        opacity: musicMenu.player && musicMenu.player.canGoNext ? 1 : 0.4
                        font.family: Theme.font
                        font.pixelSize: 15

                        MouseArea
                        {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: musicMenu.player.next()
                        }
                    }
                }
            }
        }

        Rectangle
        {
            width: parent.width
            height: 1
            color: Theme.edge
        }

        // Section: Equaliser
        Item
        {
            width: parent.width
            height: 24

            Text
            {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "Equalizer"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }

            // The preset in use ("Custom" once a slider has moved)
            Rectangle
            {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: ShellState.eqAvailable
                width: presetName.implicitWidth + 20
                height: 24
                radius: 8
                color: Theme.card
                border.width: 1
                border.color: Theme.cardBorder

                Text
                {
                    id: presetName

                    anchors.centerIn: parent
                    text:
                    {
                        const Preset = ShellState.eqPresets.find(Item => Item.name === ShellState.eqPreset);
                        return Preset ? Preset.label : "Custom";
                    }
                    color: Theme.pastel
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        // Ten bands: drag a knob, scroll over it for half steps, double-click to put it back to 0
        Item
        {
            width: parent.width
            height: 170
            opacity: ShellState.eqAvailable ? 1 : 0.35
            enabled: ShellState.eqAvailable

            Row
            {
                anchors.fill: parent

                Repeater
                {
                    model: ShellState.eqBands

                    Item
                    {
                        id: band

                        required property var modelData
                        required property int index

                        // This band's gain, -12 to +12 dB, as a share of the slider from the bottom
                        property real gain: ShellState.eqGains[index] || 0
                        property real level: (gain + 12) / 24
                        property bool dragging: bandArea.pressed

                        width: parent.width / 10
                        height: parent.height

                        // The dB value, shown while dragging or hovering
                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            visible: band.dragging || bandArea.containsMouse
                            text: (band.gain > 0 ? "+" : "") + band.gain
                            color: Theme.pastel
                            font.family: Theme.font
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Item
                        {
                            id: track

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 16
                            width: 26
                            height: parent.height - 40

                            // Groove, and the filled part up to the knob
                            Rectangle
                            {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 6
                                height: parent.height
                                radius: 3
                                color: Theme.cardHover
                            }

                            Rectangle
                            {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: 6
                                height: parent.height * band.level
                                radius: 3
                                color: Theme.pastel

                                Behavior on height
                                {
                                    enabled: !band.dragging
                                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                                }
                            }

                            // Zero line
                            Rectangle
                            {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height / 2
                                width: 12
                                height: 1
                                color: Theme.edge
                            }

                            Rectangle
                            {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height * (1 - band.level) - height / 2
                                width: band.dragging ? 18 : 15
                                height: width
                                radius: width / 2
                                color: Theme.text

                                Behavior on y
                                {
                                    enabled: !band.dragging
                                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea
                            {
                                id: bandArea

                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true

                                // The setFrom function turns the mouse height into a gain
                                function setFrom(Y)
                                {
                                    const Share = 1 - Math.max(0, Math.min(1, (Y - 6) / track.height));
                                    ShellState.setEqBand(band.index, Share * 24 - 12);
                                }

                                onPressed: (Mouse) => setFrom(Mouse.y)
                                onPositionChanged: (Mouse) =>
                                {
                                    if (pressed)
                                    {
                                        setFrom(Mouse.y);
                                    }
                                }
                                onDoubleClicked: ShellState.setEqBand(band.index, 0)
                                onWheel: (Wheel) => ShellState.setEqBand(band.index, band.gain + (Wheel.angleDelta.y > 0 ? 0.5 : -0.5))
                            }
                        }

                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: band.modelData
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }

        // Section: Presets
        Grid
        {
            width: parent.width
            columns: 4
            columnSpacing: 8
            rowSpacing: 8
            opacity: ShellState.eqAvailable ? 1 : 0.35
            enabled: ShellState.eqAvailable

            Repeater
            {
                model: ShellState.eqPresets

                Rectangle
                {
                    id: presetButton

                    required property var modelData

                    property bool active: ShellState.eqPreset === modelData.name

                    width: (parent.width - 24) / 4
                    height: 30
                    radius: 8
                    color: active ? Theme.pastel : (presetHover.containsMouse ? Theme.cardHover : Theme.card)
                    border.width: 1
                    border.color: active ? "transparent" : Theme.cardBorder

                    Behavior on color
                    {
                        ColorAnimation { duration: 150 }
                    }

                    Text
                    {
                        anchors.centerIn: parent
                        text: presetButton.modelData.label
                        color: presetButton.active ? Theme.pastelText : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: presetButton.active
                    }

                    MouseArea
                    {
                        id: presetHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.setEqPreset(presetButton.modelData.name)
                    }
                }
            }
        }

        // Without Easy Effects there's nothing to drive the equaliser
        Text
        {
            visible: !ShellState.eqAvailable
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Install Easy Effects (Flatpak: com.github.wwmm.easyeffects) to use the equaliser."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
