![BMX Crank](Design/Banners/bmx-crank-readme-hero.png)

# bmx-crank
PlayDate BMX game to pull some serious tricks

## Documentation

The [BMX Crank wiki](https://github.com/franksedivy/bmx-crank/wiki) explains the current architecture,
prototype mechanics, tuning variables, and safe ways to extend the game.

## Scene artwork

In `Source/game.lua`, set `useSceneArtwork` to `false` for a white background
and the original wireframe pipe. Set it to `true` to show the artwork layers.
`showPoolTrace` controls the physics-curve overlay in artwork mode; leave it on
while aligning the original perspective pool with the riding surface.

Export the landscape and pool layers as 400 × 240 PNGs with transparency,
using these paths in `Source/`. They draw at `(0, 0)` and load once when the
game starts. Clouds use separate cropped images, positioned by their renderer.

| Draw order | Export path | Status |
| --- | --- | --- |
| 1 | Far cloud instances | Smaller and slower |
| 2 | Near cloud instances | Larger and faster |
| 3 | `images/background.png` | Optional city and landscape |
| 4 | `images/pool/middle.png` | Required when artwork is enabled |
| 5 | Rider | Drawn by the game |
| 6 | `images/pool/front.png` | Optional near edge of the pipe |

Telemetry draws last. Missing optional landscape/pool layers are skipped.
Rebuild and restart after adding an export.

## Cloud motion

`Source/game/clouds.lua` draws two cloud depths using six cropped images,
`images/clouds/cloud-a.png` through `cloud-f.png`. Its settings table
controls each depth independently:

| Setting | Far | Near | Meaning |
| --- | --- | --- | --- |
| `count` | 2 | 2 | Number of active clouds; set to 0 to empty that depth. |
| `scale` | 0.6 | 1 | Image scale, prepared once at startup. |
| `windMultiplier` | 0.35 | 1 | Fraction of the shared wind speed used at that depth. |
| `minimumY` / `maximumY` | 45–80 | 65–110 | Random top-edge height in screen pixels. |
| `minimumGap` / `maximumGap` | 35–100 | 50–140 | Random spacing beyond the upwind edge when recycling. |

Each instance randomly selects a shape, horizontal flip, height, and speed
variation (85–115% of its depth's speed). All clouds follow the same wind
direction and re-enter from the opposite edge after leaving the screen.
Images and cloud objects are reused, and clouds continue across rider respawns.

Set `cloudsEnabled = false` alongside the other toggles in `Source/game.lua`
to hide the clouds. `useSceneArtwork = false` also disables cloud rendering
and updates as part of wireframe mode.

The original combined `images/clouds/far.png` is preserved as an unused source
sheet. `Design/Clouds/split-clouds.swift` reproduces the three crops from it
without resampling; the output images no longer need full-screen canvases.

## Wind

`Game` owns a single `Wind` instance from `Source/game/wind.lua`, updated before
the scene. Its signed speed appears in telemetry with `<` for left and `>` for
right. Wind continues updating with artwork or clouds disabled.

The settings at the top of `wind.lua` control:

| Setting | Default | Effect |
| --- | --- | --- |
| `initialSpeed` | -12 | Initial leftward wind in pixels per second. |
| `minimumSpeed` / `maximumSpeed` | 6–20 | Random target strength after a reversal. |
| `minimumChangeInterval` / `maximumChangeInterval` | 20–45 | Seconds between target reversals. |
| `acceleration` | 2.5 | How quickly the speed approaches its target, in px/s². |

Wind eases through zero on each reversal. Cloud speed is wind speed multiplied
by depth and instance variation. For now this affects scenery and telemetry;
the future jump influence is recorded in the Wiki's Ideas page.

## Rider sprite alignment

The renderer overlays `Source/images/rider/default-side.png` on the procedural
bike, clearing the PNG's static wheels in a cached copy so the rotating wheels
remain visible. The original PNG is unchanged.

In `Source/game/tuning.lua`, adjust `riderSpriteOffsetX` (forward),
`riderSpriteOffsetY` (down), `riderSpriteScale`, and `riderSpriteAngleOffset`
(degrees). Offsets follow the bike's angle and facing. The pivot and wheel-mask
settings describe the source image; update them if you move its wheels in
Aseprite. In `Source/game.lua`, set `riderSpriteEnabled = false` to show only
the procedural bike, alongside the scene artwork and pool-trace toggles.
Rebuild and restart after changing these settings.
