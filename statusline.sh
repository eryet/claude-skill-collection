#!/bin/bash

# Read JSON input once
input=$(cat)

# Extract current directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

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

  printf '\033[01;36m%s\033[00m | ctx: %b%s%%\033[00m | cache: %b' \
    "$repo_name" "$ctx_color" "$ctx_pct" "$cache_indicator"
else
  printf '\033[01;36m%s\033[00m | ctx: %s%% | cache: %b' "$cwd" "$ctx_pct" "$cache_indicator"
fi
