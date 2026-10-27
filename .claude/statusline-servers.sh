#!/bin/bash

# Finds the dev servers that belong to a project, for statusline.sh (macOS,
# Linux; statusline-servers.ps1 does the same on Windows, with the same switches).
#
#   -FindClaude <pid>
#       Prints the PID of the Claude Code process that <pid> runs under.
#
#   -Dir <project> -ClaudePid <pid> -Out <file>
#       Writes "label<TAB>url" for each listening TCP port that belongs to the
#       project, one per line, sorted by port. A port belongs to it when the
#       process listening on it either
#         - was started by a command this Claude Code session ran (it descends
#           from the session through one of its shells), or
#         - runs in the project folder or below it (its working directory),
#       but never when it is Claude Code itself or one of its MCP servers.
#
# Needs ps and lsof. Written for the bash 3.2 and awk that come with macOS.

while [ $# -ge 2 ]; do
  case "$1" in
    -FindClaude) find_claude=$2 ;;
    -Dir) dir=$2 ;;
    -ClaudePid) claude_pid=$2 ;;
    -Out) out=$2 ;;
  esac
  shift
  shift
done

# Shared by both modes: load_ps reads a line of
# `ps -A -o pid= -o ppid= -o command=` into parent[] and command[].
lib='
function load_ps() {
  parent[$1] = $2
  pid = $1
  sub(/^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]*/, "")
  command[pid] = $0
}
# The program a command runs, without its folder or the "-" of a login shell.
function program(c,    w) {
  split(c, w, "[ \t]+")
  sub(/.*\//, "", w[1])
  sub(/^-/, "", w[1])
  return w[1]
}
# Claude Code: the native install, or Node running the npm package.
function is_claude(p,    c) {
  c = command[p]
  return program(c) == "claude" || c ~ /@anthropic-ai\/claude-code/ || c ~ /\/claude\/versions\//
}
'

if [ -n "$find_claude" ]; then
  ps -A -o pid= -o ppid= -o command= | awk -v start="$find_claude" "$lib"'
    { load_ps() }
    END {
      p = start
      for (depth = 0; depth < 40 && p > 1; depth++) {
        if (is_claude(p)) { print p; exit }
        p = parent[p]
      }
    }'
  exit 0
fi

[ -n "$dir" ] && [ -n "$out" ] || exit 1
tmp="$out.tmp"

# lsof reports real paths (/private/tmp, not /tmp).
real_dir=$(cd "$dir" 2> /dev/null && pwd -P) || real_dir=$dir

listening=''
if command -v lsof > /dev/null 2>&1; then
  listening=$(lsof -nP -iTCP -sTCP:LISTEN -F pn 2> /dev/null)
fi
pids=$(printf '%s\n' "$listening" | sed -n 's/^p//p' | sort -u | paste -s -d , -)

if [ -z "$pids" ]; then
  : > "$tmp"
else
  {
    echo '## ps'
    ps -A -o pid= -o ppid= -o command=
    echo '## listen'
    printf '%s\n' "$listening"
    echo '## cwd'
    lsof -a -p "$pids" -d cwd -F pn 2> /dev/null
  } | awk -v dir="${real_dir%/}" -v claude="${claude_pid:-0}" "$lib"'
    /^## / { section = $2; next }
    section == "ps" { load_ps(); next }
    # lsof -F prints a "p<pid>" line, then an "n<name>" line per file: the
    # address:port of a socket, or the folder for -d cwd.
    /^p/ { pid = substr($0, 2); next }
    section == "listen" && /^n/ {
      address = substr($0, 2)
      port = address; sub(/.*:/, "", port)
      host = address; sub(/:[0-9]+$/, "", host)
      if (!(port in owner)) { owner[port] = pid; listen_host[port] = host }
      next
    }
    section == "cwd" && /^n/ { cwd[pid] = substr($0, 2); next }

    function in_project(p) {
      return cwd[p] == dir || index(cwd[p], dir "/") == 1
    }
    function belongs(p,    q, child, depth) {
      child = ""
      for (q = p; depth < 40 && q > 1; depth++) {
        if (is_claude(q)) {
          # Claude Code itself, or something it started without a shell (an MCP server).
          if (child == "" || program(command[child]) !~ /^(bash|zsh|sh|dash|fish)$/) return 0
          return q == claude || in_project(p)
        }
        child = q
        q = parent[q]
      }
      return in_project(p)
    }
    # A short name for the server: the script an interpreter runs (vite,
    # astro, server, uvicorn), or the program itself.
    function label(p,    w, n, i, name) {
      n = split(command[p], w, "[ \t]+")
      name = program(command[p])
      if (tolower(name) ~ /^(node|bun|deno|python[0-9.]*|ruby|php|java|dotnet)$/) {
        for (i = 2; i <= n; i++) {
          if (w[i] == "-m" && i < n) return w[i + 1]
          if (w[i] !~ /^-/) {
            sub(/.*\//, "", w[i])
            sub(/\.[^.]*$/, "", w[i])
            return w[i]
          }
        }
      }
      return name
    }

    END {
      for (port in owner) {
        p = owner[port]
        if (!belongs(p)) continue
        # 127.0.0.1 only answers on IPv4; localhost covers ::1 and all addresses.
        host = listen_host[port] == "127.0.0.1" ? "127.0.0.1" : "localhost"
        print port "\t" label(p) "\thttp://" host ":" port
      }
    }' | sort -n | cut -f 2- > "$tmp"
fi

# Written whole and then moved into place, so statusline.sh never reads half a file.
mv -f "$tmp" "$out"
