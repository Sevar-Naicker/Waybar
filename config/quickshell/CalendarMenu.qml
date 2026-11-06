// This file contains the calendar menu that drops down from the island's clock
// Month on the left, a big clock in the middle with the forecast revolving round it, and the weather for the slot at the front on the right

import Quickshell
import Quickshell.Io
import QtQuick

// Section: Calendar menu
MenuWindow
{
    id: calendarMenu

    side: "centre"
    panelWidth: 980

    // Section: State
    // The time, ticking every second while the menu is open
    property date now: new Date()

    // Months away from this one (‹ › in the month card, or scrolling over it)
    property int monthOffset: 0
    property date shownMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    // Blank days before the 1st (weeks start on Monday), and the month's length
    property int leadingDays: (shownMonth.getDay() + 6) % 7
    property int daysInMonth: new Date(shownMonth.getFullYear(), shownMonth.getMonth() + 1, 0).getDate()
    property int daysInLastMonth: new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 0).getDate()

    // What weather.py last printed; {"ok": false} until it answers
    property var forecast: ({ "ok": false })

    // Which day the weather side shows (0 today, 1 tomorrow, 2 the day after)
    property int dayIndex: 0
    property var shownDay: forecast.ok && forecast.days && forecast.days.length > dayIndex ? forecast.days[dayIndex] : null
    property var slots: shownDay ? shownDay.hours : []

    // The forecast ring: ringIndex counts whole steps (it can keep going round), ringPosition follows it smoothly
    property int ringIndex: 0
    property real ringPosition: 0
    property int slotCount: Math.max(slots.length, 1)
    property int frontSlot: ((ringIndex % slotCount) + slotCount) % slotCount
    property var frontData: slots.length > frontSlot ? slots[frontSlot] : null

    Behavior on ringPosition
    {
        id: ringBehavior
        NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
    }

    // The turnRing function moves the ring a number of slots (positive turns it forward in time)
    function turnRing(Steps)
    {
        ringIndex += Steps;
        ringPosition = ringIndex;
    }

    // The userTurn function is turnRing for scrolls, keys and clicks: it also pauses the ring's own turning for a while
    function userTurn(Steps)
    {
        turnRing(Steps);
        autoPause.restart();
    }

    // The bringToFront function turns the ring the short way round until a slot is at the front
    function bringToFront(Slot)
    {
        let Steps = Slot - frontSlot;

        if (Steps > slotCount / 2)
        {
            Steps -= slotCount;
        }

        if (Steps < -slotCount / 2)
        {
            Steps += slotCount;
        }

        userTurn(Steps);
    }

    // The dialInfo function gives one weather dial's label and reading for the slot at the front of the ring
    function dialInfo(Name)
    {
        const Slot = frontData || { "wind": 0, "humidity": 0, "rain": 0, "feelsLike": 0 };

        if (Name === "wind")
        {
            return { "label": "\uef16 WIND", "value": Slot.wind, "suffix": "", "unit": "km/h", "fill": Slot.wind / 60 };
        }

        if (Name === "humidity")
        {
            return { "label": "\ue373 HUMID", "value": Slot.humidity, "suffix": "%", "unit": "", "fill": Slot.humidity / 100 };
        }

        if (Name === "rain")
        {
            return { "label": "\ue371 RAIN", "value": Slot.rain, "suffix": "%", "unit": "", "fill": Slot.rain / 100 };
        }

        return { "label": "\uf2c9 FEELS", "value": Slot.feelsLike, "suffix": "°", "unit": "", "fill": Math.max(0, Slot.feelsLike) / 40 };
    }

    // The startSlot function picks which slot goes to the front for a day: the current one today, midday otherwise
    function startSlot()
    {
        if (dayIndex === 0)
        {
            return Math.min(Math.floor(now.getHours() / 3), slotCount - 1);
        }

        return Math.floor(slotCount / 2);
    }

    // The spinIn function puts the right slot at the front with one full revolution, so the ring sweeps round as it appears
    function spinIn()
    {
        const Target = startSlot();

        ringBehavior.enabled = false;
        ringIndex = Target;
        ringPosition = Target - slotCount;
        ringBehavior.enabled = true;
        ringPosition = Target;
    }

    // The changeDay function switches the weather side to another day and spins its forecast in
    function changeDay(Step)
    {
        const Last = forecast.days ? forecast.days.length - 1 : 0;
        dayIndex = Math.max(0, Math.min(Last, dayIndex + Step));
        spinIn();
    }

    // Every time it opens: this month, today's weather, the ring spinning in
    Connections
    {
        target: calendarMenu

        function onShownChanged()
        {
            if (calendarMenu.shown)
            {
                calendarMenu.now = new Date();
                calendarMenu.monthOffset = 0;
                calendarMenu.dayIndex = 0;
                calendarMenu.spinIn();
            }
        }
    }

    // Section: Turning by itself
    // While open, the ring moves on one slot every few seconds; touching it pauses that for 10 seconds
    Timer
    {
        interval: 3500
        running: calendarMenu.shown && !autoPause.running && calendarMenu.slots.length > 1
        repeat: true
        onTriggered: calendarMenu.turnRing(1)
    }

    Timer
    {
        id: autoPause
        interval: 10000
    }

    // Section: Sources
    Timer
    {
        interval: 1000
        running: calendarMenu.shown
        repeat: true
        onTriggered: calendarMenu.now = new Date()
    }

    // weather.py prints the forecast now and every 30 minutes
    Process
    {
        command: ["sh", "-c", "exec python3 \"$HOME/.config/quickshell/weather.py\""]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    calendarMenu.forecast = JSON.parse(Line);
                }
                catch (Problem)
                {
                }
            }
        }
    }

    // Section: Keys
    // Left and right turn the ring, up and down change the month
    Item
    {
        focus: calendarMenu.shown

        Keys.onLeftPressed: calendarMenu.userTurn(-1)
        Keys.onRightPressed: calendarMenu.userTurn(1)
        Keys.onUpPressed: calendarMenu.monthOffset -= 1
        Keys.onDownPressed: calendarMenu.monthOffset += 1
    }

    // Section: Layout
    Item
    {
        width: parent.width
        height: 300

        // Section: Month
        Rectangle
        {
            id: monthCard

            width: 268
            height: parent.height
            radius: 16
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            // Scrolling over the month changes it
            WheelHandler
            {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (Wheel) => calendarMenu.monthOffset += Wheel.angleDelta.y > 0 ? -1 : 1
            }

            Column
            {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                // Month name between its arrows; clicking the name goes back to this month
                Item
                {
                    width: parent.width
                    height: 24

                    Repeater
                    {
                        model: [{ "icon": "", "step": -1 }, { "icon": "", "step": 1 }]

                        Text
                        {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            x: modelData.step < 0 ? 4 : parent.width - width - 4
                            text: modelData.icon
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarMenu.monthOffset += parent.modelData.step
                            }
                        }
                    }

                    Text
                    {
                        anchors.centerIn: parent
                        text: Qt.formatDate(calendarMenu.shownMonth, "MMMM yyyy").toUpperCase()
                        color: calendarMenu.monthOffset === 0 ? Theme.text : Theme.accentHover
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 1

                        MouseArea
                        {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarMenu.monthOffset = 0
                        }
                    }
                }

                Grid
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7

                    // Day names
                    Repeater
                    {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Text
                        {
                            required property var modelData
                            required property int index

                            width: 34
                            height: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: index >= 5 ? Theme.accentHover : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    // Six weeks, with the ends of the months either side faded
                    Repeater
                    {
                        model: 42

                        Item
                        {
                            id: dayCell

                            required property int index

                            property int dayNumber: index - calendarMenu.leadingDays + 1
                            property bool inMonth: dayNumber >= 1 && dayNumber <= calendarMenu.daysInMonth
                            property bool isToday: inMonth && calendarMenu.monthOffset === 0 && dayNumber === calendarMenu.now.getDate()

                            width: 34
                            height: 34

                            Rectangle
                            {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 9
                                color: dayCell.isToday ? Theme.accent : "transparent"
                            }

                            Text
                            {
                                anchors.centerIn: parent
                                text:
                                {
                                    if (dayCell.dayNumber < 1)
                                    {
                                        return calendarMenu.daysInLastMonth + dayCell.dayNumber;
                                    }

                                    if (dayCell.dayNumber > calendarMenu.daysInMonth)
                                    {
                                        return dayCell.dayNumber - calendarMenu.daysInMonth;
                                    }

                                    return dayCell.dayNumber;
                                }
                                color: dayCell.isToday ? Theme.accentText : Theme.text
                                opacity: dayCell.inMonth ? 1 : 0.25
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: dayCell.isToday
                            }
                        }
                    }
                }
            }
        }

        // Section: Clock and forecast ring
        Item
        {
            id: ringArea

            // Size and centre of the ring's oval
            property real radiusX: 168
            property real radiusY: 96
            property real centreX: width / 2
            property real centreY: height / 2 - 4

            anchors.left: monthCard.right
            anchors.right: weatherSide.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: parent.height

            // Scrolling here turns the ring
            WheelHandler
            {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (Wheel) => calendarMenu.userTurn(Wheel.angleDelta.y > 0 ? -1 : 1)
            }

            // The dashed oval the forecast rides on
            Canvas
            {
                id: orbit

                anchors.fill: parent
                opacity: 0.45

                onPaint:
                {
                    const Context = getContext("2d");
                    Context.reset();
                    Context.strokeStyle = Theme.muted;
                    Context.lineWidth = 1.5;
                    Context.setLineDash([4, 6]);
                    Context.beginPath();
                    Context.ellipse(ringArea.centreX - ringArea.radiusX, ringArea.centreY - ringArea.radiusY, ringArea.radiusX * 2, ringArea.radiusY * 2);
                    Context.stroke();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Big time with small seconds, and the date under it
            Column
            {
                anchors.horizontalCenter: parent.horizontalCenter
                y: ringArea.centreY - 62
                z: 1

                Row
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text
                    {
                        id: bigTime

                        text: Qt.formatDateTime(calendarMenu.now, "HH:mm")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 64
                        font.bold: true
                    }

                    Text
                    {
                        anchors.baseline: bigTime.baseline
                        text: Qt.formatDateTime(calendarMenu.now, ":ss")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 22
                    }
                }

                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(calendarMenu.now, "dddd, d MMMM")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            // The forecast pills, spaced evenly round the oval; the one at the bottom is the front one
            Repeater
            {
                model: calendarMenu.slots

                Rectangle
                {
                    id: pill

                    required property var modelData
                    required property int index

                    // Where this pill is on the oval: the front slot sits at the bottom (90°)
                    property real angle: Math.PI / 2 + (index - calendarMenu.ringPosition) * 2 * Math.PI / calendarMenu.slotCount
                    // 1 at the front, 0 at the back
                    property real depth: (Math.sin(angle) + 1) / 2
                    property bool atFront: index === calendarMenu.frontSlot

                    width: 62
                    height: 88
                    radius: 31
                    x: ringArea.centreX + ringArea.radiusX * Math.cos(angle) - width / 2
                    y: ringArea.centreY + ringArea.radiusY * Math.sin(angle) - height / 2
                    z: 2 + depth
                    scale: 0.5 + 0.5 * depth
                    opacity: 0.55 + 0.45 * depth
                    color: atFront ? Theme.pastel : Theme.panel
                    border.width: atFront ? 0 : 1
                    border.color: Theme.edge

                    Behavior on color
                    {
                        ColorAnimation { duration: 200 }
                    }

                    Column
                    {
                        anchors.centerIn: parent
                        spacing: 3

                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pill.modelData.time
                            color: pill.atFront ? Theme.pastelText : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pill.modelData.icon
                            color: pill.atFront ? Theme.accent : Theme.accentHover
                            font.family: Theme.font
                            font.pixelSize: 20
                        }

                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pill.modelData.temp + "°"
                            color: pill.atFront ? Theme.pastelText : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    // Clicking a pill turns it to the front
                    MouseArea
                    {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarMenu.bringToFront(pill.index)
                    }
                }
            }
        }

        // Section: Weather
        Item
        {
            id: weatherSide

            anchors.right: parent.right
            width: 268
            height: parent.height

            // Day name between arrows to step through the three days
            Item
            {
                id: dayHeader

                width: parent.width
                height: 24

                Repeater
                {
                    model: [{ "icon": "", "step": -1 }, { "icon": "", "step": 1 }]

                    Text
                    {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        x: modelData.step < 0 ? 18 : parent.width - width - 18
                        text: modelData.icon
                        color: Theme.muted
                        opacity: (modelData.step < 0 && calendarMenu.dayIndex === 0) || (modelData.step > 0 && (!calendarMenu.forecast.days || calendarMenu.dayIndex >= calendarMenu.forecast.days.length - 1)) ? 0.25 : 1
                        font.family: Theme.font
                        font.pixelSize: 11

                        MouseArea
                        {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarMenu.changeDay(parent.modelData.step)
                        }
                    }
                }

                Text
                {
                    anchors.centerIn: parent
                    text: calendarMenu.shownDay ? calendarMenu.shownDay.name.toUpperCase() : "WEATHER"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1
                }
            }

            // Big temperature: now for today, the high for other days
            Column
            {
                anchors.top: dayHeader.bottom
                anchors.topMargin: 18
                anchors.right: parent.right
                anchors.rightMargin: 18
                spacing: 2
                visible: calendarMenu.shownDay !== null

                Row
                {
                    anchors.right: parent.right
                    spacing: 10

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: calendarMenu.dayIndex === 0 ? (calendarMenu.forecast.icon || "") : (calendarMenu.shownDay ? calendarMenu.shownDay.icon : "")
                        color: Theme.accentHover
                        font.family: Theme.font
                        font.pixelSize: 34
                    }

                    Text
                    {
                        text: (calendarMenu.dayIndex === 0 ? calendarMenu.forecast.temp : (calendarMenu.shownDay ? calendarMenu.shownDay.high : "")) + "°"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 56
                        font.bold: true
                    }
                }

                Text
                {
                    anchors.right: parent.right
                    width: 232
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: (calendarMenu.dayIndex === 0 ? calendarMenu.forecast.description : (calendarMenu.shownDay ? calendarMenu.shownDay.description : ""))
                          + (calendarMenu.forecast.place ? " · " + calendarMenu.forecast.place : "")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text
                {
                    anchors.right: parent.right
                    text: calendarMenu.shownDay ? "H " + calendarMenu.shownDay.high + "°  L " + calendarMenu.shownDay.low + "°" : ""
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Text
            {
                anchors.centerIn: parent
                visible: calendarMenu.shownDay === null
                horizontalAlignment: Text.AlignHCenter
                text: "\nWeather unavailable right now"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
                lineHeight: 1.6
            }

            // Section: Dials
            // Wind, humidity, rain and feels-like for whichever slot is at the front of the ring
            Text
            {
                anchors.bottom: dialRow.top
                anchors.bottomMargin: 8
                anchors.horizontalCenter: dialRow.horizontalCenter
                visible: calendarMenu.frontData !== null
                text: calendarMenu.frontData ? "At " + calendarMenu.frontData.time : ""
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }

            Row
            {
                id: dialRow

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                visible: calendarMenu.frontData !== null

                // The four dials stay put and slide to each slot's numbers as the ring turns
                Repeater
                {
                    model: ["wind", "humidity", "rain", "feels"]

                    Column
                    {
                        id: dial

                        required property var modelData

                        // This dial's label and reading for the slot at the front
                        property var info: calendarMenu.dialInfo(modelData)

                        // The number on screen, sliding to each new reading
                        property real shownValue: info.value

                        Behavior on shownValue
                        {
                            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                        }

                        spacing: 6

                        Item
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52

                            // Ring that fills clockwise from the top
                            Canvas
                            {
                                id: dialCanvas

                                property real fill: Math.max(0, Math.min(1, dial.info.fill))

                                Behavior on fill
                                {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }

                                anchors.fill: parent

                                onFillChanged: requestPaint()

                                onPaint:
                                {
                                    const Context = getContext("2d");
                                    const Middle = width / 2;
                                    Context.reset();
                                    Context.lineWidth = 4;
                                    Context.lineCap = "round";

                                    Context.strokeStyle = Theme.cardHover;
                                    Context.beginPath();
                                    Context.arc(Middle, Middle, Middle - 3, 0, 2 * Math.PI);
                                    Context.stroke();

                                    if (fill > 0)
                                    {
                                        Context.strokeStyle = Theme.pastel;
                                        Context.beginPath();
                                        Context.arc(Middle, Middle, Middle - 3, -Math.PI / 2, -Math.PI / 2 + fill * 2 * Math.PI);
                                        Context.stroke();
                                    }
                                }
                            }

                            Column
                            {
                                anchors.centerIn: parent

                                Text
                                {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(dial.shownValue) + dial.info.suffix
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text
                                {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: dial.info.unit !== ""
                                    text: dial.info.unit
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
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
                        }
                    }
                }
            }
        }
    }
}
