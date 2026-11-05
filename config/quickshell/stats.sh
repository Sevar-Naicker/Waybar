#!/bin/bash
# This file contains the system stats feed for the dynamic island
# Prints one line every 2 seconds: cpu% cpuTemp gpu% gpuTemp ramUsedGB ramTotalGB (-1 means unavailable)

# Section: Sensor discovery

# The find_hwmon function finds the sensor folder with a given driver name
find_hwmon()
{
    for Dir in /sys/class/hwmon/hwmon*
    do
        if [[ "$(cat "$Dir/name" 2>/dev/null)" == "$1" ]]
        then
            echo "$Dir"
            return
        fi
    done
}

# The read_temp function reads a sensor folder's first temperature in °C, or -1
read_temp()
{
    if [[ -n "$1" && -r "$1/temp1_input" ]]
    then
        echo $(( $(cat "$1/temp1_input") / 1000 ))
    else
        echo -1
    fi
}

# AMD CPUs report as k10temp, Intel as coretemp
CpuHwmon=$(find_hwmon k10temp)
[[ -z "$CpuHwmon" ]] && CpuHwmon=$(find_hwmon coretemp)

# AMD GPUs expose usage and temperature in sysfs; NVIDIA needs nvidia-smi
GpuHwmon=$(find_hwmon amdgpu)
GpuBusyFile=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 1)
HasNvidia=0
command -v nvidia-smi >/dev/null 2>&1 && HasNvidia=1

# Section: CPU baseline
read -r _ User Nice System Idle Iowait Irq Softirq Steal _ < /proc/stat
PrevTotal=$(( User + Nice + System + Idle + Iowait + Irq + Softirq + Steal ))
PrevIdle=$(( Idle + Iowait ))

# Section: Main loop
while true
do
    sleep 2

    # CPU usage since the last reading
    read -r _ User Nice System Idle Iowait Irq Softirq Steal _ < /proc/stat
    Total=$(( User + Nice + System + Idle + Iowait + Irq + Softirq + Steal ))
    IdleAll=$(( Idle + Iowait ))
    DiffTotal=$(( Total - PrevTotal ))
    DiffIdle=$(( IdleAll - PrevIdle ))
    PrevTotal=$Total
    PrevIdle=$IdleAll

    CpuUsage=0
    (( DiffTotal > 0 )) && CpuUsage=$(( 100 * (DiffTotal - DiffIdle) / DiffTotal ))
    CpuTemp=$(read_temp "$CpuHwmon")

    # GPU usage and temperature
    GpuUsage=-1
    GpuTemp=-1

    if (( HasNvidia ))
    then
        NvidiaLine=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        GpuUsage=$(echo "$NvidiaLine" | cut -d',' -f1 | tr -d ' ')
        GpuTemp=$(echo "$NvidiaLine" | cut -d',' -f2 | tr -d ' ')
        [[ -z "$GpuUsage" ]] && GpuUsage=-1
        [[ -z "$GpuTemp" ]] && GpuTemp=-1
    else
        [[ -n "$GpuBusyFile" ]] && GpuUsage=$(cat "$GpuBusyFile" 2>/dev/null || echo -1)
        GpuTemp=$(read_temp "$GpuHwmon")
    fi

    # RAM in use (total minus available) and total, in GB
    Ram=$(awk '/^MemTotal:/ {T=$2} /^MemAvailable:/ {A=$2} END {printf "%.1f %.1f", (T-A)/1048576, T/1048576}' /proc/meminfo)

    echo "$CpuUsage $CpuTemp $GpuUsage $GpuTemp $Ram"
done
