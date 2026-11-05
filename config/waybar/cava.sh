#!/bin/bash
# CAVA wrapper for Waybar
cava -p <(echo "[general]
bars = 10
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7") | while read -r line; do
    if [[ "$line" =~ [1-7] ]]; then
        CLEAN_LINE=$(echo "$line" | sed 's/;//g' | sed 's/0/ /g' | sed 's/1/▂/g' | sed 's/2/▃/g' | sed 's/3/▄/g' | sed 's/4/▅/g' | sed 's/5/▆/g' | sed 's/6/▇/g' | sed 's/7/█/g')
        echo "$CLEAN_LINE"
    else
        echo ""
    fi
done
