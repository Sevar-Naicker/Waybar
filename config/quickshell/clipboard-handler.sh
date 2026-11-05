#!/bin/bash
# This file contains the clipboard handler for the dynamic island
# Saves a copied image to a temporary folder and prints its path; prints nothing for text or other copies

# Section: Drain
# wl-paste hands us the clipboard on stdin; we fetch the image ourselves, so just empty it
cat > /dev/null

# Section: Startup guard
if (( $(date +%s) - ${IslandClipStart:-0} < 2 ))
then
    exit 0
fi

# Section: Image check
ImageType=$(wl-paste --list-types 2>/dev/null | grep -m 1 '^image/')

if [[ -z "$ImageType" ]]
then
    exit 0
fi

# Section: Save
# Temporary folder, cleared on logout; only the newest 5 copies are kept
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

ls -1t "$ClipFolder"/Copied_* 2>/dev/null | tail -n +6 | xargs -r rm -f

# Section: Report
echo "$ClipFile"
