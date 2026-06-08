#!/bin/sh

# Read-only discovery for an RDKC camera connected to an XB gateway.
# This script does not open or consume csi_motion_pipe* FIFOs.

OUT="${1:-/tmp/rdkc_ai/camera_discovery.txt}"
OUT_DIR=$(dirname "$OUT")
mkdir -p "$OUT_DIR" 2>/dev/null

exec >"$OUT" 2>&1

section() {
    printf '\n===== %s =====\n' "$1"
}

run_if_present() {
    command_name="$1"
    shift
    if command -v "$command_name" >/dev/null 2>&1; then
        "$command_name" "$@"
    else
        printf '%s: not installed\n' "$command_name"
    fi
}

section "Timestamp and platform"
date
uname -a
printf 'User: '
id

section "Relevant mounts"
grep ' /tmp ' /proc/mounts 2>/dev/null
grep ' /data ' /proc/mounts 2>/dev/null

section "Camera and motion processes"
ps 2>/dev/null | grep -Ei 'csi|camera|rdkc|csc|zilker|xhome|icontrol' | grep -v grep

section "CSI motion FIFOs"
ls -l /tmp/csi_motion_pipe* 2>/dev/null || echo "No /tmp/csi_motion_pipe* entries found"

section "Processes with CSI motion FIFO descriptors"
found_pipe_fd=0
for fd in /proc/[0-9]*/fd/*; do
    target=$(readlink "$fd" 2>/dev/null) || continue
    case "$target" in
        *csi_motion_pipe*)
            found_pipe_fd=1
            pid=$(echo "$fd" | cut -d/ -f3)
            fd_number=$(basename "$fd")
            cmd=$(tr '\000' ' ' <"/proc/$pid/cmdline" 2>/dev/null)
            [ -n "$cmd" ] || cmd=$(cat "/proc/$pid/comm" 2>/dev/null)
            flags=$(grep '^flags:' "/proc/$pid/fdinfo/$fd_number" 2>/dev/null | awk '{print $2}')
            printf 'pid=%s fd=%s flags=%s target=%s command=%s\n' \
                "$pid" "$fd_number" "${flags:-unknown}" "$target" "$cmd"
            ;;
    esac
done
[ "$found_pipe_fd" -eq 1 ] || echo "No process file descriptors mapped to csi_motion_pipe*"

section "Video and media device nodes"
ls -l /dev/video* /dev/media* /dev/v4l-* 2>/dev/null || echo "No standard V4L2/media device nodes found"

section "Camera service directories"
for directory in /csc /tmp/csc /nvram/csc /opt/icontrol; do
    if [ -e "$directory" ]; then
        echo "-- $directory"
        ls -la "$directory" 2>/dev/null
    fi
done

section "Likely camera configuration files"
for root in /tmp /data /nvram /opt/icontrol /csc; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth 4 -type f 2>/dev/null |
        grep -Ei 'camera|csi|motion|clip|stream|rtsp|zilker|csc' |
        head -n 200
done

section "Recent media and frame files"
for root in /tmp /data /nvram; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth 5 -type f 2>/dev/null |
        grep -Ei '\.(mp4|mkv|ts|h264|h265|hevc|jpg|jpeg|png|pgm)$' |
        head -n 200 |
        while IFS= read -r media_file; do
            ls -l "$media_file" 2>/dev/null
        done
done

section "Available media utilities"
for command_name in ffmpeg gst-launch-1.0 gst-inspect-1.0 v4l2-ctl media-ctl cvlc; do
    if command -v "$command_name" >/dev/null 2>&1; then
        command -v "$command_name"
    else
        echo "$command_name: not installed"
    fi
done

section "Listening sockets"
if command -v ss >/dev/null 2>&1; then
    ss -lntup 2>/dev/null
elif command -v netstat >/dev/null 2>&1; then
    netstat -lntup 2>/dev/null
else
    echo "Neither ss nor netstat is installed"
fi

section "Recent camera-related log lines"
for log in /tmp/*csc*.log /tmp/*camera*.log /nvram/log/*csc* /nvram/log/*camera*; do
    [ -f "$log" ] || continue
    echo "-- $log"
    tail -n 200 "$log" 2>/dev/null |
        grep -Ei 'camera|motion|clip|stream|csi|connect|event|error' |
        tail -n 80
done

section "Discovery summary"
echo "Output file: $OUT"
echo "The CSI FIFO was not opened or consumed by this script."
