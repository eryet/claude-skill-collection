# Claude Skill Collection

A collection of reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills.

> Also check out the [Codex Skill Collection](https://github.com/eryet/codex-skill-collection) for OpenAI Codex equivalents.

## Skills

| Skill | Description |
|-------|-------------|
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

```
/waifu2x image.png
/waifu2x -d image.png          # use defaults, skip prompts
/waifu2x /path/to/folder       # batch mode
```

## Prerequisites

Each skill may have its own external dependencies:

- **waifu2x** - Requires [waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan) installed on your system

## Contributing

To add a new skill, create a folder under `.claude/skills/` with a `SKILL.md` file. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for the skill format.
