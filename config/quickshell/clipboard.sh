#!/bin/bash
# This file contains the clipboard watcher for the dynamic island
# Runs clipboard-handler.sh every time the clipboard changes; the handler prints a file path when an image was copied

# Section: Start time
# The handler ignores the first two seconds, so whatever is already on the clipboard doesn't pop up at login
export IslandClipStart=$(date +%s)

# Section: Watch
exec wl-paste --watch bash "$HOME/.config/quickshell/clipboard-handler.sh"
