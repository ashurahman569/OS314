#!/usr/bin/bash
#
# File Deduplicator
# Usage: ./deduplicator.sh <target_directory>
#
# STRATEGY (per the assignment's hint):
#   1. Recursively list every file under the target directory.
#   2. Group files by SIZE first, since comparing sizes is cheap.
#      Any file whose size is unique in the whole tree can NEVER be a
#      duplicate, so we skip it immediately and never touch it again.
#   3. Only for size groups that have 2+ files do we bother computing
#      MD5 checksums (the expensive step) and group THOSE files by hash.
#   4. Within a hash group of 2+ files, everything really is byte-for-byte
#      identical. We keep the first file as the "original" and delete
#      the rest, tallying how many files and how many bytes we freed.
#   5. Write Report.txt with the requested statistics.

target_dir="$1"

if [[ -z "$target_dir" || ! -d "$target_dir" ]]; then
    echo "Usage: $0 <target_directory>" >&2
    exit 1
fi

# ---------------------------------------------------------------------
# size_groups: associative array mapping   size_in_bytes -> file list
# The "file list" is stored as ONE string with paths separated by
# newlines (same pattern used in earlier scripts) so we can keep using
# a plain associative array instead of arrays-of-arrays (bash can't do
# those natively anyway).
# ---------------------------------------------------------------------
declare -A size_groups

# add_to_size_group: appends a file path under its size "bucket".
# $1 = size in bytes (the key we group by)
# $2 = full path to the file (the value we're storing)
add_to_size_group() {
    local size="$1"
    local path="$2"

    if [[ -z "${size_groups[$size]+set}" ]]; then
        # First time we've seen this exact size -> start a new entry
        size_groups["$size"]="$path"
    else
        # We've seen this size before -> append, separated by a newline
        size_groups["$size"]+=$'\n'"$path"
    fi
}

# ---------------------------------------------------------------------
# hash_groups: associative array mapping   md5_checksum -> file list
# This gets wiped and rebuilt fresh for EVERY size group we investigate,
# since an MD5 collision only matters when comparing files of the exact
# same size in the first place.
# ---------------------------------------------------------------------
declare -A hash_groups

add_to_hash_group() {
    local hash="$1"
    local path="$2"

    if [[ -z "${hash_groups[$hash]+set}" ]]; then
        hash_groups["$hash"]="$path"
    else
        hash_groups["$hash"]+=$'\n'"$path"
    fi
}

# ---------------------------------------------------------------------
# Running totals for the final report
# ---------------------------------------------------------------------
total_files=0
duplicates_found=0
space_saved=0   # in bytes, since the spec says plain bytes is fine

# ---------------------------------------------------------------------
# STEP 1: Recursively collect every file under target_dir into an array
# ---------------------------------------------------------------------
mapfile -t all_files < <(find "$target_dir" -type f)

total_files=${#all_files[@]}

# ---------------------------------------------------------------------
# STEP 2: Bucket every file by its size (the cheap filter)
# ---------------------------------------------------------------------
for file in "${all_files[@]}"; do
    file_size=$(stat -c %s "$file")
    add_to_size_group "$file_size" "$file"
done

# Get the list of distinct sizes we found, so we can loop over the
# buckets safely (looping directly over "${!size_groups[@]}" while also
# modifying hash_groups inside the loop is fine, but mapfile-ing it
# first keeps the loop predictable and matches our usual style).
mapfile -t all_sizes < <(printf '%s\n' "${!size_groups[@]}")

# ---------------------------------------------------------------------
# STEP 3 & 4: For every size bucket with 2+ files, hash them and
# delete any true duplicates we find.
# ---------------------------------------------------------------------
for size in "${all_sizes[@]}"; do

    # Turn this size bucket's newline-separated string back into a
    # real bash array so we can count it and loop over it easily.
    mapfile -t files_this_size <<< "${size_groups[$size]}"

    file_count=${#files_this_size[@]}

    # Only one file at this size? It's impossible for it to have a
    # duplicate, so skip straight to the next size bucket. This is
    # exactly the "cheap filter first" optimization the spec asks for -
    # we never compute an MD5 for this file at all.
    if [[ $file_count -lt 2 ]]; then
        continue
    fi

    # Reset hash_groups before reusing it for this size bucket
    hash_groups=()

    # Now that we know 2+ files share this exact size, it's worth
    # paying the cost of computing MD5 checksums for just these files.
    for file in "${files_this_size[@]}"; do
        checksum=$(md5sum "$file" | cut -d ' ' -f 1)
        add_to_hash_group "$checksum" "$file"
    done

    # Get the list of distinct hashes found within this size bucket
    mapfile -t all_hashes < <(printf '%s\n' "${!hash_groups[@]}")

    for hash in "${all_hashes[@]}"; do
        # Turn this hash bucket's newline-separated string into an array
        mapfile -t dup_files <<< "${hash_groups[$hash]}"

        dup_count=${#dup_files[@]}

        # Same size but different MD5 -> just a coincidence, not a
        # duplicate. Skip this hash bucket.
        if [[ $dup_count -lt 2 ]]; then
            continue
        fi

        # Everything in this hash bucket is a byte-for-byte duplicate.
        # dup_files[0] is the "original" we keep. Delete every other
        # entry (index 1 onward).
        for ((i = 1; i < dup_count; i++)); do
            duplicate_path="${dup_files[$i]}"

            # Tally the freed space BEFORE actually deleting the file
            space_saved=$((space_saved + size))
            duplicates_found=$((duplicates_found + 1))

            rm -f "$duplicate_path"
        done
    done
done

# ---------------------------------------------------------------------
# STEP 5: Write the final report inside the target directory
# ---------------------------------------------------------------------
report_file="$target_dir/Report.txt"

{
    echo "Total files scanned: $total_files"
    echo "Duplicates found: $duplicates_found"
    echo "Space saved: $space_saved bytes"
} > "$report_file"

echo "Deduplication complete. Report written to $report_file"
