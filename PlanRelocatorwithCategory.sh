#!/usr/bin/bash
mkdir -p blueprints

heist=$1
mapfile -t cities < <(find "$heist" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")
declare -A evens

for city in "${cities[@]}"; do
    mapfile -t blueprints < <(find "${1}/${city}" -type f -name "*.dat" -printf "%f\n")
    for plan in "${blueprints[@]}"; do
        cp "${1}/$city/$plan" "blueprints/${city}_${plan}"
        num=${plan#*_}
        num=${num%.dat}
        category=${num#*_}
        num=${num%_*}
        num=$((10#$num))
        if [[ $((num % 2)) == 0 ]] ;then
            if [ ! ${evens[$category]+set} ]; then
                evens[$category]=1
            else
                evens[$category]=$(( evens[$category] + 1 ))
            fi 
        fi 
    done
done

: > summary.txt
for part in "${!evens[@]}"; do
    echo "$part: ${evens[$part]}"
done | sort >> summary.txt
