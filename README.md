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
- **Context usage %** — color-coded green/yellow/red
- **Cache indicator** — green dot for cache hit, red dot for miss

### Install

```bash
# Copy to your Claude config
cp .claude/statusline.sh ~/.claude/statusline.sh
```

Then set `"statusline": "~/.claude/statusline.sh"` in your Claude Code settings.

## Prerequisites

Each skill may have its own external dependencies:

- **background-removal** - Requires Python 3.8+ with `Pillow` and `numpy`. The ML path additionally needs `rembg` and `onnxruntime` (`pip install --user rembg onnxruntime`); the ONNX model downloads to `~/.u2net/` on first use (~170 MB). `scipy` is optional but speeds up flood-fill on large images.
- **generate-palette** - No external dependencies (uses built-in web tools for color research)
- **realupscale** - Requires one or both of [realcugan-ncnn-vulkan](https://github.com/nihui/realcugan-ncnn-vulkan/releases) (recommended for illustration/anime/web art) and [realesrgan-ncnn-vulkan](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases) (recommended for photos/general). Download the prebuilt zip for your platform (Windows x64, macOS arm64, or Ubuntu) — no install needed, just unzip and point the skill at the executable on first run.
- **waifu2x** - Requires [waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan) installed on your system
