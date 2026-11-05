#!/usr/bin/env python3
# This file contains the Waybar media module: it prints the current track as JSON using playerctl

import json
import subprocess


# The Get_Player_Value function returns one playerctl value, such as the status or a metadata field
def Get_Player_Value(Args):
    return subprocess.check_output(["playerctl", *Args], text=True, stderr=subprocess.DEVNULL).strip()


# The Main function prints the track text and a CSS class Waybar uses to style or hide the pill
def Main():
    try:
        Status = Get_Player_Value(["status"])
        Title = Get_Player_Value(["metadata", "title"])
        Artist = Get_Player_Value(["metadata", "artist"])
        print(json.dumps({"text": f"{Title} - {Artist}", "class": Status.lower(), "alt": Status.lower()}))
    except (subprocess.CalledProcessError, FileNotFoundError):
        # No player running, or playerctl isn't installed
        print(json.dumps({"text": "", "class": "none", "alt": "none"}))


if __name__ == "__main__":
    Main()
