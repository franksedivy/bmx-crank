# Far cloud layer

Generated with the built-in image generator using the landscape source as the
style reference. Original: `far-source.png`. Native export:
`Source/images/clouds/far.png` (400 × 240, black/white with binary transparency).

The combined export is now retained as a source sheet. The moving cloud renderer
uses three crops: `cloud-a.png`, `cloud-b.png`, and `cloud-c.png` in the same
source-image folder. `split-clouds.swift` extracts them without resampling.

## Prompt

+Use case: stylized-concept.
Asset: one transparent distant-cloud layer for the 400x240 Playdate game BMX Crank.
Reference image: style and environmental context only. Output ONLY clouds; omit every building, tree, hill, fence, pool, and ground.
Composition: landscape 5:3 full-screen layer. Three separate small, horizontally elongated fair-weather clouds, asymmetrically spaced, with lots of transparent empty sky between them. On a final 400x240 grid, put one at approximately (80,70), one at (230,55), one at (325,100), with individual widths around 45-70 pixels and heights 12-22 pixels. Keep all clouds away from the top 40 pixels used by telemetry, and keep the lower half of the canvas empty and transparent. The central jump area should feel open. No cropping of clouds.
Style: match the reference's monochrome hand-inked game art, simplified rounded cloud silhouettes, crisp black outlines around opaque white interiors, a few economical black shadow marks underneath and very sparse black/white stippling. Clean readable silhouettes designed for reduction to 400x240. Only black and white ink plus transparent background. No grey gradients, soft blur, glows, photographic shading, busy crosshatching, or thick storm masses.
Constraints: clouds only; exactly one layer containing three disconnected clouds. Full transparency around and between them, no opaque rectangular sky, no scenery, sun, moon, stars, birds, rain, people, text, logos, border, or watermark.
