#!/bin/bash

. "/etc/Kave-Cloud.conf"

DIR="/var/www/html/kave.${Domain}/"
TRACKERS_FILE="${DIR}ClearnetTrackers.txt"
WEBSEEDER="https://kave.${Domain}/OpenCamera"
CAMERA_DIR="${DIR}OpenCamera"
SERVER="${Android_IP_Address}:${Android_Port}"
CLEARNET_TRACKERS="https://newtrackon.com/api/100?include_ipv6_only_trackers=false"
OUTFILE="${DIR}ClearnetTrackers.txt"
TEMPFILE="${OUTFILE}.new"

if curl -s -I "http://$SERVER" >/dev/null; then

cd "${DIR}"

rm -f "${DIR}index.html"

echo "Started snowing at $(date)"

snow "${DIR}" "http://$SERVER"

echo "Finished snowing at $(date)"

echo "Starting comparison step at $(date)"

# Get the list of relative paths in index.html
html_files=$(grep -oP 'OpenCamera\/\K[^"]+' "${DIR}index.html")

# Compare the files present in the OpenCamera directory with the relative paths in index.html
for file in OpenCamera/*; do
  # Extract the file name from the full path
  file_name=${file##*/}
  echo "Comparing file: $file_name"
    # Ignore torrent files
  if [ "${file_name##*.}" == "torrent" ]; then
    continue
  fi
  # Check if the file is present in index.html
  if ! echo "$html_files" | grep -q "$file_name"; then
    echo "Deleting file: $file_name"
    rm "$file"
  fi
done

echo "Finished comparison step at $(date)"

# Get clearnet trackers
RESPONSE_CODE=$(curl --fail --write-out "%{response_code}" "${CLEARNET_TRACKERS}" --output "${TEMPFILE}")

# If something went wrong getting the clearnet trackers list
if [[ ${RESPONSE_CODE} != 200 ]]; then
  # Erase the temporal file and exit
  rm -f "${TEMPFILE}"
  exit 1
fi

# Replace the old clearnet trackers file with the new one
mv "${TEMPFILE}" "${OUTFILE}"

cd "$CAMERA_DIR"

echo "Starting tracker loop step at $(date)"

trackers=""
while read -r line; do
    if [ -n "$line" ]; then
        trackers="$trackers -a $line"
    fi
done < "$TRACKERS_FILE"

echo "Finished tracker loop step at $(date)"

rm -f "${CAMERA_DIR}"/*.torrent
for file in *.webp *.mp4; do
    echo "Starting processing of file $file at $(date)"

    mktorrent -w "$WEBSEEDER" $trackers "$file" -o "${file}.torrent"
    MAGNET_LINK=$(transmission-show -m "${file}.torrent" | grep -oP 'magnet:.+')
    if [ -n "$MAGNET_LINK" ]; then
        while read -r tracker; do
            if [ -n "$tracker" ]; then
                TRACKER_PARAM="&tr=$tracker"
            fi
        done < "$TRACKERS_FILE"
        MAGNET_LINK="$MAGNET_LINK$TRACKER_PARAM"
        ESCAPED_MAGNET_LINK=$(printf '%s\n' "$MAGNET_LINK" | sed -e 's/[\/&]/\\&/g')
        sed -i "s|$file|$file\" data-magnet=\"$ESCAPED_MAGNET_LINK|g" "${DIR}index.html"
    fi
    echo "Finished processing of file $file at $(date)"
done

echo "Finished processing all files at $(date)"

else
    # server is not reachable, do something else here
    echo "Server is not reachable"
fi