# Stream Render Scale Design

**Date:** 2026-07-13

## Objective

Allow the procedural star-map stream to load an area whose width and height are
a configurable multiple of the visible viewport. A value of `10.0` means the
streaming rectangle is ten times wider and ten times taller than the visible
map rectangle before sector rounding.

This setting controls preventive off-screen loading. It does not change camera
zoom, star density, universe identity or what the GPU displays inside the camera.

## Configuration

Add one typed Inspector field under `Map Streaming`:

```gdscript
@export var stream_render_scale: float
```

Production values:

```text
stream_render_scale = 10.0
stream_load_margin = 1
stream_unload_margin = 1
```

`stream_render_scale` must be at least `1.0`. Values below one would permit
unloaded holes inside the visible viewport and are invalid. It is a presentation
and streaming budget, so it must remain outside `UniverseIdentity`.

`stream_load_margin` remains a separate fixed safety ring after scaling and
sector rounding. It is restored from the temporary value `10` to `1` because it
is no longer being used as a dimension multiplier.

## Projection Formula

For orthographic height `H`, clamped viewport aspect ratio `A`, universe sector
size `S`, render scale `R` and fixed load margin `M`:

```text
scaled_half_height = max(H, 0) × 0.5 × R
scaled_half_width  = scaled_half_height × A
radius_y = ceil(scaled_half_height / S) + M
radius_x = ceil(scaled_half_width  / S) + M
```

The stream loads every sector inside `[-radius_x, radius_x]` and
`[-radius_y, radius_y]` relative to the current center. Unload radii continue to
add `stream_unload_margin` to both load radii.

### Example requested by the user

For a square visible area of `500 × 500`, `S = 40`, `R = 10` and `M = 1`:

```text
scaled visible target = 5,000 × 5,000
radius per axis = ceil(2,500 / 40) + 1 = 64 sectors
loaded span = (64 × 2 + 1) × 40 = 5,160 units per axis
```

The result is slightly larger than `5,000 × 5,000` because the stream loads
whole sectors and keeps one additional safety ring.

## Runtime Behavior

- Camera or viewport changes recompute scaled radii.
- Existing active sectors are reused.
- Newly covered sectors enter the existing center-first queue.
- Sectors outside scaled unload radii are removed.
- Invalid nonpositive viewport dimensions continue to leave current coverage
  unchanged.
- No hidden benchmark or extra canonical data is generated.
- The HUD may report more active systems, but the visible image does not change
  until the player moves the camera into the preloaded area.

## Performance Implications

The multiplier is linear per dimension and quadratic in area. Scale `10` can
cover roughly one hundred times the visible area before rounding and margins.

At the current reference `H = 300`, aspect `16:9`, `S = 40`, `R = 10` and
`M = 1`, the radii are `(68, 39)`, or `137 × 79 = 10,823` sectors. The current
two-sectors-per-frame budget requires about 5,412 frames to materialize the full
rectangle. Center-first ordering keeps visible and nearby sectors ahead of the
distant buffer.

This setting is intentionally configurable in the Inspector. The later bounded
async streaming implementation will prevent the full rectangle from becoming an
eager in-memory request array, but that optimization does not alter this
projection contract.

## Testing

Configuration tests prove:

- production render scale is `10.0`;
- production load margin is restored to `1`;
- scale `1.0` is valid;
- scale below `1.0` is rejected.

Projection tests prove:

- the scale is applied to both axes before rounding;
- the fixed margin is added after scaling;
- reference, portrait, ultrawide and clamped extreme aspect ratios;
- the `500 × 500` example produces radius `(64, 64)`;
- injected scale `1.0` preserves unscaled behavior;
- unload hysteresis remains additive after scaling.

Controller and demo tests prove:

- computed radii reach the stream controller;
- active sectors are reused when scaled coverage is unchanged;
- invalid viewports create no new work;
- behavioral tests that fully materialize sectors use injected scale `1.0` to
  remain fast while production projection is covered independently.

## Acceptance Criteria

- `stream_render_scale` is visible and editable in `game_settings.tres`.
- Value `10.0` scales both visible dimensions by ten.
- `stream_load_margin` returns to one fixed sector ring.
- Sector rounding never leaves a visible or scaled-target gap.
- Universe identity and procedural system contents remain unchanged.
- Existing center-first generation, reuse, invalid-viewport and unload behavior
  remain intact.
