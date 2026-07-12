#!/usr/bin/bash
#
# extract_access.sh
# Usage: ./extract_access.sh <log_file> <access_type> <startHH-endHH>
#
# Log line format:  YYYY-MM-DD HH:MM:SS username AccessType
#   (AccessType can be one word, like "Login"/"Logout", or two words,
#    like "File Access")
#
# This prints "username AccessType" for every line whose access type
# matches exactly and whose hour falls within the inclusive range
# [startHH, endHH], both given in 24-hour format.

log_file="$1"
access_type="$2"
time_range="$3"

if [[ -z "$log_file" || -z "$access_type" || -z "$time_range" || ! -f "$log_file" ]]; then
    echo "Usage: $0 <log_file> <access_type> <startHH-endHH>" >&2
    exit 1
fi

# Split "startHH-endHH" into its two halves using parameter expansion
start_hour="${time_range%-*}"   # everything before the "-"
end_hour="${time_range#*-}"     # everything after the "-"

# Force base-10 interpretation, otherwise hours like "08" or "09" get
# misread as invalid octal numbers by bash arithmetic
start_hour=$((10#$start_hour))
end_hour=$((10#$end_hour))

# Read every line of the log file into an array (mapfile, not a
# while/read loop)
mapfile -t lines < "$log_file"

for line in "${lines[@]}"; do
    # Field 2 is the HH:MM:SS timestamp
    time_field=$(echo "$line" | cut -d' ' -f2)

    # Field 3 is the username
    username=$(echo "$line" | cut -d' ' -f3)

    # Fields 4 onward are the access type - could be one word
    # ("Login") or two ("File Access"), so we take "4 to end"
    line_access_type=$(echo "$line" | cut -d' ' -f4-)

    # Pull just the hour out of HH:MM:SS and force base-10
    hour="${time_field%%:*}"
    hour=$((10#$hour))

    # Keep the line only if BOTH the access type matches exactly AND
    # the hour falls inside the inclusive requested range
    if [[ "$line_access_type" == "$access_type" && $hour -ge $start_hour && $hour -le $end_hour ]]; then
        echo "$username $line_access_type"
    fi
done
