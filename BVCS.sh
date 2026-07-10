#!/usr/bin/bash

#alias bvcs='/home/ashfaq/314/BashScriptingOffline/2205029.sh'

usage() {
    echo "init              Initialize a new BVCS repository"
    echo "add <file>...     Stage one or more files for the next commit"
    echo "status            Show staged, modified, and untracked files"
    echo "commit -m <msg>   Save a snapshot of all staged files"
    echo "log               Display the full commit history"
    echo "diff [file]       Compare working copy to the latest commit. Compares all files if no file is specified."
    echo "restore <file>    Restore a file from the latest commit"
    echo "help              Print usage information for all subcommands"
}

check_repo() {
    if [ ! -d ".bvcs" ]; then
        echo "Error: Not a BVCS repository. Run 'init' first."
        exit 1
    fi
    return 0
}

init_repo() {
    if [ ! -d ".bvcs" ]; then
        ( 
        mkdir .bvcs
        cd .bvcs
        mkdir objects
        touch staging
        touch log
        touch HEAD
        )
        echo "Initialized empty BVCS repository."
    else
        echo "Error: BVCS repository already exists."
    fi
}

add_files() {
    if [ $# == 0 ]; then
        echo "Error: No files specified."
        exit 1
    fi

    for file in "$@"; do
        if [ -f "$file" ]; then
            norm="${file#./}"
            if grep -qxF "$norm" .bvcs/staging; then #ekhane qx dile string fixed thakena
                echo "Already staged: $norm"
            else
                echo "$norm" >> .bvcs/staging
                echo "Staged: $norm"
            fi
        else
            echo "Error: '$file' not found."
        fi
    done
}

show_status() {
    declare -A files
    st=0
    md=0
    ut=0
    mapfile -t staged < .bvcs/staging
    for file in "${staged[@]}"; do
        files["$file"]="staged"
        st=$((st + 1))
    done
    if [ -s ".bvcs/HEAD" ]; then
        ID=$(cat .bvcs/HEAD)
        prefix=".bvcs/objects/$ID/files/"
        mapfile -t headfiles < <(find ".bvcs/objects/$ID/files" -type f | sort)
        for fullpath in "${headfiles[@]}"; do
            relpath="${fullpath#$prefix}"
            if [ -f "$relpath" ]; then
                if [ "${files[$relpath]}" == "staged" ]; then
                    files["$relpath"]="staged"
                else
                    if ! diff -q "$fullpath" "$relpath" >/dev/null; then
                        files["$relpath"]="modified"
                        md=$((md + 1))
                    fi
                fi
            fi
        done     
    fi
    mapfile -t untracked < <(find . -type f ! -path './.bvcs/*')
    for w_file in "${untracked[@]}"; do
        rel_w_file="${w_file#./}"
        if [ -z "${files["$rel_w_file"]}" ]; then
            in_head=0
            if [ -s ".bvcs/HEAD" ]; then
                ID=$(cat .bvcs/HEAD)
                if [ -f ".bvcs/objects/$ID/files/$rel_w_file" ]; then
                    in_head=1
                fi
            fi
            
            if [ $in_head -eq 0 ]; then
                files["$rel_w_file"]="untracked"
                ut=$((ut + 1))
            fi
        fi
    done
    if [ ${#files[@]} -eq 0 ]; then
        echo "Nothing to commit, working tree clean."
    fi
    if [ $st -gt 0 ]; then
        echo "Staged for commit:"
        for file in "${staged[@]}"; do
            echo "  $file"
        done
        echo ""
    fi
    if [ $md -gt 0 ]; then
        echo "Modified (not staged):"
        for file in "${!files[@]}"; do
            if [ "${files[$file]}" == "modified" ]; then
                echo "  $file"
            fi
        done | sort
        echo ""
    fi
    if [ $ut -gt 0 ]; then
        echo "Untracked files:"
        for file in "${!files[@]}"; do
            if [ "${files[$file]}" == "untracked" ]; then
                echo "  $file"
            fi
        done  | sort
        echo ""  
    fi

}

do_commit(){
    msg="$2"
    if [ $# -eq 0 ] || [ $# -lt 2 ] || [ "$1" != "-m" ] || [ -z "$2" ]; then
        echo "Error: Commit message required. Use -m \"message\"."
        exit 1
    fi 
    if [ ! -s ".bvcs/staging" ]; then
        echo "Error: Nothing to commit."
        exit 1
    fi
    count=$(wc -l < .bvcs/log)
    ID=$((count + 1))
    filled=$(printf "%04d" $ID)
    mkdir -p ".bvcs/objects/$filled/files"
    if [ -s ".bvcs/HEAD" ]; then
        prev=$(cat .bvcs/HEAD 2>/dev/null)
        cp -r .bvcs/objects/$prev/files/. .bvcs/objects/$filled/files/ 2>/dev/null
    fi
    mapfile -t filenames < .bvcs/staging
    n=0
    for file in "${filenames[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Error: '$file' not found."
            continue
        fi
        dest=".bvcs/objects/$filled/files/$file"
        mkdir -p "$(dirname "$dest")"
        cp "$file" "$dest"    
        n=$((n + 1))
    done
    current_time=$(date +'%Y-%m-%d %H:%M:%S')
    (
        cd .bvcs/objects/$filled
        echo "$msg" > message
        echo "$current_time" > timestamp
    )
    echo "$filled|$current_time|$msg" >> .bvcs/log
    echo "$filled" > .bvcs/HEAD
    > .bvcs/staging
    echo "[$filled] $msg"
    echo "$n file(s) committed."
}

show_log(){
    if [ ! -s ".bvcs/log" ]; then
        echo "No commits yet."
        return
    fi
    mapfile -t log_entries < .bvcs/log
    reversed=()
    for (( i=${#log_entries[@]}-1; i>=0; i-- )); do
        reversed+=("${log_entries[i]}")
    done
    for entry in "${reversed[@]}"; do
        IFS='|' read -r commit_id timestamp message <<< "$entry"
        echo "commit $commit_id"
        echo "Date:     $timestamp"
        echo "Message:  $message"
        echo ""
    done
}

show_diff(){
    if [ ! -s .bvcs/HEAD ]; then
        echo "Error: No commits yet."
        return
    fi
    head=$(cat .bvcs/HEAD)
    if [ $# -eq 1 ]; then
        filename="$1"
        if [ ! -f ".bvcs/objects/$head/files/$filename" ]; then
            echo "Error: '$filename' is not tracked."
        else
            is_diff=$(diff -u ".bvcs/objects/$head/files/$filename" "$filename" 2>/dev/null)
            if [ -z "$is_diff" ]; then
                echo "$filename: no changes."
            else
                diff -u --label ".bvcs/objects/$head/files/$filename" --label "$filename" ".bvcs/objects/$head/files/$filename" "$filename"
            fi
        fi
    elif [ $# -eq 0 ]; then
        prefix=".bvcs/objects/$head/files/"
        mapfile -t filenames < <(find ".bvcs/objects/$head/files" -type f | sed "s|^$prefix||" | sort)
        for filename in "${filenames[@]}"; do
            is_diff=$(diff -u ".bvcs/objects/$head/files/$filename" "$filename" 2>/dev/null)
            if [ -z "$is_diff" ]; then
                echo "$filename: no changes."
            else
                diff -u --label ".bvcs/objects/$head/files/$filename" --label "$filename" ".bvcs/objects/$head/files/$filename" "$filename"
            fi
        done
    else
        echo "Error: command syntax: diff [file] or only diff (for all files)."
    fi
}

restore_file(){
    if [ $# -eq 0 ]; then
        echo "Error: No file specified."
        return
    fi
    if [ ! -s .bvcs/HEAD ]; then
        echo "Error: No commits yet."
        return
    fi
    head=$(cat .bvcs/HEAD)
    if [ $# -eq 1 ]; then
        filename="$1"
        if [ ! -f ".bvcs/objects/$head/files/$filename" ]; then
            echo "Error: '$filename' not found in commit $head."
        else
            echo -n "Restore '$filename' from commit $head? [y/N]: "
            read -r response
            if [ "$response" == "y" ] || [ "$response" == "Y" ]; then
                mkdir -p "$(dirname "$filename")"
                cp ".bvcs/objects/$head/files/$filename" "$filename"
                echo "Restored: $filename"
            elif [ "$response" == "n" ] || [ "$response" == "N" ]; then
                echo "Aborted."
            else
                echo "Invalid response. Aborted."
            fi
        fi
    
    else
        echo "Error: command syntax: restore <file>"
    fi

}

if [ "${1}" == "init" ]; then
    init_repo
elif [ "${1}" == "help" ]; then
    usage
elif [ "${1}" == "add" ]; then
    if check_repo; then
        add_files "${@:2}"
    fi
elif [ "${1}" == "status" ]; then
    if check_repo; then
        show_status
    fi
elif [ "${1}" == "commit" ]; then
    if check_repo; then
        do_commit "${@:2}"
    fi
elif [ "${1}" == "log" ]; then
    if check_repo; then
        show_log
    fi
elif [ "${1}" == "diff" ]; then
    if check_repo; then
        show_diff "${@:2}"
    fi
elif [ "${1}" == "restore" ]; then
    if check_repo; then
        restore_file "${@:2}"
    fi
else
    echo "Error: Unknown subcommand '${1}'." 
    exit 1 
fi

