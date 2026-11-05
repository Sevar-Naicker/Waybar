#!/usr/bin/env bash
# This file contains the app launcher: it opens rofi with the Shrine theme and header image

# Section: Paths
ROFI_DIR="$HOME/.config/rofi"
HEADER_IMAGE="$ROFI_DIR/shrine_header.png"

# Section: Launch
# The header is passed in here because rofi themes can't use $HOME in image paths
rofi -show drun \
    -theme "$ROFI_DIR/app_launcher.rasi" \
    -theme-str "dummy { background-image: url(\"$HEADER_IMAGE\", width); }"
