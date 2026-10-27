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

# Second line: the project's running dev servers as clickable links. A helper
# finds them: statusline-servers.ps1 on Windows (Git Bash), statusline-servers.sh
# on macOS and Linux. The scan takes up to a second, so it runs in the
# background every few seconds and this shows its last result. What runs on
# every refresh sticks to bash builtins: on Windows, each program started costs
# 15-30 ms. Also runs under macOS's bash 3.2.
script_dir=${BASH_SOURCE[0]%/*}
[ "$script_dir" = "${BASH_SOURCE[0]}" ] && script_dir=.
case "$OSTYPE" in
  msys* | cygwin*) helper="$script_dir/statusline-servers.ps1" ;;
  darwin* | linux*) helper="$script_dir/statusline-servers.sh" ;;
  *) exit 0 ;;
esac
[ -f "$helper" ] || exit 0

# Runs the helper. The Windows one takes Windows paths.
run_helper() {
  case "$helper" in
    *.ps1) powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$helper")" "$@" ;;
    *) bash "$helper" "$@" ;;
  esac
}
helper_path() {
  case "$helper" in
    *.ps1) cygpath -w "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

IFS=$'\t' read -r project_dir session < <(
  echo "$input" | jq -r '[.workspace.project_dir // .workspace.current_dir, .session_id // ""] | @tsv'
)
state_dir="${TMPDIR:-/tmp}/claude-statusline"
[ -d "$state_dir" ] || mkdir -p "$state_dir"
key=${session:-$(printf '%s' "$project_dir" | cksum | cut -d' ' -f1)}
servers="$state_dir/$key.servers"
claude_pid_file="$state_dir/$key.claude-pid"
stamp="$state_dir/$key.scanned"
lock="$state_dir/$key.lock"

# Claude Code's own process, found once per session: servers it starts descend
# from it. Windows loses track of the parent of a bash that Git Bash started, so
# there the search starts from the bash that Claude Code started, found through
# Git Bash's own chain of parents.
read -r claude_pid 2> /dev/null < "$claude_pid_file"
if [ -z "$claude_pid" ]; then
  start=$$
  case "$helper" in
    *.ps1)
      while read -r ppid 2> /dev/null < "/proc/$start/ppid" && [ "$ppid" -gt 1 ]; do start=$ppid; done
      read -r start < "/proc/$start/winpid"
      ;;
  esac
  claude_pid=$(run_helper -FindClaude "$start")
  claude_pid=${claude_pid%$'\r'}
  echo "${claude_pid:=0}" > "$claude_pid_file"
fi

# Rescan every 5 seconds, unless a scan is still running (the lock of a scan
# that never finished expires after a minute). bash 3.2 has no EPOCHSECONDS.
now=${EPOCHSECONDS:-$(date +%s)}
read -r scanned 2> /dev/null < "$stamp" || scanned=0
if ((now - scanned >= 60)) && [ -d "$lock" ]; then rmdir "$lock"; fi
if ((now - scanned >= 5)) && mkdir "$lock" 2> /dev/null; then
  echo "$now" > "$stamp"
  (
    run_helper -Dir "$(helper_path "$project_dir")" -ClaudePid "$claude_pid" -Out "$(helper_path "$servers")"
    rmdir "$lock"
    # Files of sessions that ended more than a day ago.
    find "$state_dir" -type f -mtime +1 -delete
  ) < /dev/null > /dev/null 2>&1 &
fi

esc=$'\033'
bel=$'\a'
links=''
# "● label url": a green dot (running, like the cache dot), then the label and
# the URL as one link. The URL keeps its http://: VS Code finds links by it.
add_link() { # label url
  [ -n "$2" ] || return
  links+="${links:+   }$esc[32m●$esc[00m $esc]8;;$2$bel${1:+$1 }$esc[90m$2$esc[00m$esc]8;;$bel"
}

if [ -f "$servers" ]; then
  while IFS=$'\t' read -r label url; do add_link "$label" "$url"; done < "$servers"
fi

# Plus any URLs listed in the project's .claude/statusline-urls ("label url" or
# just "url" per line, # for comments), for servers the scan can't see, such as
# Docker containers.
extra="$project_dir/.claude/statusline-urls"
if [ -f "$extra" ]; then
  while read -r first second _ || [ -n "$first" ]; do
    first=${first%$'\r'} second=${second%$'\r'}
    case "$first" in '' | '#'*) continue ;; esac
    if [ -n "$second" ]; then add_link "$first" "$second"; else add_link '' "$first"; fi
  done < "$extra"
fi

[ -n "$links" ] && printf '\n%s' "$links"
exit 0
