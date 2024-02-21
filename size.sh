#!/usr/bin/env bash

echo -e "\033[1mChecking all LXC containers...\033[0m"

# Function to convert to gigabytes and ensure rounding
convert_and_round_gb() {
  local value=$1
  # Handle different units explicitly
  case ${value: -1} in
    T) echo $(echo "$value" | awk '{printf "%.2f", substr($0, 1, length($0)-1) * 1024}') ;;
    G) echo $(echo "$value" | awk '{printf "%.2f", substr($0, 1, length($0)-1)}') ;;
    M) echo $(echo "$value" | awk '{printf "%.2f", substr($0, 1, length($0)-1) / 1024}') ;;
    K) echo $(echo "$value" | awk '{printf "%.4f", substr($0, 1, length($0)-1) / 1024 / 1024}') ;;
    *) echo $(echo "$value" | awk '{printf "%.2f", $0}') ;; # Assuming direct GB input without unit
  esac
}

# Function to process and format the output of pct df
process_and_format_output() {
  local container_id=$1
  local container_name=$(pct config "$container_id" | grep 'hostname:' | awk '{print $2}')

  # Skip template containers silently
  if pct config "$container_id" | grep -q "template: 1"; then return; fi

  echo -e "\n\033[1;32m[Info] Checking used space for container \033[1;34m$container_name\033[1;32m ($container_id)\033[0m"

  # Use a safer approach to read line by line and avoid syntax issues
  pct df "$container_id" | tail -n +2 | while read -r line; do
    volume=$(echo "$line" | awk '{print $1}')
    size=$(convert_and_round_gb "$(echo "$line" | awk '{print $3}')")
    used=$(convert_and_round_gb "$(echo "$line" | awk '{print $4}')")
    avail=$(convert_and_round_gb "$(echo "$line" | awk '{print $5}')")
    usep=$(echo "$used" "$size" | awk '{if ($2 > 0) printf "%.0f", ($1/$2)*100; else print "0"}')

    # Determine color for use percentage
    color_start="\033[0m" # Default no color
    [[ "$usep" -gt 50 ]] && color_start="\033[1;31m" # Red for >50%

    echo -e "\033[1;34m[$volume]\033[0m - Used: ${used}G, Total: ${size}G, Free: ${avail}G, ${color_start}Use%: ${usep}%\033[0m - \033[1m$(echo "$line" | awk '{print $NF}')\033[0m"
  done
}

for container in $(pct list | awk '{if(NR>1) print $1}'); do
  process_and_format_output "$container"
done

echo -e "\n\033[1mFinished checking all containers.\033[0m"
