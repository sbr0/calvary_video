#!/bin/sh

# TODO: show output of blackdetect on terminal real time

INPUT_VIDEO=$1
if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    exit 1
fi
if ! [ -f "$INPUT_VIDEO" ]; then
    echo "File not found!"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
LOG_DIR="$SCRIPT_DIR/.ffmpeg_logs"
mkdir -p "$LOG_DIR"
DATE=$(date +"%Y-%m-%d_%H-%M")
LOG_FILE="$LOG_DIR"/"$DATE".log

"$SCRIPT_DIR"/convert.sh "$INPUT_VIDEO" "vp9_alpha_$DATE.mkv" 2>&1 | tee "$LOG_FILE"
cp -n "$LOG_FILE" /tmp/calv_parse.log
"$SCRIPT_DIR"/curl.sh "vp9_alpha_$DATE.mkv" /tmp/calv_parse.log 2>&1 | tee -a "$LOG_FILE"

# green screen version no longer needed as vp9 transparency works better

# DATE=$(date +"%Y-%m-%d_%H-%M")
# LOG_FILE="$LOG_DIR"/"$DATE".log
# "$SCRIPT_DIR"/green_convert.sh "$INPUT_VIDEO" "green_H264_$DATE.mp4" 2>&1 | tee "$LOG_FILE"
# cp -n "$LOG_FILE" /tmp/calv_parse.log
# "$SCRIPT_DIR"/curl.sh "green_H264_$DATE.mp4" /tmp/calv_parse.log 2>&1 | tee -a "$LOG_FILE"

kill -9 "$PPID"
