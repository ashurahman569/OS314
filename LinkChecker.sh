#!/usr/bin/bash
#
# Website Link Integrity Checker
# Usage: ./checklinks.sh <directory> [cache_file_path]

dir="$1"
cache_file="${2:-cache.txt}"

if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "Usage: $0 <directory> [cache_file_path]" >&2
    exit 1
fi

declare -A cache_ts     # path -> previously stored mtime (loaded from cache_file)
declare -A new_ts       # path -> mtime to write back this run
declare -A broken_count # path -> broken link count (only for files actually checked)

total_files=0
files_checked=0
cache_hits=0
cache_misses=0
total_links=0
total_broken=0

# 1. Load existing cache (path:timestamp per line), skipping the header
if [[ -f "$cache_file" ]]; then
    while IFS=':' read -r path ts; do
        [[ "$path" == "Cache File"* ]] && continue
        [[ -z "$path" ]] && continue
        cache_ts["$path"]="$ts"
    done < "$cache_file"
fi

# 2. Collect all HTML files under the target directory
mapfile -t html_files < <(find "$dir" -type f -iname "*.html")

for file in "${html_files[@]}"; do
    total_files=$((total_files + 1))
    mtime=$(stat --format=%Y "$file")

    # Cache hit: file already scanned and unchanged since then
    if [[ -n "${cache_ts[$file]+set}" && "${cache_ts[$file]}" == "$mtime" ]]; then
        cache_hits=$((cache_hits + 1))
        new_ts["$file"]="$mtime"
        continue
    fi

    # Cache miss: file is new or modified, so check its links
    cache_misses=$((cache_misses + 1))
    files_checked=$((files_checked + 1))
    new_ts["$file"]="$mtime"

    broken=0
    file_dir="$(dirname "$file")"

    # Extract href targets from <a ...href="...">  tags only
    while IFS= read -r href; do
        [[ -z "$href" ]] && continue
        # Skip external links, mailto, and pure page-fragment links
        [[ "$href" =~ ^(https?:|mailto:|ftp:|//|#) ]] && continue

        target="${href%%#*}"   # drop any trailing #fragment
        [[ -z "$target" ]] && continue

        total_links=$((total_links + 1))
        resolved="$file_dir/$target"

        if [[ ! -f "$resolved" ]]; then
            broken=$((broken + 1))
        fi
    done < <(grep -oE '<a[^>]*href="[^"]*"' "$file" | sed -E 's/.*href="([^"]*)".*/\1/' | sort -u)

    broken_count["$file"]="$broken"
    total_broken=$((total_broken + broken))
done

scan_time="$(date '+%Y-%m-%d %H:%M:%S')"

# 3. Write the updated cache file
{
    echo "Cache File - Last updated: $scan_time"
    for path in "${!new_ts[@]}"; do
        echo "$path:${new_ts[$path]}"
    done | sort
} > "$cache_file"

# 4. Print the report
echo "Scan time: $scan_time"
echo "Directory: $(realpath "$dir")"
echo
echo "BROKEN LINK COUNTS:"
for path in "${!broken_count[@]}"; do
    echo "$path: ${broken_count[$path]}"
done | sort
echo
echo "STATISTICS:"
echo "Total HTML files scanned: $total_files"
echo "Files checked: $files_checked ($cache_hits from cache)"
echo "Total internal links: $total_links"
echo "Broken links: $total_broken"
echo
echo "CACHE SUMMARY:"
echo "Cache hits: $cache_hits"
echo "Cache misses: $cache_misses"
