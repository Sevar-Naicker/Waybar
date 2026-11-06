#!/usr/bin/env python3
# This file contains the weather feed for the calendar menu
# Prints one line of JSON now and every 30 minutes: current conditions, the next few hours, and three days of 3-hour slots
# The location comes from SHRINE_WEATHER_LOCATION in shrine.conf; empty means wttr.in works it out from your connection

import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

# Section: Settings
RefreshSeconds = 1800
RetrySeconds = 300
TimeoutSeconds = 15
HourSlots = 5

# Section: Icons
# Nerd Font weather glyphs
Icons = {
    "sunny": "", "clear_night": "", "partly": "", "partly_night": "",
    "cloudy": "", "fog": "", "showers": "", "rain": "",
    "snow": "", "thunder": "",
}

# wttr.in weather codes grouped by look
CodeGroups = {
    "sunny": {113},
    "partly": {116},
    "cloudy": {119, 122},
    "fog": {143, 248, 260},
    "showers": {176, 263, 266, 293, 296, 353},
    "rain": {299, 302, 305, 308, 356, 359, 179, 182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377},
    "snow": {227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 392, 395},
    "thunder": {200, 386, 389},
}


# The read_location function asks settings.sh for SHRINE_WEATHER_LOCATION
def read_location():
    Settings = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "shrine-waybar" / "settings.sh"

    try:
        return subprocess.run(["bash", str(Settings), "--get", "SHRINE_WEATHER_LOCATION"],
                              capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


# The fetch function downloads the full forecast as JSON
def fetch(Location):
    Url = "https://wttr.in/" + urllib.parse.quote(Location) + "?format=j1"
    Request = urllib.request.Request(Url, headers={"User-Agent": "curl/8"})

    with urllib.request.urlopen(Request, timeout=TimeoutSeconds) as Response:
        return json.load(Response)


# The parse_clock function turns "05:14 AM" into a time, or None
def parse_clock(Text):
    try:
        return datetime.strptime(Text.strip(), "%I:%M %p").time()
    except (ValueError, AttributeError):
        return None


# The is_night function says whether a moment falls outside sunrise to sunset
def is_night(Moment, Astronomy):
    Sunrise = parse_clock(Astronomy.get("sunrise", ""))
    Sunset = parse_clock(Astronomy.get("sunset", ""))

    if Sunrise is None or Sunset is None:
        return Moment.hour < 6 or Moment.hour >= 18

    return Moment.time() < Sunrise or Moment.time() > Sunset


# The pick_icon function chooses a glyph for a weather code, with night versions where they matter
def pick_icon(Code, Night):
    if Code in CodeGroups["sunny"]:
        return Icons["clear_night"] if Night else Icons["sunny"]

    if Code in CodeGroups["partly"]:
        return Icons["partly_night"] if Night else Icons["partly"]

    for Group in ("cloudy", "fog", "showers", "rain", "snow", "thunder"):
        if Code in CodeGroups[Group]:
            return Icons[Group]

    return Icons["cloudy"]


# The build function turns the forecast into what the card shows
def build(Data, Now):
    Current = Data["current_condition"][0]
    Days = Data["weather"]
    Today = Days[0]
    Area = (Data.get("nearest_area") or [{}])[0]
    Place = ((Area.get("areaName") or [{}])[0]).get("value", "")

    # Every 3-hour forecast slot from today on, as (time, slot, day)
    Slots = []

    for Offset, Day in enumerate(Days):
        Date = Now.date() + timedelta(days=Offset)

        for Hour in Day.get("hourly", []):
            HourValue = int(Hour.get("time", "0")) // 100
            Slots.append((datetime.combine(Date, datetime.min.time()) + timedelta(hours=HourValue), Hour, Day))

    # The next few slots after now
    Upcoming = [Slot for Slot in Slots if Slot[0] > Now][:HourSlots]

    Hours = []

    for Moment, Hour, Day in Upcoming:
        Night = is_night(Moment, (Day.get("astronomy") or [{}])[0])
        Hours.append({
            "time": Moment.strftime("%H:%M"),
            "temp": int(Hour.get("tempC", 0)),
            "icon": pick_icon(int(Hour.get("weatherCode", 119)), Night),
        })

    # Three days, each with its eight 3-hour slots (midnight to 9pm) for the calendar's forecast ring
    DayList = []

    for Offset, Day in enumerate(Days[:3]):
        Date = Now.date() + timedelta(days=Offset)
        Astronomy = (Day.get("astronomy") or [{}])[0]
        Slots3 = []

        for Hour in Day.get("hourly", []):
            Moment = datetime.combine(Date, datetime.min.time()) + timedelta(hours=int(Hour.get("time", "0")) // 100)
            Slots3.append({
                "time": Moment.strftime("%H:%M"),
                "temp": int(Hour.get("tempC", 0)),
                "icon": pick_icon(int(Hour.get("weatherCode", 119)), is_night(Moment, Astronomy)),
                "rain": int(Hour.get("chanceofrain", 0)),
                "wind": int(Hour.get("windspeedKmph", 0)),
                "humidity": int(Hour.get("humidity", 0)),
                "feelsLike": int(Hour.get("FeelsLikeC", Hour.get("tempC", 0))),
                "description": ((Hour.get("weatherDesc") or [{}])[0]).get("value", "").strip(),
            })

        # The day's look comes from its midday slot
        Midday = Slots3[len(Slots3) // 2] if Slots3 else {"icon": Icons["cloudy"], "description": ""}

        DayList.append({
            "name": "Today" if Offset == 0 else Date.strftime("%A"),
            "high": int(Day.get("maxtempC", 0)),
            "low": int(Day.get("mintempC", 0)),
            "icon": Midday["icon"],
            "description": Midday["description"],
            "rainChance": max((Slot["rain"] for Slot in Slots3), default=0),
            "hours": Slots3,
        })

    Night = is_night(Now, (Today.get("astronomy") or [{}])[0])
    RainChance = max((int(Hour.get("chanceofrain", 0)) for Hour in Today.get("hourly", [])), default=0)

    return {
        "ok": True,
        "place": Place,
        "temp": int(Current["temp_C"]),
        "feelsLike": int(Current["FeelsLikeC"]),
        "description": Current["weatherDesc"][0]["value"].strip(),
        "icon": pick_icon(int(Current["weatherCode"]), Night),
        "high": int(Today["maxtempC"]),
        "low": int(Today["mintempC"]),
        "rainChance": RainChance,
        "wind": int(Current.get("windspeedKmph", 0)),
        "humidity": int(Current.get("humidity", 0)),
        "hours": Hours,
        "days": DayList,
    }


# The main function prints the weather now and every 30 minutes, retrying sooner when it can't connect
def main():
    while True:
        try:
            Output = build(fetch(read_location()), datetime.now())
            Wait = RefreshSeconds
        except Exception:
            Output = {"ok": False}
            Wait = RetrySeconds

        print(json.dumps(Output, ensure_ascii=False), flush=True)
        time.sleep(Wait)


if __name__ == "__main__":
    main()
