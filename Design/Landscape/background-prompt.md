# Landscape generation

Created with the built-in image generator. References:
`Design/Launcher/Layers/landscape.png` for the setting and composition,
`Design/Launcher/Layers/pool.png` for the ink style.

The source is `background-source.png`. The game export is
`Source/images/background.png`: 400 × 240, black and white with binary
transparency, scaled proportionally and anchored at the bottom.

## Generation prompt

Use case: stylized-concept.
Asset: a transparent city and landscape background layer for BMX Crank on Playdate, to export at exactly 400x240 pixels.
Image 1 is the composition and setting reference: distant city towers, rolling hills, shrubs, palm trees and a modest fence behind a concrete BMX pool. Image 2 is ONLY the established bold monochrome ink style reference. Generate ONLY the landscape, not any part of the pool.
Canvas and composition: landscape 5:3. On the intended 400x240 grid, keep the upper 90 pixels completely clear and transparent. A few palms rise to around y=100-130 at the sides; a compact small city skyline sits around y=140-175, rolling hills and low trees around y=150-185. A thin fence stretches across the scene around y=185-192, behind where the pool will be composited. The main skyline is low on the canvas so there is ample clear sky for airborne gameplay. Terrain continues beneath the horizon to the bottom, with quiet white ground and very sparse texture, mostly hidden by the separate pool layer.
Visual style: match the pool's crisp black-and-white hand-inked game art. Strong clean contours, simplified building shapes, small window marks, solid black tree silhouettes, white highlights, controlled sparse stipple and ordered black/white dithering on hills. High readability when reduced to 400x240. Two-color BLACK and WHITE only, plus transparent sky. Black outlines around white buildings so they remain readable on a white sky. No grey gradients, softness, blur, photographic texture or excessive fine detail.
Constraints: skyline and landscape only. No pool, ramp, deck, coping, rider, bicycle, people, clouds, sun, stars, text, signs, logos or watermark. No rectangular opaque sky backdrop. Keep mountains, trees, buildings and fence visually separate and plausibly scaled in the distance. Both edges extend naturally to the canvas boundaries.
