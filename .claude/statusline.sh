#!/bin/bash

# Read JSON input once
input=$(cat)

# Extract current directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Extract current model name
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# Extract effort level (absent on older versions / models without effort)
effort=$(echo "$input" | jq -r '.effort.level // empty')
if [ -n "$effort" ]; then
  effort_str=" \033[01;34m[$effort]\033[00m"
else
  effort_str=''
fi

# Extract context percentage
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Extract cache tokens (null before first API call)
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

# Cache indicator: green dot = cache hit, red dot = cache miss/cold
if [ "$cache_read" -gt 0 ]; then
  cache_indicator='\033[32m●\033[00m'
else
  cache_indicator='\033[31m●\033[00m'
fi

# Git information
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  repo_name=$(basename "$cwd")

  # Color the context percentage based on usage
  if [ "$ctx_pct" -ge 60 ]; then
    ctx_color='\033[01;31m' # red
  elif [ "$ctx_pct" -ge 40 ]; then
    ctx_color='\033[01;33m' # yellow
  else
    ctx_color='\033[01;32m' # green
  fi

  printf '\033[01;36m%s\033[00m | \033[01;35m%s\033[00m%b | ctx: %b%s%%\033[00m | cache: %b' \
    "$repo_name" "$model" "$effort_str" "$ctx_color" "$ctx_pct" "$cache_indicator"
else
  printf '\033[01;36m%s\033[00m | \033[01;35m%s\033[00m%b | ctx: %s%% | cache: %b' \
    "$cwd" "$model" "$effort_str" "$ctx_pct" "$cache_indicator"
fi
