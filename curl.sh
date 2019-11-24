#!/bin/bash

# location to store 5Mb chunks
# WARNING! This location will be crushed by dd
TEMP_FILE="/tmp/weTrans.dat"
DUMMY_LOG="/tmp/dummy.log"

CRED_FILE="$(dirname "$0")/creds.sh"

if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    exit 1
fi
if ! [ -f $CRED_FILE ]; then
    echo "Credential file not found"
    exit 1
fi
source "$CRED_FILE"

LOG_FILE="$2"
if ! [ -f "$LOG_FILE" ]; then
    echo "Log file not found!"
    # Make dummy log so wetransfer doesnt fail
    echo "Dummy log" > "$DUMMY_LOG"
    LOG_FILE="$DUMMY_LOG"
    PASTEBIN_MSG="$PASTEBIN_MSG Error: log file not found!"
fi
LOG_SIZE=$(wc -c < $LOG_FILE)
LOG_BASE_NAME=$(basename $LOG_FILE)

INPUT_FILE="$1"
if ! [ -f "$INPUT_FILE" ]; then
    echo "File not found! Using log file instead"
    PASTEBIN_MSG="Error: video file not found!"
    INPUT_FILE="$2"
fi
FILE_SIZE=$(wc -c < $INPUT_FILE)
INPUT_BASE_NAME=$(basename $INPUT_FILE)

AUTH=$(curl -X POST "https://dev.wetransfer.com/v2/authorize" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $KEY" \
  -d '{"user_identifier":"'"$USER_ID"'"}')
if [[ $? -ne 0 ]]; then echo "authentication ERROR" && exit 1; fi
echo "$AUTH"
# TOKEN=$(echo "$AUTH" | jq -r '.token')
TOKEN=$(echo "$AUTH" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["token"]);')

RESP=$(curl -X POST "https://dev.wetransfer.com/v2/transfers" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -d '
    {
      "message":"Board man gets paid!",
      "files":[
        {
          "name":"'"$INPUT_BASE_NAME"'",
          "size":'"$FILE_SIZE"'
        },
        {
          "name":"'"$LOG_BASE_NAME"'",
          "size":'"$LOG_SIZE"'
        }
      ]
  }')
if [[ $? -ne 0 ]]; then echo "API ERROR" && exit 1; fi
echo "$RESP"

TRANSFER_ID=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["id"]);')
FILE_ID=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][0]["id"]);')
PART_COUNT=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][0]["multipart"]["part_numbers"]);')
CHUNK_SIZE=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][0]["multipart"]["chunk_size"]);')
LOG_FILE_ID=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][1]["id"]);')
LOG_PART_COUNT=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][1]["multipart"]["part_numbers"]);')
LOG_CHUNK_SIZE=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["files"][1]["multipart"]["chunk_size"]);')

# Upload Video file
for ((i=1 ; i<=PART_COUNT ; i++)); do
    RESP=$(curl -X GET "https://dev.wetransfer.com/v2/transfers/$TRANSFER_ID/files/$FILE_ID/upload-url/$i" \
      -H "x-api-key: $KEY" \
      -H "Authorization: Bearer $TOKEN")
    if [[ $? -ne 0 ]]; then echo "API ERROR" && exit 1; fi
    echo "$RESP"
    URL=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["url"]);')

    if [ -n "$TEMP_FILE" ]; then
        dd if="$INPUT_FILE" of="$TEMP_FILE" bs="$CHUNK_SIZE" count=1 skip=$((i - 1))
    else
        echo "No temp file location provided"
        exit 1
    fi

    curl -T "$TEMP_FILE" "$URL"
    if [[ $? -ne 0 ]]; then echo "Upload ERROR" && exit 1; fi
done

# Video file complete
COMPLETE=0
COUNT=0
while (( COMPLETE != 1 || COUNT > 10)); do
    echo "Waiting 3s for upload"
    sleep 3
    RESP=$(curl -i -X PUT "https://dev.wetransfer.com/v2/transfers/$TRANSFER_ID/files/$FILE_ID/upload-complete" \
      -H "Content-Type: application/json" \
      -H "x-api-key: $KEY" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{"part_numbers":'"$PART_COUNT"'}')
    if [[ $? -eq 0 ]] ; then
        COMPLETE=1
    fi
    echo "$RESP"
    COUNT=$(( COUNT + 1 ))
done

# Upload Log file
for ((i=1 ; i<=LOG_PART_COUNT ; i++)); do
    RESP=$(curl -X GET "https://dev.wetransfer.com/v2/transfers/$TRANSFER_ID/files/$LOG_FILE_ID/upload-url/$i" \
      -H "x-api-key: $KEY" \
      -H "Authorization: Bearer $TOKEN")
    if [[ $? -ne 0 ]]; then echo "API ERROR" && exit 1; fi
    echo "$RESP"
    URL=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["url"]);')

    if [ -n "$TEMP_FILE" ]; then
        dd if="$LOG_FILE" of="$TEMP_FILE" bs="$LOG_CHUNK_SIZE" count=1 skip=$((i - 1))
    else
        echo "No temp file location provided"
        exit 1
    fi

    curl -T "$TEMP_FILE" "$URL"
    if [[ $? -ne 0 ]]; then echo "Upload ERROR" && exit 1; fi
done

# Log file complete
COMPLETE=0
COUNT=0
while (( COMPLETE != 1 || COUNT > 10)); do
    echo "Waiting 3s for upload"
    sleep 3
    RESP=$(curl -i -X PUT "https://dev.wetransfer.com/v2/transfers/$TRANSFER_ID/files/$LOG_FILE_ID/upload-complete" \
      -H "Content-Type: application/json" \
      -H "x-api-key: $KEY" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{"part_numbers":'"$LOG_PART_COUNT"'}')
    if [[ $? -eq 0 ]] ; then
        COMPLETE=1
    fi
    echo "$RESP"
    COUNT=$(( COUNT + 1 ))
done

RESP=$(curl -X PUT "https://dev.wetransfer.com/v2/transfers/$TRANSFER_ID/finalize" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $KEY" \
  -H "Authorization: Bearer $TOKEN")
echo "$RESP"
DWL_URL=$(echo "$RESP" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["url"]);')
echo "LINK: $DWL_URL"
# Remove https:// from url to avoid trigering pastebin spam detection
DWL_URL=$(echo $DWL_URL | sed 's/https:\/\///')
PASTEBIN_MSG="$PASTEBIN_MSG
Download link: $DWL_URL"

# Pastebin API Call
echo ""
echo "Done uploading to WeTransfer, uploading link to PasteBin:"
echo ""
SUCCESS=0
while [ "$SUCCESS" -eq 0 ]; do
    SUCCESS=1
    DATE=$(date +"%Y-%m-%d_%H-%M")
    url="http://pastebin.com/api/api_login.php"
    headers="Content-Type: application/x-www-form-urlencoded; charset=UTF-8"
    data="api_dev_key=$API_DEV_KEY&api_user_name=$USER_NAME&api_user_password=$PASS"
    AUTH=$(curl -X POST -H "$headers" --data "$data" $url)
    if [[ $? -ne 0 ]]; then echo "authentication ERROR" && exit 1; fi
    if echo "$AUTH" | grep -q "heavy load" ; then SUCCESS=0 && sleep 30; fi
    echo "$AUTH"
done

url="http://pastebin.com/api/api_post.php"
headers="Content-Type: application/x-www-form-urlencoded; charset=UTF-8"
data="api_option=paste&api_dev_key=$API_DEV_KEY&api_user_key=$AUTH&api_paste_name=$DATE&api_paste_expire_date=1W&api_option=paste&api_paste_private=1"

RESP=$(curl -X POST -H "$headers" --data "$data" --data-urlencode "api_paste_code=$PASTEBIN_MSG" $url)
echo "$RESP"

echo ""
rm "$TEMP_FILE"
rm -f "$DUMMY_LOG"
