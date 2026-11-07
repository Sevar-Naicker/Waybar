#!/usr/bin/env python3
# This file contains the clipboard history store for the clipboard menu
# clipboard-handler.sh runs it for each copy: "text" reads the copied text from stdin, "image <path>" records a saved image
# The history is a JSON list in ~/.local/state/shrine-waybar/clipboard-history.json, newest first, at most 100 entries

import json
import os
import sys
from pathlib import Path

# Section: Settings
MaxEntries = 100
MaxTextBytes = 100_000
HistoryFile = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "shrine-waybar" / "clipboard-history.json"


# The load function reads the history, or starts a new one
def load():
    try:
        History = json.loads(HistoryFile.read_text(encoding="utf-8"))
        return History if isinstance(History, list) else []
    except (OSError, ValueError):
        return []


# The save function writes the history in one go, so the menu never reads half a file
def save(History):
    HistoryFile.parent.mkdir(parents=True, exist_ok=True)
    Temporary = HistoryFile.with_suffix(".tmp")
    Temporary.write_text(json.dumps(History, ensure_ascii=False), encoding="utf-8")
    Temporary.replace(HistoryFile)


# The add function puts an entry on top, drops its older copy, and forgets images whose files are gone
def add(Entry):
    History = [Item for Item in load() if Item != Entry]
    History = [Item for Item in History if "image" not in Item or os.path.exists(Item["image"])]
    History.insert(0, Entry)
    save(History[:MaxEntries])


# The main function handles "text" (from stdin), "image <path>" and "clear"
def main():
    Action = sys.argv[1] if len(sys.argv) > 1 else ""

    if Action == "text":
        Data = sys.stdin.buffer.read(MaxTextBytes + 1)

        # Very large copies (whole files) aren't worth keeping
        if len(Data) > MaxTextBytes:
            return

        Text = Data.decode("utf-8", errors="replace")

        if Text.strip():
            add({"text": Text})

    elif Action == "image" and len(sys.argv) > 2:
        add({"image": sys.argv[2]})

    elif Action == "clear":
        save([])


if __name__ == "__main__":
    main()
