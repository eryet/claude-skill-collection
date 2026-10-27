# Claude Skill Collection

A collection of reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills.

> Also check out the [Codex Skill Collection](https://github.com/eryet/codex-skill-collection) for OpenAI Codex equivalents.

## Skills

| Skill | Description |
|-------|-------------|
| [background-removal](.claude/skills/background-removal/SKILL.md) | Remove the background from an image (file or folder) and write a transparent PNG. Auto-routes between corner flood-fill and `rembg` ML segmentation |
| [generate-palette](.claude/skills/generate-palette/skill.md) | Generate professional, interactive SVG color palette reference sheets from a theme, URL, or hex colors |
| [realupscale](.claude/skills/realupscale/SKILL.md) | Upscale images locally with realcugan-ncnn-vulkan (illustration/anime) or realesrgan-ncnn-vulkan (photos/general). Cross-platform, single file or folder batch |
| [waifu2x](.claude/skills/waifu2x/SKILL.md) | Upscale images using waifu2x-ncnn-vulkan with configurable scale, noise, model, format, and tile size |

## Usage

### Install a skill

Copy the skill folder into your Claude Code skills directory:

```bash
# Project-level (recommended)
cp -r .claude/skills/waifu2x /path/to/your/project/.claude/skills/

# User-level (available globally)
cp -r .claude/skills/waifu2x ~/.claude/skills/
```

### Invoke a skill

Once installed, invoke it in Claude Code:

#### `/generate-palette`

```
/generate-palette Ocean Blue                        # from a theme description
/generate-palette https://example.com/brand-guide   # from a URL
/generate-palette #FF6B6B #4ECDC4 #2C3E50           # from hex colors
```

#### `/waifu2x`

```
/waifu2x image.png              # single image
/waifu2x -d image.png           # use defaults, skip prompts
/waifu2x /path/to/folder        # batch mode
```

#### `/realupscale`

```
/realupscale image.png              # asks which model family (realcugan / realesrgan)
/realupscale -d image.png           # use defaults (realcugan, 2x), skip prompts
/realupscale /path/to/folder        # batch mode
```

#### `/background-removal`

```
/background-removal logo.png                      # single image, auto method
/background-removal photo.jpg --method rembg      # force ML segmentation
/background-removal /path/to/folder               # batch mode
/background-removal logo.png --tolerance 45 --feather 2   # tune flood-fill
```

## Statusline

A custom Claude Code [statusline script](.claude/statusline.sh) that displays:

- **Repo name** (cyan) or current directory if not in a git repo
- **Model name** (magenta) with the current **effort level** (blue, e.g. `[xhigh]`) next to it
- **Context usage %** — color-coded green/yellow/red
- **Cache indicator** — green dot for cache hit, red dot for miss

A second line lists the project's running dev servers as clickable links (Ctrl+click on Windows, Cmd+click on macOS), for example `● astro http://localhost:4321   ● server http://127.0.0.1:4400`: a green dot for each running server, its name, and its URL in grey. A helper finds them in the background every few seconds: [statusline-servers.ps1](.claude/statusline-servers.ps1) on Windows (Git Bash), [statusline-servers.sh](.claude/statusline-servers.sh) on macOS and Linux. A listening port counts when the process behind it was started by the Claude Code session, through one of its shells (`pnpm dev`, `npm run dev`, `uvicorn` and the like, frontend and backend alike), or when it was started elsewhere but belongs to the project:

- **Windows:** its command line names the project folder (`node_modules/.bin/vite`, `.venv/Scripts/python`).
- **macOS and Linux:** it runs in the project folder or below it, which also catches a bare `node server.ts`.

Claude Code's own MCP servers never count.

For servers the scan can't see, such as Docker containers, list them in the project's `.claude/statusline-urls`, one per line, with or without a label:

```
# label url, or just a url
api http://localhost:8000
http://localhost:9000
```

### Install

```bash
# Copy to your Claude config: the .ps1 is used on Windows, the .sh helper on macOS and Linux
cp .claude/statusline.sh .claude/statusline-servers.ps1 .claude/statusline-servers.sh ~/.claude/
```

Then point your Claude Code settings (`~/.claude/settings.json`) at it. `refreshInterval` re-runs it every 5 seconds, so servers appear and disappear without waiting for the next message:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline.sh",
  "refreshInterval": 5
}
```

Requires `jq` (`brew install jq` on macOS). The server line uses Windows PowerShell on Windows, and `ps` and `lsof` on macOS and Linux (both built into macOS; some Linux distributions need `lsof` installed). Without them, or on other systems, the status line is the single line above. The scripts run under the bash 3.2 that ships with macOS. Links are clickable in terminals that support them, such as VS Code's, iTerm2, Windows Terminal, Kitty and WezTerm.

## Prerequisites

Each skill may have its own external dependencies:

- **background-removal** - Requires Python 3.8+ with `Pillow` and `numpy`. The ML path additionally needs `rembg` and `onnxruntime` (`pip install --user rembg onnxruntime`); the ONNX model downloads to `~/.u2net/` on first use (~170 MB). `scipy` is optional but speeds up flood-fill on large images.
- **generate-palette** - No external dependencies (uses built-in web tools for color research)
- **realupscale** - Requires one or both of [realcugan-ncnn-vulkan](https://github.com/nihui/realcugan-ncnn-vulkan/releases) (recommended for illustration/anime/web art) and [realesrgan-ncnn-vulkan](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases) (recommended for photos/general). Download the prebuilt zip for your platform (Windows x64, macOS arm64, or Ubuntu) — no install needed, just unzip and point the skill at the executable on first run.
- **waifu2x** - Requires [waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan) installed on your system
