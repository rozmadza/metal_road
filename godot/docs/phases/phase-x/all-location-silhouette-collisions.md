# All locations — top-down props and silhouette collisions

## Coverage

- Scrapyard arena: school bus, semi truck, tire/scrap heap, crushed cars and crushed container.
- Oil Cauldron arena: pumpjack, water tower, broken pipeline, drilling truck, checkpoint and drum/scrap pile.
- Standard race locations: shared top-down arena prop set used by track decoration.
- Rust Frontier tracks: the new six-object frontier top-down set.
- Small interactive props: circular tire heap, capsule-shaped wreck and inset rectangular crate/barrier/fence collisions.

## Collision model

- Major arena obstacle colliders are generated once from each PNG alpha silhouette.
- The sampled outline is reduced to a convex hull and inset to 90% of the visible sprite, preventing contact before the car reaches the artwork.
- The same polygon drives physics and the dark contrast footprint. The temporary amber debug boundary has been removed from the player-facing presentation.
- Navigation retains conservative rectangles so bots and bonus placement keep safe clearance without changing physical contact.
- Circular tire heaps use circular or many-sided round colliders instead of squares.

## Art

- Six Rust Frontier props were regenerated as individual transparent raster assets using built-in ImageGen.
- Prompt set required an exact 90-degree orthographic overhead camera, one isolated object, diffuse overhead light, a short contact shadow, transparent background, and prohibited isometric/three-quarter views, visible facades, horizons, UI and watermarks.
- Final project assets are stored in `assets/environment/frontier/*_topdown.png`.

## Validation

- `arena_smoke.gd`: verifies silhouette polygons for all major obstacles, a non-square round tire collider, visible-art coverage and a circular small tire collider.
- `survival_smoke.gd`, `frontier_biome_smoke.gd`, `frontier_gameplay_smoke.gd` and `track_smoke.gd`: PASS.
- Both arena layouts were reviewed visually at 1280×720.
