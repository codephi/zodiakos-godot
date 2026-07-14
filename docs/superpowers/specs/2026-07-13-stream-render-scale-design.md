# Zoom-Dependent Stream Render Scale Design

**Original date:** 2026-07-13

**Revised:** 2026-07-14

## Objective

Load only nearby sectors while the player is close to the map and progressively
increase preventive off-screen coverage as the camera zooms out. The configured
`stream_render_scale = 10.0` is the maximum amplification reached at maximum
zoom, not a constant multiplier at every zoom level.

This setting controls off-screen procedural streaming. It does not change star
density, universe identity or camera rendering.

## Configuration

Map Streaming production values:

```text
stream_render_scale = 10.0
stream_load_margin = 0
stream_unload_margin = 0
stream_min_aspect_ratio = 0.25
stream_max_aspect_ratio = 1.0
```

`stream_render_scale` must be finite and at least `1.0`. It remains editable in
the Inspector and outside `UniverseIdentity`.

Zero load/unload margins make the active sector set follow the rounded target
immediately when zooming in. Sector ceiling already covers the current sector
and every neighboring sector crossed by the viewport.

## Projection Formula

For orthographic height `H`, camera range `[Zmin, Zmax]`, maximum scale `Rmax`,
clamped aspect ratio `A`, sector size `S` and margin `M`:

```text
zoom_progress = clamp((max(H, 0) - Zmin) / (Zmax - Zmin), 0, 1)
effective_scale = lerp(1, Rmax, zoom_progress)
scaled_half_height = max(H, 0) × 0.5 × effective_scale
scaled_half_width = scaled_half_height × A
radius_y = ceil(scaled_half_height / S) + M
radius_x = ceil(scaled_half_width / S) + M
```

If the configured camera range has no span, projection uses `Rmax` directly.

## Reference Behavior

With camera range `0..1000`, `Rmax = 10`, sector size `40`, aspect cap `1` and
zero margins:

| Camera zoom | Effective scale | Radius | Sector target |
| ---: | ---: | ---: | ---: |
| `0` | `1.00×` | `(0, 0)` | `1` |
| `30` | `1.27×` | `(1, 1)` | `9` |
| `94.7` | `1.85×` | `(3, 3)` | `49` |
| `300` | `3.70×` | `(14, 14)` | `841` |
| `500` | `5.50×` | `(35, 35)` | `5,041` |
| `1000` | `10.00×` | `(125, 125)` | `63,001` |

The zoom-30 row is the reported regression target: after zooming in from `94.7`,
the stream must release distant sectors and retain only `3 × 3 = 9` sectors.
At the current average density this is approximately four loaded stellar systems,
though exact SS count remains deterministic by location.

## Runtime Behavior

- Camera or viewport changes recompute zoom-dependent radii.
- Existing active sectors inside the new target are reused.
- Newly covered sectors enter the center-first queue.
- Sectors outside the unload radii are removed immediately with production
  unload margin zero.
- Invalid nonpositive viewport dimensions leave current coverage unchanged.
- The HUD `Active` value counts loaded sectors, while `Systems` counts loaded SS;
  neither is a count of only the points currently visible inside the camera.
- Canonical generation and system composition are unchanged.

## Performance Implications

The old constant `10×` rule requested radius `(5,5)` at zoom `30` and retained
`169` sectors after hysteresis. The revised rule requests radius `(1,1)` and
retains `9` sectors.

Maximum zoom still reaches `10×`, so its 63,001-sector target requires the
separate bounded lazy queue design. The projection contract defines eventual
coverage; it does not require allocating every coordinate at once.

## Testing

Tests prove:

- zoom `30` resolves to radius `(1,1)` and nine active sectors after zoom-in;
- zoom `500` uses midpoint scale `5.5×`;
- zoom `1000` reaches the configured maximum `10×`;
- portrait and extreme aspect values remain clamped;
- scale `1.0` preserves unscaled injected behavior;
- camera/viewport invalid inputs remain safe;
- changing presentation scale does not change universe identity.

## Acceptance Criteria

- Near zoom loads a small neighboring set instead of applying constant `10×`.
- Amplification grows monotonically with camera zoom.
- Maximum zoom still reaches the configured render scale.
- Zooming in releases sectors outside the current target.
- All tuning remains in `config/game_settings.tres`.
- Procedural universe contents remain unchanged.
