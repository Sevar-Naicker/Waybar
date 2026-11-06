// This file contains the power menu that drops down from the power pill
// Lock and sleep happen straight away; log out, restart and shut down ask for a second click first

import Quickshell
import Quickshell.Io
import QtQuick

// Section: Power menu
MenuWindow
{
    id: powerMenu

    panelWidth: 460
    side: "right"

    // Section: State
    property string userName: Quickshell.env("USER") || "you"
    property string fullName: ""
    property string uptimeText: ""
    property string systemName: ""
    property string hostName: ""
    property string kernel: ""

    // The highlighted button, and the one waiting for its confirming second click (-1 means none)
    property int selected: -1
    property int armed: -1

    // Section: Actions
    // On KDE, log out, restart and shut down go through KDE so your session closes properly; elsewhere they use loginctl and systemctl
    property var actions: [
        {
            "label": "Lock",
            "icon": "",
            "confirm": false,
            "command": "loginctl lock-session"
        },
        {
            "label": "Sleep",
            "icon": "",
            "confirm": false,
            "command": "systemctl suspend"
        },
        {
            "label": "Log out",
            "icon": "",
            "confirm": true,
            "command": "gdbus call --session --dest org.kde.Shutdown --object-path /Shutdown --method org.kde.Shutdown.logout || loginctl terminate-session \"$XDG_SESSION_ID\""
        },
        {
            "label": "Restart",
            "icon": "",
            "confirm": true,
            "command": "gdbus call --session --dest org.kde.Shutdown --object-path /Shutdown --method org.kde.Shutdown.logoutAndReboot || systemctl reboot"
        },
        {
            "label": "Shut down",
            "icon": "",
            "confirm": true,
            "command": "gdbus call --session --dest org.kde.Shutdown --object-path /Shutdown --method org.kde.Shutdown.logoutAndShutdown || systemctl poweroff"
        }
    ]

    // Fresh details and nothing armed every time it opens
    onShownChanged:
    {
        if (shown)
        {
            selected = -1;
            armed = -1;
            detailsProcess.running = true;
            keyCatcher.forceActiveFocus();
        }
    }

    // Section: Functions

    // The initials function turns the name into one or two letters for the round badge
    function initials()
    {
        const Name = (fullName || userName).trim();
        const Words = Name.split(/\s+/).filter(Word => Word.length > 0);

        if (Words.length >= 2)
        {
            return (Words[0][0] + Words[Words.length - 1][0]).toUpperCase();
        }

        return Name.slice(0, 2).toUpperCase();
    }

    // The activate function runs an action, or arms it first if it needs a second click
    function activate(Index)
    {
        const Action = actions[Index];

        if (Action.confirm && armed !== Index)
        {
            armed = Index;
            disarmTimer.restart();
            return;
        }

        closeMenu();
        Quickshell.execDetached(["sh", "-c", Action.command]);
    }

    // Section: Details
    // Reads your full name, how long the computer has been on, the system's name, the computer's name and the kernel
    Process
    {
        id: detailsProcess

        property var lines: []

        command: ["sh", "-c",
            "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1; " +
            "cut -d' ' -f1 /proc/uptime; " +
            "( . /etc/os-release 2>/dev/null; echo \"${NAME:-Linux}\" ); " +
            "cat /proc/sys/kernel/hostname; " +
            "uname -r"]

        onStarted: lines = []

        stdout: SplitParser
        {
            onRead: (Line) => detailsProcess.lines.push(Line)
        }

        onExited:
        {
            powerMenu.fullName = lines[0] || "";

            const Seconds = Math.floor(parseFloat(lines[1]) || 0);
            const Hours = Math.floor(Seconds / 3600);
            const Minutes = Math.floor((Seconds % 3600) / 60);
            powerMenu.uptimeText = "Up " + (Hours > 0 ? Hours + "h " : "") + Minutes + "m";

            powerMenu.systemName = lines[2] || "";
            powerMenu.hostName = lines[3] || "";
            powerMenu.kernel = lines[4] || "";
        }
    }

    // A confirming click has 3 seconds before it's forgotten
    Timer
    {
        id: disarmTimer
        interval: 3000
        onTriggered: powerMenu.armed = -1
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 12

        // Section: Keyboard
        // Left and right pick a button, Enter presses it
        Item
        {
            id: keyCatcher

            width: 0
            height: 0
            focus: true

            Keys.onPressed: (Event) =>
            {
                if (Event.key === Qt.Key_Right || Event.key === Qt.Key_Tab)
                {
                    powerMenu.selected = (powerMenu.selected + 1) % powerMenu.actions.length;
                    Event.accepted = true;
                }
                else if (Event.key === Qt.Key_Left || Event.key === Qt.Key_Backtab)
                {
                    powerMenu.selected = (powerMenu.selected - 1 + powerMenu.actions.length) % powerMenu.actions.length;
                    Event.accepted = true;
                }
                else if ((Event.key === Qt.Key_Return || Event.key === Qt.Key_Enter) && powerMenu.selected >= 0)
                {
                    powerMenu.activate(powerMenu.selected);
                    Event.accepted = true;
                }
                else if (Event.key === Qt.Key_Escape)
                {
                    powerMenu.closeMenu();
                    Event.accepted = true;
                }
            }
        }

        // Section: Who's signed in
        // A card with your initials, name, user and computer, and chips for the system, kernel and uptime
        Rectangle
        {
            width: parent.width
            height: 112
            radius: 16
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Rectangle
            {
                id: badge

                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 70
                radius: 35
                color: Theme.pastel
                border.width: 3
                border.color: Theme.panel

                // Thin outer ring, like a photo frame
                Rectangle
                {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 6
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.pastel
                    opacity: 0.6
                }

                Text
                {
                    anchors.centerIn: parent
                    text: powerMenu.initials()
                    color: Theme.pastelText
                    font.family: Theme.font
                    font.pixelSize: 24
                    font.bold: true
                }
            }

            Column
            {
                anchors.left: badge.right
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text
                {
                    width: parent.width
                    elide: Text.ElideRight
                    text: powerMenu.fullName || powerMenu.userName
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 17
                    font.bold: true
                }

                Text
                {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "@" + powerMenu.userName + (powerMenu.hostName ? " on " + powerMenu.hostName : "")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Flow
                {
                    width: parent.width
                    spacing: 6
                    topPadding: 4

                    Repeater
                    {
                        model: [
                            { "icon": "\uf17c", "text": powerMenu.systemName },
                            { "icon": "\uf2db", "text": powerMenu.kernel.split("-")[0] },
                            { "icon": "\uf017", "text": powerMenu.uptimeText }
                        ].filter(Chip => Chip.text !== "")

                        Rectangle
                        {
                            required property var modelData

                            width: chipText.implicitWidth + 16
                            height: 20
                            radius: 6
                            color: Theme.card
                            border.width: 1
                            border.color: Theme.cardBorder

                            Text
                            {
                                id: chipText

                                anchors.centerIn: parent
                                text: parent.modelData.icon + "  " + parent.modelData.text
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        // Section: Buttons
        // Square tiles; the highlighted one fills cream, one waiting for its second click fills red
        Row
        {
            width: parent.width
            spacing: 8

            Repeater
            {
                model: powerMenu.actions

                Rectangle
                {
                    id: actionTile

                    required property var modelData
                    required property int index

                    property bool isArmed: powerMenu.armed === index
                    property bool isSelected: powerMenu.selected === index

                    width: (parent.width - 8 * (powerMenu.actions.length - 1)) / powerMenu.actions.length
                    height: 78
                    radius: 14
                    color: isArmed ? Theme.accent : (isSelected ? Theme.pastel : Theme.card)
                    border.width: 1
                    border.color: isArmed || isSelected ? "transparent" : Theme.cardBorder

                    Behavior on color
                    {
                        ColorAnimation { duration: 140 }
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 15
                        text: actionTile.modelData.icon
                        color: actionTile.isArmed ? Theme.accentText : (actionTile.isSelected ? Theme.pastelText : Theme.text)
                        font.family: Theme.font
                        font.pixelSize: 22
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 50
                        width: parent.width - 6
                        horizontalAlignment: Text.AlignHCenter
                        text: actionTile.isArmed ? "AGAIN" : actionTile.modelData.label.toUpperCase()
                        elide: Text.ElideRight
                        color: actionTile.isArmed ? Theme.accentText : (actionTile.isSelected ? Theme.pastelText : Theme.muted)
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    MouseArea
                    {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: powerMenu.selected = actionTile.index
                        onClicked: powerMenu.activate(actionTile.index)
                    }
                }
            }
        }

        // Section: Confirm hint
        Text
        {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: powerMenu.armed >= 0
                  ? "Click " + powerMenu.actions[powerMenu.armed].label.toLowerCase() + " again to confirm"
                  : "Arrow keys and Enter · Esc to close"
            color: powerMenu.armed >= 0 ? Theme.accentHover : Theme.muted
            opacity: powerMenu.armed >= 0 ? 1 : 0.7
            font.family: Theme.font
            font.pixelSize: 10
        }
    }
}
