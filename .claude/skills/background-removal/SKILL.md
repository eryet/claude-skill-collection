---
name: background-removal
description: Remove the background from an image and produce a transparent PNG. Use this skill whenever the user asks to remove a background, make a background transparent, cut out a subject, create a transparent PNG from a non-transparent image, "knock out" the background, or get an image with only the subject and a transparent backdrop. Triggers on white-background logos and icons, screenshots that need their background dropped, product photos, portrait photos, text-on-solid-color images, and any phrasing like "make this transparent", "remove white background", "isolate the subject", or "give me a PNG without the background".
argument-hint: [image-path-or-folder] [--method auto|flood|rembg]
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

# Remove Image Background

You are helping the user remove the background from one or more images, producing transparent PNG output. The input can be a single image file or a folder containing images.

The script auto-picks between two strategies and falls back gracefully if the ML path is unavailable:

| Method  | Best for                                               | How it works                                                                                                                                  |
|---------|--------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `flood` | Logos, icons, screenshots, text on solid color         | BFS from the four corners with a color tolerance; pixels reachable from a corner become transparent. **Preserves white inside the subject.** |
| `rembg` | Photos with complex backgrounds, hair/fur, portraits   | ISNet/U2Net ONNX segmentation. Model downloads to `~/.u2net/` on first use (~170 MB).                                                         |

## Step 1: Get the input path

Determine the input path using the following priority:

1. **From `$ARGUMENTS`**: If provided (after stripping option flags), use that as the input path.
2. **From a pasted image**: If the user pasted an image, look for a source path in the image metadata. Pasted images may include an annotation like `[Image: source: <path>]` — extract that path.
3. **From the user's message**: Check whether the user's message contains a file or folder path.
4. **Ask the user**: If none of the above yielded a path, ask the user for the path.

### Determine if the path is a file or folder

After resolving the path, check whether it is a **file** or a **directory**:

- **File**: Verify it exists. Proceed in single-image mode.
- **Directory**: Use Glob to find image files matching `*.{png,jpg,jpeg,webp,bmp,tga,tiff}` at the top level (non-recursive). Skip any files whose name ends in `_nobg` to avoid re-processing previous outputs. If no images are found, tell the user and stop. Otherwise, proceed in **batch mode**.

## Step 2: Pick the method

Default to `auto`. The script samples border pixels and chooses `flood` for low-variance borders (uniform background) or `rembg` for noisy ones.

Only ask the user about method/options if they explicitly want to customize, or if you have strong reason to override the default (e.g. the user complained about an earlier result). When asking, use AskUserQuestion with these options:

- **Auto (Recommended)**: let the script route by border variance
- **Flood-fill**: force the corner-flood algorithm — best for logos/icons/text on uniform backgrounds
- **rembg (ML)**: force the segmentation model — best for photos and complex backgrounds

When forcing `flood`, also offer optional tuning:

- **`--tolerance N`** (default 30, useful range 5–80) — higher = more pixels treated as background. Raise if visible background remains; lower if subject edges get eaten.
- **`--feather N`** (default 1, 0 disables) — Gaussian blur radius applied to the alpha channel for cleaner edges. Try 2 for hi-res Chinese text PNGs.

When forcing `rembg`, the relevant option is:

- **`--model NAME`** (default `isnet-general-use`) — alternatives: `u2net`, `birefnet-general` (higher quality, larger), `isnet-anime`, `silueta`.

## Step 3: Verify dependencies

The script needs `Pillow` and `numpy` (always). The `rembg` path additionally needs `rembg` and `onnxruntime`; `scipy` is preferred for the flood path but not required.

Quickly verify with:

```bash
python -c "import PIL, numpy; print('core OK')"
python -c "import rembg, onnxruntime; print('rembg OK')"  # only needed for the ML path
```

If `rembg` is missing and the user wants the ML path (or the auto-router picks it), offer to install:

```bash
pip install --user rembg onnxruntime
```

(Use `--user` on Windows if a system-wide install hits a "WinError 2 .deleteme" file-locking error.)

If `rembg` is unavailable when the auto-router picks it, the script will print a stderr warning and fall back to flood-fill — that is fine; just surface the warning to the user.

## Step 4: Run the script

The script lives at `scripts/remove_bg.py` inside this skill folder. Resolve its absolute path using the SKILL.md location.

### Output naming

Output filename is `<input_stem>_nobg.png`, written next to the input. When the user passes `-o`, honor it: a path ending in `.png` is treated as a single output file (single-image mode only); otherwise it is treated as an output folder.

### Single-image mode

```bash
python "<skill-dir>/scripts/remove_bg.py" "<input-path>" [--method ...] [--tolerance N] [--feather N] [--model NAME]
```

### Batch mode (folder)

```bash
python "<skill-dir>/scripts/remove_bg.py" "<folder-path>" [--method ...] [--tolerance N] [--feather N] [--model NAME]
```

The script processes each image sequentially, prints `[i/N] <input> -> <output> (method)` per file, continues past individual failures, and finishes with a `Done: K/N succeeded` summary.

## Step 5: Report results

### Single-image mode

- On success: report the output file path, its size (use `ls -lh` on the output), and the method that ran (`auto -> flood` or `auto -> rembg`).
- On failure: show the script's stderr and suggest the most likely fix:
  - `ModuleNotFoundError: rembg` → `pip install --user rembg onnxruntime`
  - rembg model download failed → check network, or pass `--method flood` to skip the ML path entirely
  - Flood ate the entire image → the image has no clear subject (it is essentially all background); confirm with the user
  - Flood left visible halo → suggest re-running with a higher `--tolerance` (e.g. 45) and/or `--feather 2`
  - Flood ate part of the subject → suggest a lower `--tolerance` (e.g. 15) or `--method rembg`

### Batch mode

- Show a summary table: filename, output filename, method (`flood`/`rembg`), output size, status.
- Report totals: succeeded, failed.
- If any failed: list each error and apply the same suggestions above.
