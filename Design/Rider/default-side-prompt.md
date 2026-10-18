# Default side-view rider

Generated with the built-in image generator. The source is
`default-side-source.png`; the standalone 64 × 64 monochrome export is
`Source/images/rider/default-side.png`. The rider renderer overlays it on the
procedural wheels, masking the static wheels in a cached copy of the image.
The PNG itself remains unchanged. Alignment settings live in
`Source/game/tuning.lua` under the rider artwork overlay section.

## Prompt

+Use case: stylized-concept.
Asset: ONE neutral/default BMX rider gameplay sprite, pure side view, transparent background, facing RIGHT.
Design it for a final 64x64 pixel sprite on the monochrome Playdate screen. Single full-body rider PLUS one complete BMX bicycle, all visible and uncropped. Clear readable silhouette and simple bold shapes rather than tiny illustration detail.
Camera: strict orthographic side elevation, at wheel axle height, zero three-quarter perspective. Exactly TWO equal circular wheels in the same plane, axles at the same horizontal height, rear wheel on left, front wheel on right. In the intended 64x64 sprite, tire outer diameter is about 16 pixels and axle-to-axle wheelbase about 38 pixels. Leave transparent margins around the subject.
Bicycle: mechanically correct compact BMX diamond frame; straight top tube, down tube and seat tube form the main front triangle; rear triangle connects bottom bracket and seat cluster to rear axle. One short fork runs from head tube to front axle; a stem and raised BMX handlebar connect correctly above the head tube. Small saddle at top of seat tube. ONE small chainring at the bottom bracket, ONE chain loop to rear hub, two opposite crank arms and pedals. Simplify or occlude the far pedal and far limbs naturally. No extra wheels, handlebars, chainrings or floating disconnected parts. Do not let the chainring drift toward either wheel.
Rider: helmeted adult BMX rider in a relaxed ready-to-ride position, standing slightly above the saddle with a modest forward lean, natural straight back, gently bent elbows and knees, hips over bottom bracket, both hands gripping handlebar, feet on level/opposing pedals. Not performing a trick. Correct human proportions with head above shoulders, shoulders above hips, legs naturally reaching pedals. Shorts, plain short-sleeved shirt and shoes, no branding. Use natural side-view occlusion of far limbs rather than separating everything unnaturally.
Art: clean intentional monochrome pixel-art sprite, black ink outlines with opaque white interior shapes, matching a black-and-white retro BMX game. Minimal tire/spoke and fabric detail, very restrained shading, no halftone noise. Strong helmet and limb silhouette. Black and white only plus transparent negative space between frame tubes, wheels and limbs.
Output: only this ONE sprite, centered on a square transparent canvas. No sprite sheet, multiple poses, ground line, floor shadow, scenery, lettering, logos, UI or watermark.
