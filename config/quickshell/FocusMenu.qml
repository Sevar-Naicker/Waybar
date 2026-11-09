// This file contains the focus timer menu: a ring counting down, start/pause, skip and reset, the three lengths, and today's total
// The timer itself lives in ShellState, so it keeps running (and the island keeps counting) after this menu closes

import Quickshell
import QtQuick

// Section: Focus menu
MenuWindow
{
    id: focusMenu

    side: "centre"
    panelWidth: 430

    // Section: State
    // Breaks get the success colour, focus gets the accent
    property bool onBreak: ShellState.focusPhase === "short" || ShellState.focusPhase === "long"
    property color ringColour: onBreak ? Theme.success : Theme.pastel

    // How much of the ring is left (glides between the once-a-second updates)
    property real share: ShellState.focusTotal > 0 ? ShellState.focusLeft / ShellState.focusTotal : 1

    Behavior on share
    {
        NumberAnimation { duration: 1000 }
    }

    onShareChanged: ring.requestPaint()
    onRingColourChanged: ring.requestPaint()

    // The keyboard goes to the menu while it's open
    onShownChanged:
    {
        if (shown)
        {
            keys.forceActiveFocus();
        }
    }

    // Section: Functions

    // The phaseName function says what the timer is doing, for the chip at the top
    function phaseName()
    {
        if (ShellState.focusPhase === "focus")
        {
            return (ShellState.focusRunning ? "FOCUSING" : "PAUSED") + " · ROUND " + (ShellState.focusRound + 1) + " OF " + ShellState.focusRoundsPerSet;
        }

        if (onBreak)
        {
            return (ShellState.focusPhase === "long" ? "LONG BREAK" : "BREAK") + (ShellState.focusRunning ? "" : " · PAUSED");
        }

        return "READY · ROUND " + (ShellState.focusRound + 1) + " OF " + ShellState.focusRoundsPerSet;
    }

    // The underTime function is the line under the countdown
    function underTime()
    {
        if (ShellState.focusPhase === "focus")
        {
            return "until your break";
        }

        if (onBreak)
        {
            return "until the next round";
        }

        return "press play to start";
    }

    // The todayText function shows today's focus time, like "1 h 15 m · 3 rounds"
    function todayText()
    {
        const Minutes = Math.floor(ShellState.focusTodaySeconds / 60);
        const Time = Minutes >= 60 ? Math.floor(Minutes / 60) + " h " + (Minutes % 60) + " m" : Minutes + " m";
        const Rounds = ShellState.focusTodayRounds;
        return Time + " · " + Rounds + (Rounds === 1 ? " round" : " rounds");
    }

    // Section: Keys
    // Space starts or pauses, S skips, R resets
    Item
    {
        id: keys

        focus: true

        Keys.onPressed: (Event) =>
        {
            if (Event.key === Qt.Key_Space)
            {
                ShellState.focusToggle();
                Event.accepted = true;
            }
            else if (Event.key === Qt.Key_S)
            {
                ShellState.focusSkip();
                Event.accepted = true;
            }
            else if (Event.key === Qt.Key_R)
            {
                ShellState.focusReset();
                Event.accepted = true;
            }
            else if (Event.key === Qt.Key_Escape)
            {
                focusMenu.closeMenu();
                Event.accepted = true;
            }
        }
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 16

        // Section: Heading
        Item
        {
            width: parent.width
            height: 22

            Text
            {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 4
                text: "FOCUS TIME"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
            }

            Rectangle
            {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: phaseText.implicitWidth + 18
                height: 22
                radius: 7
                color: ShellState.focusRunning ? focusMenu.ringColour : Theme.card
                border.width: 1
                border.color: ShellState.focusRunning ? "transparent" : Theme.cardBorder

                Behavior on color
                {
                    ColorAnimation { duration: 200 }
                }

                Text
                {
                    id: phaseText

                    anchors.centerIn: parent
                    text: focusMenu.phaseName()
                    color: ShellState.focusRunning ? Theme.pastelText : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }

        // Section: Ring
        Item
        {
            width: parent.width
            height: 236

            Canvas
            {
                id: ring

                anchors.centerIn: parent
                width: 228
                height: 228

                onPaint:
                {
                    const Context = getContext("2d");
                    const Middle = width / 2;
                    const Radius = Middle - 16;
                    const Top = -Math.PI / 2;

                    Context.reset();

                    // Sixty ticks round the outside, like a watch face
                    for (let Tick = 0; Tick < 60; Tick++)
                    {
                        const Angle = Top + Tick / 60 * 2 * Math.PI;
                        const Long = Tick % 5 === 0;
                        const Inner = Middle - (Long ? 7 : 4);
                        Context.strokeStyle = Long ? Theme.muted : Theme.cardBorder;
                        Context.lineWidth = Long ? 2 : 1;
                        Context.beginPath();
                        Context.moveTo(Middle + Math.cos(Angle) * Inner, Middle + Math.sin(Angle) * Inner);
                        Context.lineTo(Middle + Math.cos(Angle) * (Middle - 1), Middle + Math.sin(Angle) * (Middle - 1));
                        Context.stroke();
                    }

                    // The track, then what's left of this phase
                    Context.lineWidth = 10;
                    Context.lineCap = "round";
                    Context.strokeStyle = Theme.cardHover;
                    Context.beginPath();
                    Context.arc(Middle, Middle, Radius, 0, 2 * Math.PI);
                    Context.stroke();

                    if (focusMenu.share > 0.002)
                    {
                        Context.strokeStyle = focusMenu.ringColour;
                        Context.beginPath();
                        Context.arc(Middle, Middle, Radius, Top, Top + focusMenu.share * 2 * Math.PI);
                        Context.stroke();
                    }
                }

                Connections
                {
                    target: Theme

                    function onCardHoverChanged()
                    {
                        ring.requestPaint();
                    }

                    function onMutedChanged()
                    {
                        ring.requestPaint();
                    }
                }
            }

            // Countdown, what it's counting to, and the four rounds as dots
            Column
            {
                anchors.centerIn: parent
                spacing: 6

                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ShellState.focusClock()
                    color: Theme.text
                    opacity: ShellState.focusRunning || ShellState.focusPhase === "idle" ? 1 : 0.55
                    font.family: Theme.font
                    font.pixelSize: 44
                    font.bold: true

                    Behavior on opacity
                    {
                        NumberAnimation { duration: 200 }
                    }
                }

                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: focusMenu.underTime()
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Row
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6
                    spacing: 7

                    Repeater
                    {
                        model: ShellState.focusRoundsPerSet

                        Rectangle
                        {
                            required property int index

                            property bool done: index < ShellState.focusRound
                            property bool current: index === ShellState.focusRound && ShellState.focusPhase === "focus"

                            width: 8
                            height: 8
                            radius: 4
                            color: done ? Theme.pastel : "transparent"
                            border.width: 1.5
                            border.color: done || current ? Theme.pastel : Theme.cardBorder
                        }
                    }
                }
            }
        }

        // Section: Controls
        // Reset, start or pause, skip
        Row
        {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 30

            Repeater
            {
                model: [
                    { "name": "reset", "icon": "", "tip": "Reset (R)" },
                    { "name": "toggle", "icon": "", "tip": "" },
                    { "name": "skip", "icon": "", "tip": "Skip (S)" }
                ]

                Rectangle
                {
                    id: controlButton

                    required property var modelData

                    property bool main: modelData.name === "toggle"
                    property bool usable: main || ShellState.focusPhase !== "idle" || (modelData.name === "reset" && ShellState.focusRound > 0)

                    anchors.verticalCenter: parent.verticalCenter
                    width: main ? 56 : 40
                    height: width
                    radius: width / 2
                    color: main ? (controlHover.containsMouse ? Theme.text : focusMenu.ringColour) : (controlHover.containsMouse && usable ? Theme.cardHover : Theme.card)
                    border.width: main ? 0 : 1
                    border.color: Theme.cardBorder
                    opacity: usable ? 1 : 0.4

                    Behavior on color
                    {
                        ColorAnimation { duration: 120 }
                    }

                    Text
                    {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: controlButton.main && !ShellState.focusRunning ? 2 : 0
                        text: controlButton.main ? (ShellState.focusRunning ? "" : "") : controlButton.modelData.icon
                        color: controlButton.main ? Theme.pastelText : Theme.text
                        font.family: Theme.font
                        font.pixelSize: controlButton.main ? 18 : 13
                    }

                    MouseArea
                    {
                        id: controlHover

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: controlButton.usable
                        cursorShape: Qt.PointingHandCursor
                        onClicked:
                        {
                            if (controlButton.modelData.name === "reset")
                            {
                                ShellState.focusReset();
                            }
                            else if (controlButton.modelData.name === "skip")
                            {
                                ShellState.focusSkip();
                            }
                            else
                            {
                                ShellState.focusToggle();
                            }
                        }
                    }
                }
            }
        }

        // Section: Lengths
        // Focus, break and long break: click - or +, or scroll over a card
        Row
        {
            width: parent.width
            spacing: 8

            Repeater
            {
                model: [
                    { "name": "focus", "label": "FOCUS", "low": 5, "high": 90, "step": 5 },
                    { "name": "short", "label": "BREAK", "low": 1, "high": 30, "step": 1 },
                    { "name": "long", "label": "LONG BREAK", "low": 5, "high": 60, "step": 5 }
                ]

                Rectangle
                {
                    id: lengthCard

                    required property var modelData

                    property int value: modelData.name === "focus" ? ShellState.focusMinutes : (modelData.name === "long" ? ShellState.longMinutes : ShellState.breakMinutes)

                    // The change function moves the length up or down a step and saves it
                    function change(Steps)
                    {
                        const Next = Math.max(modelData.low, Math.min(modelData.high, value + Steps * modelData.step));

                        if (modelData.name === "focus")
                        {
                            ShellState.focusMinutes = Next;
                        }
                        else if (modelData.name === "long")
                        {
                            ShellState.longMinutes = Next;
                        }
                        else
                        {
                            ShellState.breakMinutes = Next;
                        }

                        ShellState.saveFocus();
                    }

                    width: (parent.width - 16) / 3
                    height: 66
                    radius: 12
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.cardBorder

                    MouseArea
                    {
                        anchors.fill: parent
                        onWheel: (Wheel) => lengthCard.change(Wheel.angleDelta.y > 0 ? 1 : -1)
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        text: lengthCard.modelData.label
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    Row
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        spacing: 8

                        Repeater
                        {
                            model: [-1, 0, 1]

                            Item
                            {
                                required property int modelData

                                width: modelData === 0 ? minutesText.implicitWidth : 20
                                height: 22

                                // The minutes in the middle
                                Text
                                {
                                    id: minutesText

                                    anchors.centerIn: parent
                                    visible: parent.modelData === 0
                                    text: lengthCard.value + " min"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                // - and + either side
                                Rectangle
                                {
                                    anchors.fill: parent
                                    visible: parent.modelData !== 0
                                    radius: 6
                                    color: stepHover.containsMouse ? Theme.cardHover : "transparent"

                                    Text
                                    {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData < 0 ? "−" : "+"
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                    }

                                    MouseArea
                                    {
                                        id: stepHover

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: lengthCard.change(parent.parent.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Section: Silence switch
        // Holds notifications back while a focus round runs
        Rectangle
        {
            width: parent.width
            height: 44
            radius: 12
            color: silenceHover.containsMouse ? Theme.cardHover : Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Behavior on color
            {
                ColorAnimation { duration: 120 }
            }

            Text
            {
                id: silenceIcon

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: ShellState.focusSilence ? Theme.pastel : Theme.muted
                font.family: Theme.font
                font.pixelSize: 13
            }

            Text
            {
                anchors.left: silenceIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Silence notifications while focusing"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
            }

            // The switch
            Rectangle
            {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 20
                radius: 10
                color: ShellState.focusSilence ? Theme.pastel : Theme.cardHover

                Behavior on color
                {
                    ColorAnimation { duration: 150 }
                }

                Rectangle
                {
                    x: ShellState.focusSilence ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: ShellState.focusSilence ? Theme.pastelText : Theme.muted

                    Behavior on x
                    {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea
            {
                id: silenceHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked:
                {
                    ShellState.focusSilence = !ShellState.focusSilence;
                    ShellState.saveFocus();
                }
            }
        }

        // Section: Today
        Item
        {
            width: parent.width
            height: 16

            Text
            {
                leftPadding: 4
                text: "TODAY"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
            }

            Text
            {
                anchors.right: parent.right
                rightPadding: 4
                text: focusMenu.todayText()
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }
}
