#!/usr/bin/env bash

# Script to display used space of LXC containers in Proxmox, excluding templates

echo -e "\033[1mChecking all LXC containers...\033[0m"

# Function to convert to gigabytes and round to the second most significant digit
convert_and_round_gb() {
  local value=$1
  local unit=${value: -1}
  local number=${value%?}

  case $unit in
    T) echo $(awk "BEGIN {printf \"%.2f\", $number*1024}") ;; # Terabytes to gigabytes
    G) echo $(awk "BEGIN {printf \"%.2f\", $number}") ;; # Already in gigabytes
    M) echo $(awk "BEGIN {printf \"%.2f\", $number/1024}") ;; # Megabytes to gigabytes
    K) echo $(awk "BEGIN {printf \"%.2f\", $number/1024/1024}") ;; # Kilobytes to gigabytes
    *) echo $(awk "BEGIN {printf \"%.2f\", $number}") ;; # Assume gigabytes if no unit
  esac
}

# Function to process and format the output of pct df
process_and_format_output() {
  local container_id=$1
  # Correct approach to retrieve container name
  local container_name=$(pct config "$container_id" | grep 'hostname:' | awk '{print $2}')

  # Skip the container if it is a template without printing a message
  if pct config "$container_id" | grep -q "template: 1"; then
    return
  fi

  # Apply green color to the title part, with container name in blue
  echo -e "\n\033[1;32m[Info] Checking used space for container \033[1;34m$container_name\033[1;32m ($container_id)\033[0m"

  while IFS= read -r line; do
    if [[ $line != MP* ]]; then
      local volume=$(echo $line | awk '{print $1}')
      local size=$(convert_and_round_gb "$(echo $line | awk '{print $3}')")
      local used=$(convert_and_round_gb "$(echo $line | awk '{print $4}')")
      local avail=$(convert_and_round_gb "$(echo $line | awk '{print $5}')")
      local usep=$(awk "BEGIN {printf \"%.0f\", ($used/$size)*100}")

      # Apply formatting based on use percentage
      local color_start="" local color_end="\033[0m"
      if [ "$usep" -gt 50 ]; then
        color_start="\033[1;31m" # Red and bold if usage > 50%
      fi

      echo -e "\033[1;34m[$volume]\033[0m - Used: ${used}G, Total: ${size}G, Free: ${avail}G, ${color_start}Use%: ${usep}%${color_end} - \033[1m$(echo $line | awk '{print $7}')\033[0m"
    fi
  done < <(pct df "$container_id")
}

# Loop through all containers
for container in $(pct list | awk '{if(NR>1) print $1}'); do
  process_and_format_output "$container"
done

echo -e "\n\033[1mFinished checking all containers.\033[0m"
