#!/bin/bash
# This file contains the clipboard handler for the dynamic island
# Saves a copied image to a temporary folder and prints its path, and adds every copy to the clipboard menu's history

# Section: Drain
# wl-paste hands us the clipboard on stdin; we fetch the image ourselves, so just empty it
cat > /dev/null

# Section: Startup guard
if (( $(date +%s) - ${IslandClipStart:-0} < 2 ))
then
    exit 0
fi

# Section: Copy check
Types=$(wl-paste --list-types 2>/dev/null)
HistoryScript="$HOME/.config/quickshell/clipboard-history.py"

# Password managers mark secret copies; those never go into the history
if grep -q 'x-kde-passwordManagerHint' <<< "$Types"
then
    exit 0
fi

ImageType=$(grep -m 1 '^image/' <<< "$Types")

# Text: keep it for the clipboard menu, nothing to pop up
if [[ -z "$ImageType" ]]
then
    if grep -qE '^(text/plain|UTF8_STRING|STRING|TEXT)' <<< "$Types"
    then
        wl-paste --no-newline --type text 2>/dev/null | python3 "$HistoryScript" text
    fi

    exit 0
fi

# Section: Save
# Temporary folder, cleared on logout; only the newest 20 copies are kept
ClipFolder="${XDG_RUNTIME_DIR:-/tmp}/island-clipboard"
mkdir -p "$ClipFolder"

Extension="${ImageType#image/}"
ClipFile="$ClipFolder/Copied_$(date +%Y-%m-%d_%H-%M-%S).$Extension"

wl-paste --type "$ImageType" > "$ClipFile" 2>/dev/null || exit 0

if [[ ! -s "$ClipFile" ]]
then
    rm -f "$ClipFile"
    exit 0
fi

ls -1t "$ClipFolder"/Copied_* 2>/dev/null | tail -n +21 | xargs -r rm -f

# Section: Report
python3 "$HistoryScript" image "$ClipFile"
echo "$ClipFile"
