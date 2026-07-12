#!/usr/bin/bash


if [ $# -ne 1 ]; then
    echo "Usage: ./create_academic_dirs.sh <input_file>"
    exit 1
fi

input_file=$1
main_dir="Academic Materials"
mkdir -p "$main_dir"

# Read the input file line by line
while read -r line; do
    # Extract course code, level and term
    course_code=$(echo "$line" | cut -d' ' -f1-2)
    level=$(echo "$line" | cut -d' ' -f2 | cut -c1)
    term=$(echo "$line" | cut -d' ' -f3 | cut -d'-' -f2)
    term_dir="L${level}T${term}"

    mkdir -p "$main_dir/$term_dir"

    # Extract the course number from the course code (second part of course code)
    course_number=$(echo "$line" | cut -d' ' -f2)

    if ((course_number % 2 == 1)); then
        mkdir -p "$main_dir/$term_dir/$course_code"
    else
        mkdir -p "$main_dir/$term_dir/LABS/$course_code"
    fi
done < "$input_file"

echo "Directory structure created successfully."
