#!/usr/bin/bash

morning=0
afternoon=0
evening=0

mapfile -t photos < <(find "files/photos_input" -type f -iname "*.jpg" -printf "%f\n")

mkdir -p "files/output/morning"
mkdir -p "files/output/afternoon"
mkdir -p "files/output/evening"

for file in "${photos[@]}";do
    time="${file##*_}" #strip till the last _
    time="${time%.jpg}" #strip from the last .jpg
    hour="${time:0:2}"
    hour=$((10#$hour)) #for base 10 representation
    if [[ $hour -ge 00 && $hour -lt 12 ]]; then
        folder="morning"
        morning=$((morning + 1))
    elif [[ $hour -ge 12 && $hour -lt 18 ]]; then
        folder="afternoon"
        afternoon=$((afternoon + 1))
    else
        folder="evening"
        evening=$((evening + 1))
    fi
    cp "files/photos_input/$file" "files/output/$folder/${folder}_${file}"

done

echo "morning: $morning">>"files/cnt.txt"
echo "afternoon: $afternoon">>"files/cnt.txt"
echo "evening: $evening">>"files/cnt.txt"
