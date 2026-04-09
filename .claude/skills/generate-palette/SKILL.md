---
name: generate-palette
description: Generate SVG Color Palette
argument-hint: [theme description, URL, or hex colors]
allowed-tools: WebSearch, WebFetch, Write, Read, Glob
---

# Generate SVG Color Palette

Generate a professional, interactive SVG color palette reference sheet with click-to-copy hex codes and hover effects.

## Input

The user will provide: $ARGUMENTS

This may include:
- A **theme name** (e.g., "Coral Sunset", "Ocean Blue")
- A **source URL** for color guidelines (e.g., a Pantone page, brand guide, government spec)
- Specific **hex colors** they already know
- A **description** of the mood/context

## Step 1 — Research Colors

If the user provided a URL or named a specific color standard:
1. Use `WebFetch` to retrieve the page content from the provided URL.
2. Extract the relevant color values (hex, RGB, Pantone codes, color names).
3. If the URL is inaccessible, use `WebSearch` to find the color specification by name.

If the user only provided a theme description (no URL or specific colors):
1. Use `WebSearch` to find authoritative color references matching the theme (e.g., Pantone, government brand guides, well-known design systems).
2. Extract 5-6 color values that form a cohesive palette from dark to light.

If the user provided exact hex values, skip research and use those directly.

## Step 2 — Build the Palette Structure

Organize **N main swatches + 1 soft background**, arranged dark-to-light. **Default N=5** unless the user requests more or fewer (supported range: 4–7).

The general structure, always dark-to-light:

| Slot | Role | Typical Usage |
|------|------|---------------|
| 1 (leftmost) | Deepest shade | Text, dark backgrounds |
| 2 | Primary dark | Dropdowns, secondary surfaces |
| ... | Mid tones | Various UI roles |
| center | **Anchor / brand color** | Hero sections, brand identity |
| ... | Light variants | Hover states, interactive |
| N (rightmost) | Brightest tint | Highlights, accents |
| bottom bar | Soft background | Light background fill |

For a **5-swatch** default, the slots map to: deepest → primary dark → **hero** → light → brightest.
For **6–7 swatches**, distribute mid-tones evenly between the dark and light ends.
For **4 swatches**, collapse to: deepest → **hero** → light → brightest.

The **hero swatch** is always the middle index (`floor(N/2)` using 0-based indexing). It displays the Pantone or source reference name prominently inside the swatch.

For each swatch, determine:
- **Name**: A descriptive, evocative name (e.g., "Deep Jade", "Formosan Green")
- **Hex**: The color in `#rrggbb`
- **RGB**: The color as `rgb(r, g, b)`
- **Token**: A CSS-friendly token name (e.g., `green-deep`, `coral-accent`)
- **Usage label**: Short label shown inside the swatch (e.g., "Text", "Hovers")

### Layout Calculation

All swatches are the same size within a palette. Calculate positions using:

```
size = 140  (use 120 if N=7)
gap  = 20   (use 16 if N=7)
total_row = N × size + (N-1) × gap
margin    = (960 - total_row) / 2
x[i]      = margin + i × (size + gap)     for i = 0..N-1
center[i] = x[i] + size / 2
```

Quick reference (pre-calculated):

| N | Size | Gap | Margin | Swatch x positions | Center x positions |
|---|------|-----|--------|--------------------|--------------------|
| 4 | 140 | 20 | 170 | 170, 330, 490, 650 | 240, 400, 560, 720 |
| **5** | **140** | **20** | **90** | **90, 250, 410, 570, 730** | **160, 320, 480, 640, 800** |
| 6 | 140 | 20 | 10 | 10, 170, 330, 490, 650, 810 | 80, 240, 400, 560, 720, 880 |
| 7 | 120 | 16 | 12 | 12, 148, 284, 420, 556, 692, 828 | 72, 208, 344, 480, 616, 752, 888 |

Gradient stops should be evenly distributed: `offset[i] = (i / (N-1)) × 100%`.

## Step 3 — Generate the SVG

Use the following SVG template. Replace all placeholder values (`{{...}}`) with the actual palette data.

IMPORTANT layout rules:
- Canvas: `viewBox="0 0 960 520"`, background `#fafafa`, corner radius 16
- Font: `Segoe UI, system-ui, sans-serif`
- Title at y=48, subtitle (source attribution) at y=74
- N swatches in a row at y=110, all same size, centered — use the layout table from Step 2 to determine x positions. The SVG template below shows the **default 5-swatch layout**; adapt positions for other counts.
- Soft background bar at y=380, full width (880px) matching gradient bar
- Gradient bar at y=450, full width (880px), using a `linearGradient` from darkest to brightest
- Source attribution text at y=492
- All text uses `text-anchor="middle"` and is centered within its swatch
- Root `<svg>` has `role="img"` and `aria-label` for accessibility, plus a `<desc>` element

Interactive features (all self-contained in the SVG, no external files):
- Each swatch is wrapped in `<g class="swatch" onclick="...">` for click-to-copy hex
- CSS hover: swatches lift up (`translateY(-3px)`) with a drop-shadow on `:hover`
- Click copies the hex code to clipboard and flashes a "Copied!" label inside the swatch
- Native browser tooltips via `<title>` inside each swatch group
- Soft background bar is also clickable (`<g class="bg-bar">`)
- `cursor: pointer` on all interactive elements

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 520" font-family="Segoe UI, system-ui, sans-serif" role="img" aria-label="{{palette_title}}">
  <defs>
    <linearGradient id="palette-grad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="{{color1_hex}}"/>
      <stop offset="25%" stop-color="{{color2_hex}}"/>
      <stop offset="50%" stop-color="{{color3_hex}}"/>
      <stop offset="75%" stop-color="{{color4_hex}}"/>
      <stop offset="100%" stop-color="{{color5_hex}}"/>
    </linearGradient>
    <style>
      .swatch { cursor: pointer; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.08)); transition: filter 0.2s ease, transform 0.15s ease; }
      .swatch:hover { filter: drop-shadow(0 6px 16px rgba(0,0,0,0.2)); transform: translateY(-3px); }
      .bg-bar { cursor: pointer; transition: filter 0.2s ease; }
      .bg-bar:hover { filter: drop-shadow(0 3px 8px rgba(0,0,0,0.12)); }
      .copied-label { opacity: 0; transition: opacity 0.3s ease; pointer-events: none; }
    </style>
  </defs>
  <desc>{{palette_title}} — click any swatch to copy its hex code</desc>

  <rect width="960" height="520" fill="#fafafa" rx="16"/>

  <!-- Title -->
  <text x="480" y="48" text-anchor="middle" font-size="22" font-weight="700" fill="#1a1a2e">{{palette_title}}</text>
  <text x="480" y="74" text-anchor="middle" font-size="13" fill="#64748b">{{source_attribution}}</text>

  <!-- Swatch 1: Deepest -->
  <g class="swatch" onclick="navigator.clipboard.writeText('{{color1_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color1_name}} — {{color1_hex}} — Click to copy</title>
    <rect x="90" y="110" width="140" height="140" rx="14" fill="{{color1_hex}}"/>
    <text x="160" y="156" text-anchor="middle" font-size="11" font-weight="600" fill="{{color1_label_fill}}">{{color1_usage}}</text>
    <text class="copied-label" x="160" y="190" text-anchor="middle" font-size="11" font-weight="700" fill="{{color1_label_fill}}">Copied!</text>
  </g>
  <text x="160" y="280" text-anchor="middle" font-size="13" font-weight="600" fill="#1e293b">{{color1_name}}</text>
  <text x="160" y="298" text-anchor="middle" font-size="11" fill="#64748b">{{color1_hex}}</text>
  <text x="160" y="314" text-anchor="middle" font-size="10" fill="#94a3b8">{{color1_rgb}}</text>
  <text x="160" y="330" text-anchor="middle" font-size="10" fill="#94a3b8">{{color1_token}}</text>

  <!-- Swatch 2: Primary Dark -->
  <g class="swatch" onclick="navigator.clipboard.writeText('{{color2_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color2_name}} — {{color2_hex}} — Click to copy</title>
    <rect x="250" y="110" width="140" height="140" rx="14" fill="{{color2_hex}}"/>
    <text x="320" y="156" text-anchor="middle" font-size="11" font-weight="600" fill="{{color2_label_fill}}">{{color2_usage}}</text>
    <text class="copied-label" x="320" y="190" text-anchor="middle" font-size="11" font-weight="700" fill="{{color2_label_fill}}">Copied!</text>
  </g>
  <text x="320" y="280" text-anchor="middle" font-size="13" font-weight="600" fill="#1e293b">{{color2_name}}</text>
  <text x="320" y="298" text-anchor="middle" font-size="11" fill="#64748b">{{color2_hex}}</text>
  <text x="320" y="314" text-anchor="middle" font-size="10" fill="#94a3b8">{{color2_rgb}}</text>
  <text x="320" y="330" text-anchor="middle" font-size="10" fill="#94a3b8">{{color2_token}}</text>

  <!-- Swatch 3: Hero / Anchor (center) -->
  <g class="swatch" onclick="navigator.clipboard.writeText('{{color3_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color3_name}} — {{color3_hex}} — Click to copy</title>
    <rect x="410" y="110" width="140" height="140" rx="14" fill="{{color3_hex}}"/>
    <text x="480" y="166" text-anchor="middle" font-size="14" font-weight="700" fill="white">{{color3_source_line1}}</text>
    <text x="480" y="186" text-anchor="middle" font-size="14" font-weight="700" fill="white">{{color3_source_line2}}</text>
    <text class="copied-label" x="480" y="216" text-anchor="middle" font-size="11" font-weight="700" fill="white">Copied!</text>
  </g>
  <text x="480" y="282" text-anchor="middle" font-size="14" font-weight="700" fill="{{color3_hex}}">{{color3_name}}</text>
  <text x="480" y="300" text-anchor="middle" font-size="12" fill="#1e293b">{{color3_subtitle}}</text>
  <text x="480" y="318" text-anchor="middle" font-size="11" fill="#64748b">{{color3_hex}}</text>
  <text x="480" y="334" text-anchor="middle" font-size="10" fill="#94a3b8">{{color3_rgb}}</text>
  <text x="480" y="350" text-anchor="middle" font-size="10" fill="#94a3b8">{{color3_token}}</text>

  <!-- Swatch 4: Light -->
  <g class="swatch" onclick="navigator.clipboard.writeText('{{color4_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color4_name}} — {{color4_hex}} — Click to copy</title>
    <rect x="570" y="110" width="140" height="140" rx="14" fill="{{color4_hex}}"/>
    <text x="640" y="156" text-anchor="middle" font-size="11" font-weight="600" fill="white">{{color4_usage}}</text>
    <text class="copied-label" x="640" y="190" text-anchor="middle" font-size="11" font-weight="700" fill="white">Copied!</text>
  </g>
  <text x="640" y="280" text-anchor="middle" font-size="13" font-weight="600" fill="#1e293b">{{color4_name}}</text>
  <text x="640" y="298" text-anchor="middle" font-size="11" fill="#64748b">{{color4_hex}}</text>
  <text x="640" y="314" text-anchor="middle" font-size="10" fill="#94a3b8">{{color4_rgb}}</text>
  <text x="640" y="330" text-anchor="middle" font-size="10" fill="#94a3b8">{{color4_token}}</text>

  <!-- Swatch 5: Brightest Accent -->
  <g class="swatch" onclick="navigator.clipboard.writeText('{{color5_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color5_name}} — {{color5_hex}} — Click to copy</title>
    <rect x="730" y="110" width="140" height="140" rx="14" fill="{{color5_hex}}"/>
    <text x="800" y="148" text-anchor="middle" font-size="11" font-weight="600" fill="{{color5_label_fill}}">{{color5_usage_line1}}</text>
    <text x="800" y="165" text-anchor="middle" font-size="11" font-weight="600" fill="{{color5_label_fill}}">{{color5_usage_line2}}</text>
    <text class="copied-label" x="800" y="198" text-anchor="middle" font-size="11" font-weight="700" fill="{{color5_label_fill}}">Copied!</text>
  </g>
  <text x="800" y="280" text-anchor="middle" font-size="13" font-weight="600" fill="#1e293b">{{color5_name}}</text>
  <text x="800" y="298" text-anchor="middle" font-size="11" fill="#64748b">{{color5_hex}}</text>
  <text x="800" y="314" text-anchor="middle" font-size="10" fill="#94a3b8">{{color5_rgb}}</text>
  <text x="800" y="330" text-anchor="middle" font-size="10" fill="#94a3b8">{{color5_token}}</text>

  <!-- Soft Background Bar -->
  <g class="bg-bar" onclick="navigator.clipboard.writeText('{{color6_hex}}');var t=this.querySelector('.copied-label');t.style.opacity='1';setTimeout(function(){t.style.opacity='0'},800)">
    <title>{{color6_name}} — {{color6_hex}} — Click to copy</title>
    <rect x="40" y="380" width="880" height="50" rx="10" fill="{{color6_hex}}" stroke="{{color6_stroke}}" stroke-width="1"/>
    <text x="480" y="410" text-anchor="middle" font-size="12" font-weight="600" fill="{{color1_hex}}">{{color6_name}} | {{color6_hex}} | {{color6_rgb}} | {{color6_token}}</text>
    <text class="copied-label" x="860" y="410" text-anchor="middle" font-size="11" font-weight="700" fill="{{color1_hex}}">Copied!</text>
  </g>

  <!-- Gradient Bar -->
  <rect x="40" y="450" width="880" height="14" rx="7" fill="url(#palette-grad)"/>

  <!-- Source -->
  <text x="480" y="492" text-anchor="middle" font-size="11" fill="#94a3b8">{{source_line}}</text>
</svg>
```

## Step 4 — Choose Label Fills for Readability

For each swatch, the label text inside needs to be readable:
- **Dark swatches** (left half up to and including hero): use a light tint of the palette color or white
- **Light swatches** (rightmost): use the deepest color from the palette
- **Medium swatches** (between hero and rightmost): use white

## Step 5 — Write the File

Save the generated SVG to the `design/` directory with a descriptive filename:
- Pattern: `design/{{theme-slug}}-palette.svg` (kebab-case, e.g., `design/coral-sunset-palette.svg`)

## Step 6 — Show Summary

After generating, display a markdown table summarizing the palette:

| Swatch | Name | Hex | Token | Usage |
|--------|------|-----|-------|-------|
| ... | ... | ... | ... | ... |

And confirm the file path where it was saved.
