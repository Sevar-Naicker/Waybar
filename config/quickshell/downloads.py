#!/usr/bin/env python3
# This file contains the downloads feed for the dynamic island
# Prints one JSON line every second: download speed, in-progress files, recent files and any new arrival

import json
import os
import subprocess
import time
from pathlib import Path


# The read_setting function asks Shrine Waybar's settings.sh for one setting, with a fallback if it can't
def read_setting(Key, Fallback):
    Settings = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "shrine-waybar" / "settings.sh"

    try:
        Value = subprocess.run(["bash", str(Settings), "--get", Key], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        Value = ""

    return Path(Value) if Value else Fallback


# Section: Settings
# Both folders come from shrine.conf (SHRINE_DOWNLOADS_DIR and SHRINE_SCREENSHOTS_DIR)
Home = Path.home()
DownloadsFolder = read_setting("SHRINE_DOWNLOADS_DIR", Home / "Downloads")
ScreenshotsFolder = read_setting("SHRINE_SCREENSHOTS_DIR", Home / "Pictures" / "Screenshots")
WatchedFolders = [DownloadsFolder, ScreenshotsFolder]
PartialSuffixes = (".part", ".crdownload", ".download")
ImageSuffixes = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}
RecentCount = 5


# The read_received_bytes function adds up bytes received on every network interface except loopback
def read_received_bytes():
    Total = 0

    with open("/proc/net/dev") as NetFile:
        for Line in NetFile.readlines()[2:]:
            Interface, Data = Line.split(":", 1)

            if Interface.strip() == "lo":
                continue

            Total += int(Data.split()[0])

    return Total


# The scan_files function lists every file in the watched folders, newest first
def scan_files():
    Files = []

    for Folder in WatchedFolders:
        if not Folder.is_dir():
            continue

        for Entry in Folder.iterdir():
            try:
                if not Entry.is_file():
                    continue

                Info = Entry.stat()
            except OSError:
                continue

            Files.append({
                "name": Entry.name,
                "path": str(Entry),
                "size": Info.st_size,
                "mtime": Info.st_mtime,
                "partial": Entry.name.endswith(PartialSuffixes),
                "image": Entry.suffix.lower() in ImageSuffixes,
                "screenshot": Folder == ScreenshotsFolder,
            })

    Files.sort(key=lambda File: File["mtime"], reverse=True)
    return Files


# The is_placeholder function spots the empty file Firefox creates next to a .part file
def is_placeholder(File, PartialPaths):
    return File["size"] == 0 and (File["path"] + ".part") in PartialPaths


# The main function loops forever, printing one JSON line per second
def main():
    PreviousBytes = read_received_bytes()
    PreviousTime = time.monotonic()

    # Seed with what's already there, so old files don't pop up at startup
    SeenComplete = {File["path"] for File in scan_files() if not File["partial"] and File["size"] > 0}

    while True:
        time.sleep(1)

        # Section: Download speed
        NowBytes = read_received_bytes()
        NowTime = time.monotonic()
        Speed = max(0, NowBytes - PreviousBytes) / max(0.001, NowTime - PreviousTime)
        PreviousBytes = NowBytes
        PreviousTime = NowTime

        # Section: Files
        Files = scan_files()
        PartialPaths = {File["path"] for File in Files if File["partial"]}

        Active = [
            {"name": File["name"].rsplit(".", 1)[0], "size": File["size"]}
            for File in Files if File["partial"]
        ]

        Complete = [
            File for File in Files
            if not File["partial"] and not is_placeholder(File, PartialPaths) and File["size"] > 0
        ]

        # Section: New arrivals
        Arrival = None

        for File in Complete:
            if File["path"] not in SeenComplete:
                SeenComplete.add(File["path"])

                if Arrival is None:
                    Arrival = File

        print(json.dumps({
            "speed": Speed,
            "active": Active,
            "recent": Complete[:RecentCount],
            "arrival": Arrival,
            "downloadsFolder": str(DownloadsFolder),
        }), flush=True)


if __name__ == "__main__":
    main()
