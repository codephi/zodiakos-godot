# Bounded Lazy Sector Queue Design

**Date:** 2026-07-14

## Objective

Preserve the approved `stream_render_scale = 10.0` behavior while preventing
large zoom changes from eagerly allocating and sorting every covered sector.

The final target coverage remains unchanged: small zoom values cover few nearby
sectors and large zoom values progressively cover many sectors. Only request
enumeration becomes lazy and memory-bounded.

## Problem

At zoom `1000`, aspect `16:9`, scale `10`, sector size `40` and fixed margin `1`,
the approved projection produces radii `(224, 126)`, or 113,597 sectors. The
current controller calls `load_order`, which creates and sorts one Array with all
coordinates synchronously before the two-sectors-per-frame generation budget can
take effect.

The projection math is correct. The eager queue construction is the unsafe part.

## Configuration

Add one field to the central `Map Streaming` settings:

```gdscript
@export var stream_max_pending_sectors: int
```

Production value:

```text
stream_max_pending_sectors = 256
```

The value must be positive. It limits only coordinates waiting in memory; it does
not cap final coverage. It remains outside `UniverseIdentity`.

## Lazy Ring Iterator

Create a pure `SectorRingIterator` that receives an immutable copy of center and
nonnegative rectangular radii.

Public interface:

```gdscript
next_coordinate() # SectorCoordinate or null when exhausted
is_exhausted() -> bool
```

The iterator stores only scalar cursor state. It emits coordinates using the
existing ordering contract:

1. increasing Chebyshev distance from center;
2. increasing sector `y` inside the same distance;
3. increasing sector `x` inside the same `y`.

For each distance ring, it emits the top row left-to-right, then each middle row's
left and right boundary, then the bottom row left-to-right. Candidates outside
the rectangular radii are skipped. Corners are emitted once.

The iterator never builds a complete Array and never sorts coordinates.

## Controller Integration

`SectorStreamController` owns:

- the current iterator;
- the existing bounded `pending` Array;
- the existing `queued` key Dictionary.

On center, zoom or viewport reconciliation:

1. rebase the view;
2. discard the previous iterator and pending state;
3. create a new iterator for the current center and load radii;
4. fill pending only until `stream_max_pending_sectors`;
5. skip coordinates already active or already queued;
6. unload active coordinates outside unload radii;
7. emit changed statistics.

`process_pending` keeps its existing per-frame generation limit. After processing
the batch, it refills pending from the iterator back to the configured maximum.
This repeats until the iterator is exhausted.

Changing view while old coordinates remain pending cancels them logically by
replacing the iterator and clearing pending/queued. Sector generation is still
synchronous in this phase, so there are no worker results to invalidate.

## Behavioral Guarantees

- `pending.size()` never exceeds 256 in production.
- Final coverage is not capped and still follows `stream_render_scale`.
- Center and nearest rings are generated first.
- Active sectors are never regenerated during an unchanged reconciliation.
- Invalid viewport sizes create no iterator and no extra work.
- Unload hysteresis remains based on scaled load radii plus unload margin.
- Canonical sector/system generation remains unchanged.
- This phase does not introduce threads, SQLite access changes or GPU generation.

At exact zoom `0`, scale contributes zero and the fixed margin yields radii
`(1, 1)`, so nine nearby sectors are the complete target. At zoom `1000`, the
target remains 113,597 sectors, but only 256 wait in memory at a time.

## Existing API Transition

`VisibleSectorProjection.load_order` is removed after controller migration because
retaining an unused eager implementation would allow the original failure mode to
return. Projection continues to calculate load/unload radii only.

The future bounded async streaming plan must reuse `SectorRingIterator` rather
than create a second ring-enumeration implementation. Its request scheduler can
wrap this iterator with epochs, priorities and worker capacity later.

## Error Handling

- Negative iterator radii are rejected by assertion at construction.
- Null center is rejected by assertion.
- Invalid `stream_max_pending_sectors <= 0` fails settings validation.
- Iterator exhaustion returns `null` consistently and remains exhausted.
- A zero processing limit generates nothing but may retain the already bounded
  pending window.

## Testing

Iterator unit tests cover:

- exact center, first ring and second ring order;
- rectangular clipping on wide and tall radii;
- no duplicates and exact total count;
- zero radii;
- stable exhaustion;
- defensive copy of center.

Controller tests cover:

- production zoom `1000` target radii with pending capped at 256;
- processing two sectors refills back to 256 while work remains;
- small finite coverage eventually exhausts and materializes every coordinate;
- unchanged reconciliation skips active sectors;
- center/zoom change replaces stale pending coordinates;
- invalid viewport preserves iterator and pending state;
- configured pending cap injection;
- zero explicit processing limit.

Configuration and identity tests cover:

- production cap `256`;
- nonpositive cap rejection;
- changing the cap does not change universe identity.

## Performance Acceptance

For production zoom `1000` at `16:9`:

- `load_radii == Vector2i(224, 126)`;
- mathematical target remains 113,597 sectors;
- pending count is at most 256;
- reconciliation does not allocate or sort an Array proportional to 113,597;
- generation remains limited by `stream_sectors_per_frame`.

## Acceptance Criteria

- Scale `10` remains the production default and preserves zoom-dependent final
  coverage.
- Large zoom no longer creates the complete coordinate list synchronously.
- Pending memory is bounded by one central Inspector setting.
- Existing deterministic center-first order is preserved exactly.
- Full suite, catalog validation and headless smoke pass.
