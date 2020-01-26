#!/bin/bash
# Expects a video file as input. Will replace each portion of the video that is
# blacked out for more then 2 seconds with a green screen. This is to aid in editing
# with imovie or other video editor that can intepret the green as transparent.
# Outputs a file dated file YYYYMMDD.mp4

INPUT="$1"
OUTPUT_FILENAME="$2"
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo ""
    echo "Usage: $0 input_file output_file.mkv"
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

SCRIPT_DIR=$(dirname "$0")
DATA_DIR="$SCRIPT_DIR/.ffmpeg_data"
mkdir -p "$DATA_DIR"
DATE=$(date +"%Y-%m-%d_%H-%M")
LIST_FILE="$DATA_DIR/$DATE.txt"

STRART_PREV=0.0
START=0.0
END_PREV=0.0
let NB_LINE=0
END=0.0
NB_CLIP=0
LAST_WAS_END=0

DATE=$(date +"%F %T")
echo "start at $DATE"

# Get list of blacked out sections of video (longer then 2s)
OUTPUT=$(ffmpeg -f lavfi -i "movie=$INPUT,blackdetect=pix_th=0.01:pic_th=1.00,metadata=print:file=-" -f null - -hide_banner | grep lavfi)

echo "output: $OUTPUT"

sleep 3

rm "$LIST_FILE"

# For each blacked out section create a greenscreen overlay with fade in/out
# Then overlay each one over original file
while IFS= read -r line
do
    echo "line iter $line"
    let NB_LINE++
    if echo "$line" | grep -q black_end ; then
        END_PREV=$END
        END=$(echo $line | sed 's/.*black_end=//')
        # ignore first video section if it is blank
        if (( $(echo "$START > 1" | bc -l) )); then
            # bc does not print leading 0s, hence the need for awk. Ex: .8324
            FADE_START=$(echo "$START - 1 - $END_PREV" | bc -l | awk '{printf "%f\n", $0}')
            if (( $(echo "$FADE_START < 0" | bc -l) )); then
                FADE_START=0;
            fi
            DURATION=$(echo "$END - $END_PREV" | bc -l)
            echo "END_PREV = $END_PREV"
            echo "END = $END"
            echo "FADE_START = $FADE_START"
            echo "DURATION = $DURATION"
            ffmpeg -ss $END_PREV -i $INPUT -vf fade=t=in:st=0:d=1:alpha=1,fade=t=out:st=$FADE_START:d=1:alpha=1 -t $DURATION -c:v libvpx-vp9 -crf 18 -b:v 0 -y -r ntsc "$DATA_DIR/clip$NB_CLIP.mkv" </dev/null
            echo "file clip$NB_CLIP.mkv" >> "$LIST_FILE"
            let NB_CLIP++
            echo ""
            echo "NB_CLIP = $NB_CLIP"
            echo ""
        fi
        LAST_WAS_END=1
    fi
    if echo "$line" | grep -q black_start ; then
        echo "  "
        START=$(echo $line | sed 's/.*black_start=//')

        echo "AT START LINE: START = $START"
        echo ""
        LAST_WAS_END=0
    fi
done <<< "$OUTPUT"

if [ "$LAST_WAS_END" -ne 1 ]; then
    echo ""
    echo "Condition met"
        echo "#"
    # $END_LAST was not updated so use $END
    # No end time specified because unknown, let ffmpeg go to end of file
    FADE_START=$(echo "$START - 1 - $END" | bc -l)
    ffmpeg -ss $END -i $INPUT -vf fade=t=in:st=0.0:d=1:alpha=1,fade=t=out:st=$FADE_START:d=1:alpha=1 -c:v libvpx-vp9 -crf 18 -b:v 0 -y -r ntsc "$DATA_DIR/clip$NB_CLIP.mkv" </dev/null
else
    # No fade out
    echo "CONDITION NOT MET"
    ffmpeg -ss $END -i $INPUT -vf fade=t=in:st=0.0:d=1:alpha=1 -c:v libvpx-vp9 -crf 18 -b:v 0 -y -r ntsc "$DATA_DIR/clip$NB_CLIP.mkv" </dev/null
fi
echo "file clip$NB_CLIP.mkv" >> "$LIST_FILE"

ffmpeg -f concat -i "$LIST_FILE" -y -c copy "$OUTPUT_FILENAME"
