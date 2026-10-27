# Finds the dev servers that belong to a project, for statusline.sh (Windows).
#
#   -FindClaude <pid>
#       Prints the PID of the Claude Code process that <pid> runs under.
#
#   -Dir <project> -ClaudePid <pid> -Out <file>
#       Writes "label<TAB>url" for each listening TCP port that belongs to the
#       project, one per line, sorted by port. A port belongs to it when the
#       process listening on it either
#         - was started by a command this Claude Code session ran (it descends
#           from the session through one of its tool shells, not an MCP server), or
#         - names the project folder in its own command line (a server started
#           from another terminal, e.g. node_modules/.bin/vite or .venv/python).

param(
  [int]$FindClaude,
  [string]$Dir,
  [int]$ClaudePid,
  [string]$Out
)

$ErrorActionPreference = 'SilentlyContinue'

$procs = @{}
foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, CommandLine, CreationDate) {
  $procs[[int]$p.ProcessId] = $p
}

# The process's parent, unless its PID now belongs to a newer process.
function Get-Parent($p) {
  $parent = $procs[[int]$p.ParentProcessId]
  if ($parent -and $parent.ProcessId -ne $p.ProcessId -and $parent.CreationDate -le $p.CreationDate) { $parent }
}

# The native installer's claude.exe, or Node running the npm package.
function Test-Claude($p) {
  $p.Name -eq 'claude.exe' -or ($p.Name -eq 'node.exe' -and $p.CommandLine -match '@anthropic-ai[\\/]claude-code')
}

if ($FindClaude) {
  $p = $procs[$FindClaude]
  while ($p -and -not (Test-Claude $p)) { $p = Get-Parent $p }
  if ($p) { $p.ProcessId }
  return
}

$shells = 'bash.exe', 'sh.exe', 'cmd.exe', 'powershell.exe', 'pwsh.exe'

function Test-FromSession($p) {
  $child = $null
  for ($depth = 0; $p -and $depth -lt 40; $depth++) {
    if (Test-Claude $p) {
      return $p.ProcessId -eq $ClaudePid -and $child -and $shells -contains $child.Name.ToLowerInvariant()
    }
    $child = $p
    $p = Get-Parent $p
  }
  $false
}

# Command lines spell paths with either slash, in any case, or as /c/... from Git Bash.
function ConvertTo-Comparable([string]$s) { ($s.ToLowerInvariant().Replace('\', '/')) -replace '/+', '/' }
$dirPath = (ConvertTo-Comparable $Dir).TrimEnd('/')
$msysPath = '/' + $dirPath.Substring(0, 1) + $dirPath.Substring(2)
$namesDir = '(' + [regex]::Escape($dirPath) + '|' + [regex]::Escape($msysPath) + ')(?=$|[/"''\s])'

# A short name for the server: the script an interpreter runs (vite, astro,
# server, uvicorn), or the program itself.
$interpreters = 'node', 'bun', 'deno', 'python', 'python3', 'py', 'pythonw', 'ruby', 'php', 'java', 'dotnet'
function Get-Label($p) {
  $words = [regex]::Matches([string]$p.CommandLine, '"[^"]*"|\S+') | ForEach-Object { $_.Value.Trim('"') }
  $program = [IO.Path]::GetFileNameWithoutExtension($p.Name)
  if ($interpreters -contains $program.ToLowerInvariant()) {
    for ($i = 1; $i -lt $words.Count; $i++) {
      if ($words[$i] -eq '-m' -and $i + 1 -lt $words.Count) { return $words[$i + 1] }
      if (-not $words[$i].StartsWith('-')) { return [IO.Path]::GetFileNameWithoutExtension($words[$i]) }
    }
  }
  $program
}

$servers = @{}
foreach ($c in Get-NetTCPConnection -State Listen) {
  $p = $procs[[int]$c.OwningProcess]
  if (-not $p -or $servers.ContainsKey([int]$c.LocalPort)) { continue }
  $named = (ConvertTo-Comparable $p.CommandLine) -match $namesDir
  if (-not ($named -or (Test-FromSession $p))) { continue }
  # 127.0.0.1 only answers on IPv4; localhost covers ::1 and all addresses.
  $hostName = if ($c.LocalAddress -eq '127.0.0.1') { '127.0.0.1' } else { 'localhost' }
  $servers[[int]$c.LocalPort] = "$(Get-Label $p)`thttp://${hostName}:$($c.LocalPort)"
}

$lines = $servers.Keys | Sort-Object | ForEach-Object { $servers[$_] }
# Written whole and then moved into place, so statusline.sh never reads half a file.
$temp = "$Out.tmp"
[IO.File]::WriteAllText($temp, (($lines -join "`n") + $(if ($lines) { "`n" })), (New-Object Text.UTF8Encoding $false))
Move-Item -Force $temp $Out
