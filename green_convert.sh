#!/bin/bash
# Expects a video file as input. Will replace each portion of the video that is
# blacked out for more then 2 seconds with a green screen. This is to aid in editing
# with imovie or other video editor that can intepret the green as transparent.
# Outputs a file dated file YYYYMMDD.mp4

INPUT="$1"
OUTPUT_FILENAME="$2"
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    exit 1
fi
if ! [ -f $INPUT ]; then
    echo "Invalid argument, file does not exist"
    exit 1
fi
if [ -f $OUTPUT_FILENAME ]; then
    echo "Output file $OUTPUT_FILENAME already exists"
    read -r -p "Overwrite? [Y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
     echo "Yes"
     ;;
        *)
     echo "Exiting..."
     exit 1
     ;;
    esac
fi

if [ $(echo "$OSTYPE" | grep darwin) ]; then
    PATH="$PATH:/Applications"
fi
HEADER="-i $INPUT -f lavfi -i color=c=0x00FF00:s=1920x1080 -loop 1 "
COMMAND=""
OVERLAY=""
STRART_PREV=0
let NB_BLANK=0
END=0

DATE=$(date +"%F %T")
echo "start at $DATE"

# Get list of blacked out sections of video (longer then 2s)
OUTPUT=$(ffmpeg -i $INPUT -vf "blackdetect=d=2:pix_th=0.00" -an -f null - 2>&1 | grep "blackdetect ")

echo "output: $OUTPUT"
echo $OUTPUT | grep -q black
if [ $? -ne 0 ]; then echo "No black frames! Exiting" && exit 1; fi

# For each blacked out section create a greenscreen overlay with fade in/out
# Then overlay each one over original file
while IFS= read -r line
do
    line=$(echo "$line" | sed 's/\[.*\] //')
    let NB_BLANK++
    START=$(echo $line | sed 's/.*black_start://' | sed 's/ black_end.*//')
    END=$(echo $line | sed 's/.*black_end://' | sed 's/ black_duration.*//')
    if (( $(echo "$START > 1" | bc -l) )); then
        START=$(echo "$START - 1" | bc -l)
    fi
    END_PLUS_ONE=$(echo "$END + 1" | bc -l)
    COMMAND="$COMMAND[1:v]fade=t=in:st=$START:d=1:c=0x00000000:alpha=1,fade=t=out:st=$END:d=1:c=0x00000000:alpha=1[v$NB_BLANK]; "
    END=$END_PLUS_ONE

    if (( NB_BLANK==1 )); then
        OVERLAY="$OVERLAY[0:v][v1]overlay=x=0:y=0:shortest=1:enable='between(t,$START,$END)'[w1]; "
    elif (( NB_BLANK>1 )); then
        OVERLAY="$OVERLAY[w$((NB_BLANK-1))][v$NB_BLANK]overlay=x=0:y=0:shortest=1:enable='between(t,$START,$END)'[w$NB_BLANK]; "
    fi
    START_PREV="$START"
done <<< "$OUTPUT"

echo "Number of transitions : $NB_BLANK"

# Remove trailing ";"
OVERLAY=$(echo "$OVERLAY" | rev | cut -c 3- | rev)
ffmpeg $HEADER -filter_complex "$COMMAND$OVERLAY" -map [w$NB_BLANK] -c:v libx264 -preset superfast -y "$OUTPUT_FILENAME"

DATE=$(date +"%F %T")
echo "end at $DATE"
echo ""

