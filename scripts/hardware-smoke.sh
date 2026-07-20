#!/usr/bin/env bash

set -euo pipefail

board=${1:-192.168.0.121}
ssh_options=(
    -o BatchMode=yes
    -o ConnectTimeout=8
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
)

remote_output=$(ssh "${ssh_options[@]}" "$board" \
    'IO.puts(String.trim_trailing(File.read!("/proc/device-tree/model"), <<0>>)); System.cmd("sh", ["-c", "cat /proc/asound/cards; cat /proc/asound/pcm; cat /proc/mounts; ls /sys/class/net; aplay -D hw:0,0 -d 1 -f S16_LE -r 48000 -c 2 /dev/zero; arecord -D hw:0,0 -d 1 -f S16_LE -r 48000 -c 2 /dev/null"], stderr_to_stdout: true) |> elem(0) |> IO.write()')

require_line() {
    description=$1
    pattern=$2
    if ! grep -Fq "$pattern" <<<"$remote_output"; then
        printf 'FAIL: %s\n' "$description" >&2
        printf '%s\n' "$remote_output" >&2
        exit 1
    fi
    printf 'PASS: %s\n' "$description"
}

require_line "ROCK Pi S device tree" "Radxa ROCK Pi S"
require_line "RK3308 ALSA card" "rockchip,rk3308-acodec"
require_line "hardware playback PCM" "00-00:"
require_line "application-data mount" "/dev/mmcblk2p4 /root ext4"
require_line "Ethernet interface" "eth0"
require_line "playback stream" "Playing raw data"
require_line "capture stream" "Recording WAVE"
