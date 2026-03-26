---
name: waifu2x
description: Upscale images using waifu2x-ncnn-vulkan with configurable scale, noise, model, format, and tile size
argument-hint: [-default] [image-path-or-folder]
allowed-tools: Bash, Read, Glob
---

# Upscale Image(s) with waifu2x

You are helping the user upscale one or more images using `waifu2x-ncnn-vulkan`. The input can be a single image file or a folder containing images.

## Step 0: Check for default flag

Check if `$ARGUMENTS` contains `-d` or `--default`. If it does, enable **quick mode**: skip all prompts and use default settings (scale=2, noise=2, model=cunet, format=png, tile=0). Remove the `-d`/`--default` flag from the arguments before proceeding — any remaining text is treated as the image/folder path.

## Step 1: Get the input path

Determine the input path using the following priority:

1. **From `$ARGUMENTS`**: If provided (after removing any flags), use that as the input path.
2. **From a pasted image**: If the user pasted an image in the conversation, look for the source path in the image metadata. Pasted images may include a source annotation like `[Image: source: <path>]` — extract the file path from that.
3. **From the user's message**: Check if the user's message contains a file or folder path.
4. **Ask the user**: If none of the above yielded a path, ask the user for the path to the image or folder they want to upscale.

### Determine if path is a file or folder

After resolving the path, check whether it is a **file** or a **directory**:

- **If it's a file**: Verify it exists. Proceed with single-image mode (one image to process).
- **If it's a directory**: Use Glob to find all image files in that folder matching `*.{png,jpg,jpeg,webp,bmp,tga}` (non-recursive — only the top level of the folder). Skip any files that already have `_waifu2x_` in their name to avoid re-processing previous outputs. If no images are found, tell the user and stop. Otherwise, proceed with **batch mode** (multiple images to process).

## Step 2: Ask for upscaling options

**If quick mode is enabled (from Step 0), skip this step entirely.**

Otherwise, first ask the user whether they want to use default settings or customize. Use AskUserQuestion with a single question:

- **Use defaults (Recommended)**: Immediately proceed with scale=2, noise=2, model=cunet, format=png, tile=0
- **Customize settings**: Let the user pick each option individually

If the user picks **Use defaults**, skip straight to Step 3 with the default values.

If the user picks **Customize settings**, present the following options using AskUserQuestion:

- **Scale factor**: 1, 2 (default), or 4
- **Noise reduction level**: -1 = none, 0, 1, 2 (default, medium), or 3
- **Model**: `models-cunet` (default, best quality), `models-upconv_7_anime_style_art_rgb` (fast, anime), or `models-upconv_7_photo` (fast, photos)
- **Output format**: `png` (default), `jpg`, or `webp`
- **Tile size**: 0 = auto (default), 32, 64, 128, 256, or 400 (lower values use less VRAM)

## Step 3: Locate waifu2x executable

Check if a memory file exists at the project memory directory that stores the waifu2x executable path. Look for a memory file about the waifu2x path (e.g., `reference_waifu2x_path.md`).

- If a saved path is found, verify the executable still exists at that location. If it does, use it. If not, ask the user for the new path.
- If no saved path is found, try running `waifu2x-ncnn-vulkan` directly first. If that fails (command not found), ask the user where `waifu2x-ncnn-vulkan.exe` is located.
- Once the user provides a valid path, save it to a memory file (type: reference) so it can be reused in future conversations.

## Step 4: Run waifu2x

### Output naming

Construct each output filename as: `<original-name>_waifu2x_<scale>x.<format>`

For example: `photo.png` with scale 2 and png format becomes `photo_waifu2x_2x.png`

Place each output file in the same directory as its input file.

### Single-image mode

Run the command once:

```
<waifu2x-path> -i "<input-path>" -o "<output-path>" -s <scale> -n <noise> -m "<model-path>" -f <format> -t <tile-size>
```

### Batch mode (folder)

Process each image in the folder sequentially. For each image, run:

```
<waifu2x-path> -i "<input-path>" -o "<output-path>" -s <scale> -n <noise> -m "<model-path>" -f <format> -t <tile-size>
```

Print a progress line for each image as it completes (e.g., `[1/5] Done: image1.png`). If a single image fails, log the error and continue with the remaining images — do not stop the entire batch.

Use the resolved executable path from Step 3. When using a full path, also pass the model directory as a full path relative to the executable's folder.

## Step 5: Report results

After all processing completes:

### Single-image mode
- If it succeeded: tell the user the output file path and its file size (use `ls -lh` on the output)
- If it failed: show the error output and suggest possible fixes (e.g., waifu2x-ncnn-vulkan not installed, invalid model path, out of VRAM — suggest lowering tile size)

### Batch mode
- Show a summary table with columns: filename, status (success/failed), output file size
- Report totals: how many succeeded, how many failed
- If any failed: list the errors and suggest fixes
