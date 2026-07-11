#!/usr/bin/bash

media_dir="$1"
output_file="$2"

declare -A media   # artist -> newline-separated titles
files=()           # array of matching filenames

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

add_entry() {
    local artist="$1" title="$2"
    if [[ -z "${media[$artist]+set}" ]]; then
        media["$artist"]="$title"
    else
        media["$artist"]+=$'\n'"$title"
    fi
}

fix1() {
    local name="$1"
    local title artist
    title="${name%% \(*}"
    artist="${name##*- }"
    title="$(trim "$title")"
    artist="$(trim "$artist")"
    add_entry "$artist" "$title"
}

fix2() {
    local name="$1"
    local artist title
    artist="${name%% - *}"
    title="${name#*- }"
    artist="$(trim "$artist")"
    title="$(trim "$title")"
    add_entry "$artist" "$title"
}

fix3() {
    add_entry "Unknown" "Unknown"
}

# 1. Collect matching filenames into an array
mapfile -t files < <(find "$media_dir" -type f \
    \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.mp4" -o -iname "*.mkv" \) \
    -printf "%f\n")

# 2. Iterate the array and dispatch to the right fix function
for filename in "${files[@]}"; do
    name="${filename%.*}"   # strip extension

    if [[ "$name" =~ \([0-9]{4}\) ]]; then
        fix1 "$name"
    elif [[ "$name" =~ .+[[:space:]]-[[:space:]].+ ]]; then
        fix2 "$name"
    else
        fix3
    fi
done

mapfile -t sorted_artists < <(printf '%s\n' "${!media[@]}" | sort)

for artist in "${sorted_artists[@]}"; do
    echo "$artist" >> "$output_file"
    printf '%s\n' "${media[$artist]}" | sort | sed 's/^/\t/'>> "$output_file"
done
