---
name: realupscale
description: Upscale images locally with realcugan-ncnn-vulkan (illustration/anime) or realesrgan-ncnn-vulkan (photos/general). Cross-platform (Windows + macOS arm64 + Linux), supports single file or folder batch, with configurable scale, noise/model variant, format, and tile size.
argument-hint: [-default] [image-path-or-folder]
allowed-tools: Bash, Read, Glob, Write, AskUserQuestion
---

# Upscale Image(s) with realcugan / realesrgan

You are helping the user upscale one or more images using either `realcugan-ncnn-vulkan` (best for anime, line art, web illustrations) or `realesrgan-ncnn-vulkan` (best for photos and general content, also has an anime variant). The input can be a single image file or a folder of images. The skill must work on Windows, macOS (Apple Silicon), and Linux — never hardcode `.exe` or platform-specific paths; use whatever executable path is resolved or saved in memory.

## Step 0: Check for default flag

Check if `$ARGUMENTS` contains `-d` or `--default`. If it does, enable **quick mode**: skip all prompts and use these defaults:

- Model family: `realcugan`
- Scale: 2
- Noise: -1 (off)
- Model variant: `models-se`
- Format: `png`
- Tile: 0 (auto)

Remove the `-d` / `--default` flag from the arguments before proceeding — any remaining text is treated as the image/folder path.

## Step 1: Get the input path

Determine the input path using the following priority:

1. **From `$ARGUMENTS`**: If provided (after removing any flags), use that as the input path.
2. **From a pasted image**: If the user pasted an image, look for the source path in the image metadata (e.g., `[Image: source: <path>]`).
3. **From the user's message**: Check if the user's message contains a file or folder path.
4. **Ask the user**: If none of the above yielded a path, ask the user for the path.

### Determine if path is a file or folder

- **File**: Verify it exists. Proceed in single-image mode.
- **Directory**: Use Glob to find all image files matching `*.{png,jpg,jpeg,webp,bmp,tga}` (non-recursive). Skip any files whose names contain `_realcugan_` or `_realesrgan_` to avoid re-processing previous outputs. If no images found, tell the user and stop. Otherwise proceed in **batch mode**.

## Step 2: Choose model family and options

**If quick mode is enabled (from Step 0), skip this step entirely and use the defaults.**

Otherwise, first ask which model family to use with AskUserQuestion:

- **realcugan (Recommended)** — best for anime, line art, illustrations, web art
- **realesrgan** — best for photos and general content (also has an anime variant)

Then ask whether to use that family's defaults or customize.

### realcugan defaults
- Scale: 2, Noise: -1 (off), Variant: `models-se`, Format: `png`, Tile: 0

### realcugan customization options
- **Scale**: 2 (default), 3, 4
- **Noise / denoise level** (`-n`): `-1` = none (default), `0`, `1`, `2`, `3` — higher = stronger denoise (can over-smooth)
- **Model variant** (passed via `-m`): `models-se` (default), `models-pro`, `models-nose`
- **Output format**: `png` (default), `jpg`, `webp`
- **Tile size**: 0 = auto (default), 32, 64, 128, 256 — lower uses less VRAM

### realesrgan defaults
- Model: `realesrgan-x4plus`, Scale: 4, Format: `png`, Tile: 0

### realesrgan customization options
- **Model name** (`-n`):
  - `realesr-animevideov3` — anime / illustration (supports scale 2, 3, 4)
  - `realesrgan-x4plus` (default) — photos, general (4x only)
  - `realesrgan-x4plus-anime` — anime art (4x only)
  - `realesr-general-x4v3` — general purpose v3 (4x only)
- **Scale** (`-s`): 4 for `x4plus` / `x4plus-anime` / `general-x4v3`; choose 2/3/4 for `animevideov3`
- **Output format**: `png` (default), `jpg`, `webp`
- **Tile size**: 0 = auto (default), 32, 64, 128, 256

If the user picks a scale that conflicts with the chosen realesrgan model (e.g., scale 2 with `realesrgan-x4plus`), warn and fall back to 4.

## Step 3: Locate the executable

The skill uses **two separate reference memories**, one per binary:

- `reference_realcugan_path.md` — path to `realcugan-ncnn-vulkan` executable
- `reference_realesrgan_path.md` — path to `realesrgan-ncnn-vulkan` executable

Only the memory file for the chosen family needs to be resolved this run.

Resolution order:

1. **Memory**: If the relevant memory file exists, read the saved path and verify the executable still exists at that location. If it does, use it and skip the rest of this step.
2. **PATH**: Try running the bare command (`realcugan-ncnn-vulkan` or `realesrgan-ncnn-vulkan`) to see if it's on PATH. If it runs, use that path and save it to the memory file.
3. **Prompt the user** with AskUserQuestion — "I couldn't find `<binary>` on this machine. Do you already have it installed somewhere?":
   - **Yes, I'll give you the path** → ask for the full path to the executable (on Windows this will end in `.exe`; on macOS/Linux it's a bare binary — do not assume). Verify it exists, then save it to memory.
   - **No, please install it for me** → run the auto-install flow described in **Step 3a** below.

Once a working path is obtained, save it to the appropriate memory file (type: reference) so it can be reused.

When invoking the executable with a full path, also pass the model directory as a full path relative to the executable's folder (e.g., `<exec-dir>/models-se` for realcugan, or the bundled `models` dir for realesrgan).

## Step 3a: Auto-install flow

Run this only if the user picked "No, please install it for me" in Step 3.

### Pick the install directory

Use a platform-appropriate, non-intrusive location:

- **Windows**: `%LOCALAPPDATA%\realupscale\` (i.e. `C:\Users\<user>\AppData\Local\realupscale\`)
- **macOS / Linux**: `~/.local/share/realupscale/`

Create the directory if it doesn't exist.

### Pick the right release asset

Fetch the latest release from the GitHub API:

- **realcugan-ncnn-vulkan** → `https://api.github.com/repos/nihui/realcugan-ncnn-vulkan/releases/latest`
- **realesrgan-ncnn-vulkan** → `https://api.github.com/repos/xinntao/Real-ESRGAN-ncnn-vulkan/releases/latest`

From the `assets` list, pick the asset whose name matches the current platform:

- Windows → asset name contains `windows`
- macOS → asset name contains `macos`
- Linux → asset name contains `ubuntu` or `linux`

If no matching asset exists, stop and tell the user to install manually.

### Download and extract

1. Download the zip with `curl -L -o <install-dir>/<asset-name>` (the file is ~40–60 MB; do not background it — wait for it to finish).
2. Extract it into `<install-dir>/`:
   - **Windows**: `Expand-Archive -Path <zip> -DestinationPath <install-dir> -Force` via PowerShell
   - **macOS / Linux**: `unzip -o <zip> -d <install-dir>`
3. Most releases extract into a versioned subfolder (e.g. `realcugan-ncnn-vulkan-20220728-windows/`). Locate the executable inside that subfolder — it'll be `realcugan-ncnn-vulkan(.exe)` or `realesrgan-ncnn-vulkan(.exe)`.
4. On macOS/Linux, make sure the binary is executable: `chmod +x <path>`.
5. (Optional) Delete the downloaded zip to save space.

### Save and verify

Write a reference memory (`reference_realcugan_path.md` or `reference_realesrgan_path.md`) containing the absolute path to the executable and the model directory location, then proceed with Step 4. Tell the user what was installed and where.

## Step 4: Run the upscaler

### Output naming

- **realcugan**: `<original-name>_realcugan_<scale>x.<format>`
- **realesrgan**: `<original-name>_realesrgan_<scale>x_<model-name>.<format>`
  (e.g., `photo_realesrgan_4x_x4plus.png`)

Place each output file in the same directory as its input.

### Command shapes

**realcugan-ncnn-vulkan:**

```
<exec> -i "<input>" -o "<output>" -s <scale> -n <noise> -m "<model-dir>" -f <format> -t <tile>
```

**realesrgan-ncnn-vulkan:**

```
<exec> -i "<input>" -o "<output>" -s <scale> -n <model-name> -f <format> -t <tile>
```

Note: in realesrgan the `-n` flag is the **model name**, not a noise level. In realcugan `-n` is the noise level and `-m` is the model variant directory.

### Single-image mode

Run the command once with the resolved settings.

### Batch mode (folder)

Process each image in the folder sequentially. Print a progress line per image (e.g., `[1/5] Done: image1.png`). If a single image fails, log the error and continue with the remaining images — do not stop the entire batch.

## Step 5: Report results

### Single-image mode
- On success: tell the user the output file path and its file size (use `ls -lh` on macOS/Linux or `Get-Item` / `dir` on Windows — pick what works on the platform; the Bash tool handles POSIX paths fine on both).
- On failure: show the error output and suggest possible fixes (binary not installed, invalid model dir, out of VRAM → suggest lowering tile size, scale incompatible with chosen realesrgan model).

### Batch mode
- Show a summary table: filename, status (success/failed), output file size.
- Report totals: how many succeeded, how many failed.
- If any failed: list the errors and suggest fixes.
