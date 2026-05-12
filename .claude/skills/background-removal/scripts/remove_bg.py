"""Remove the background from an image and write a transparent PNG.

Two methods:
  flood  — BFS-style from the four corners with a color tolerance. Preserves
           white *inside* the subject because pixels are identified by
           reachability, not color.
  rembg  — ML segmentation (ISNet/U2Net via onnxruntime). Requires the
           `rembg` package; the ONNX model downloads to ~/.u2net/ on first use.

Auto mode samples border pixels and routes by color variance: low variance
(uniform border) -> flood; otherwise rembg, with a graceful fallback to flood
if rembg is unavailable or errors out.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

VARIANCE_THRESHOLD = 600.0  # sum of per-channel variance on the border ring
DEFAULT_TOLERANCE = 30
DEFAULT_FEATHER = 1
DEFAULT_MODEL = "isnet-general-use"


def load_rgba(path: Path) -> np.ndarray:
    """Load an image as an HxWx4 uint8 array."""
    img = Image.open(path).convert("RGBA")
    return np.array(img)


def border_variance(rgb: np.ndarray) -> float:
    """Sum of per-channel variance across the 1-pixel border ring."""
    top = rgb[0, :, :3]
    bottom = rgb[-1, :, :3]
    left = rgb[:, 0, :3]
    right = rgb[:, -1, :3]
    border = np.concatenate([top, bottom, left, right], axis=0).astype(np.float32)
    return float(border.var(axis=0).sum())


def auto_method(rgb: np.ndarray) -> str:
    var = border_variance(rgb)
    return "flood" if var < VARIANCE_THRESHOLD else "rembg"


# ---------- flood-fill --------------------------------------------------------


def _candidate_mask(rgb: np.ndarray, tolerance: int) -> np.ndarray:
    """Pixels within `tolerance` (Euclidean RGB) of any corner color."""
    h, w = rgb.shape[:2]
    corners = np.array(
        [rgb[0, 0, :3], rgb[0, w - 1, :3], rgb[h - 1, 0, :3], rgb[h - 1, w - 1, :3]],
        dtype=np.float32,
    )
    pixels = rgb[:, :, :3].astype(np.float32)
    tol_sq = float(tolerance) ** 2
    mask = np.zeros((h, w), dtype=bool)
    for c in corners:
        d2 = ((pixels - c) ** 2).sum(axis=2)
        mask |= d2 <= tol_sq
    return mask


def _bg_components_scipy(candidate: np.ndarray) -> np.ndarray:
    import scipy.ndimage as ndi  # type: ignore

    labeled, _ = ndi.label(candidate, structure=np.ones((3, 3), dtype=int))
    border = np.concatenate(
        [labeled[0, :], labeled[-1, :], labeled[:, 0], labeled[:, -1]]
    )
    border_labels = np.unique(border)
    border_labels = border_labels[border_labels != 0]
    if border_labels.size == 0:
        return np.zeros_like(candidate, dtype=bool)
    return np.isin(labeled, border_labels)


def _bg_components_numpy(candidate: np.ndarray) -> np.ndarray:
    """Iterative 4-connected dilation seeded at the border."""
    bg = np.zeros_like(candidate, dtype=bool)
    bg[0, :] |= candidate[0, :]
    bg[-1, :] |= candidate[-1, :]
    bg[:, 0] |= candidate[:, 0]
    bg[:, -1] |= candidate[:, -1]

    while True:
        prev = bg.sum()
        up = np.zeros_like(bg)
        up[:-1, :] = bg[1:, :]
        down = np.zeros_like(bg)
        down[1:, :] = bg[:-1, :]
        left = np.zeros_like(bg)
        left[:, :-1] = bg[:, 1:]
        right = np.zeros_like(bg)
        right[:, 1:] = bg[:, :-1]
        bg |= (up | down | left | right) & candidate
        if bg.sum() == prev:
            return bg


def flood_remove(rgb: np.ndarray, tolerance: int, feather: int) -> np.ndarray:
    candidate = _candidate_mask(rgb, tolerance)
    try:
        bg = _bg_components_scipy(candidate)
    except ImportError:
        bg = _bg_components_numpy(candidate)

    out = rgb.copy()
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    if feather > 0:
        alpha_img = Image.fromarray(alpha, mode="L").filter(
            ImageFilter.GaussianBlur(radius=feather)
        )
        alpha = np.array(alpha_img)

    out[:, :, 3] = alpha
    return out


# ---------- rembg -------------------------------------------------------------


def rembg_remove(rgb: np.ndarray, model_name: str) -> np.ndarray:
    from rembg import new_session, remove  # type: ignore

    session = new_session(model_name)
    src = Image.fromarray(rgb, mode="RGBA")
    result = remove(src, session=session)
    if result.mode != "RGBA":
        result = result.convert("RGBA")
    return np.array(result)


# ---------- main --------------------------------------------------------------


def process(
    input_path: Path,
    output_path: Path,
    method: str,
    tolerance: int,
    feather: int,
    model: str,
) -> tuple[str, Path]:
    rgb = load_rgba(input_path)

    chosen = method
    if method == "auto":
        chosen = auto_method(rgb)
        print(f"[auto] border variance suggests: {chosen}", file=sys.stderr)

    if chosen == "rembg":
        try:
            out = rembg_remove(rgb, model)
        except Exception as exc:  # ImportError, model download failure, etc.
            print(
                f"[warn] rembg failed ({exc!r}); falling back to flood-fill",
                file=sys.stderr,
            )
            chosen = "flood"
            out = flood_remove(rgb, tolerance, feather)
    else:
        out = flood_remove(rgb, tolerance, feather)

    Image.fromarray(out, mode="RGBA").save(output_path, format="PNG")
    return chosen, output_path


def default_output(input_path: Path) -> Path:
    return input_path.with_name(f"{input_path.stem}_nobg.png")


SUPPORTED_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".tiff"}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Remove image background and write a transparent PNG."
    )
    p.add_argument("input", type=Path, help="Input image file or folder")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output path (file mode) or output folder (folder mode). "
        "Defaults to <input_stem>_nobg.png next to each input.",
    )
    p.add_argument(
        "--method",
        choices=("auto", "flood", "rembg"),
        default="auto",
        help="Background removal strategy (default: auto)",
    )
    p.add_argument(
        "--tolerance",
        type=int,
        default=DEFAULT_TOLERANCE,
        help=f"Flood-fill color tolerance, 5-80 (default: {DEFAULT_TOLERANCE})",
    )
    p.add_argument(
        "--feather",
        type=int,
        default=DEFAULT_FEATHER,
        help=f"Flood-fill alpha feather radius in pixels, 0 disables (default: {DEFAULT_FEATHER})",
    )
    p.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"rembg model name (default: {DEFAULT_MODEL})",
    )
    return p.parse_args(argv)


def collect_inputs(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if path.is_dir():
        files = sorted(
            f
            for f in path.iterdir()
            if f.is_file()
            and f.suffix.lower() in SUPPORTED_EXTS
            and not f.stem.endswith("_nobg")
        )
        return files
    raise FileNotFoundError(path)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    inputs = collect_inputs(args.input)
    if not inputs:
        print(f"No supported images found under {args.input}", file=sys.stderr)
        return 1

    is_batch = args.input.is_dir()
    if is_batch and args.output is not None:
        args.output.mkdir(parents=True, exist_ok=True)

    failures = 0
    for i, inp in enumerate(inputs, 1):
        if is_batch:
            out_path = (
                (args.output / f"{inp.stem}_nobg.png")
                if args.output is not None
                else default_output(inp)
            )
        else:
            out_path = args.output if args.output is not None else default_output(inp)

        try:
            chosen, written = process(
                inp,
                out_path,
                args.method,
                args.tolerance,
                args.feather,
                args.model,
            )
            if is_batch:
                print(f"[{i}/{len(inputs)}] {inp.name} -> {written.name} ({chosen})")
            else:
                print(f"{written} ({chosen})")
        except Exception as exc:
            failures += 1
            print(f"[{i}/{len(inputs)}] FAILED {inp.name}: {exc}", file=sys.stderr)

    if is_batch:
        print(f"Done: {len(inputs) - failures}/{len(inputs)} succeeded")
    return 1 if failures and not is_batch else 0


if __name__ == "__main__":
    sys.exit(main())
