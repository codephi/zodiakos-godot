# System Composition Debug Metrics Design

**Date:** 2026-07-13

## Objective

Add system-composition performance information to the existing development HUD
without generating hidden benchmark systems or changing the canonical universe.
The HUD must distinguish procedural generation, catalog loading and cache behavior
because they have different costs and optimization paths.

## Scope

This feature records complete stellar-system composition requests made by normal
gameplay. It does not benchmark sector generation, create background systems just
for measurement, or add a player-facing performance screen.

The current demo does not yet request complete compositions. Until selection and
lazy composition are connected, the HUD displays empty values instead of causing
work solely to populate metrics.

## HUD Presentation

The existing `DebugHud/Stats` label gains a compact composition section:

```text
SS Procedural: avg -- | p95 -- | max -- | n=0
SS Catalog:    avg -- | p95 -- | max -- | n=0
SS Cache:      hits 0 | misses 0 | rate 0%
```

Durations are displayed in milliseconds. Once samples exist, durations use two
decimal places. The hit rate is `hits / (hits + misses)` and is `0%` when there
have been no cache lookups.

The existing seed, sector, active-sector, visible-system and zoom lines remain.
Catalog validation errors keep the stable `CATALOG_INVALID:` presentation and do
not append misleading performance data.

## Metrics Component

A pure application component owns composition metrics. It does not depend on the
scene tree or mutate domain objects. Its public operations record:

- a successful procedural composition duration;
- a successful catalog composition duration;
- a procedural or catalog failure;
- a composition-cache hit;
- a composition-cache miss;
- a defensive immutable snapshot for presentation.

Procedural and catalog timings each retain only the latest 240 successful
samples. This bounded window prevents unlimited memory growth and allows recent
performance to replace obsolete startup history.

For each source, a snapshot reports:

- sample count;
- arithmetic mean;
- percentile 95 using the nearest-rank method;
- maximum;
- failure count.

The collector computes sorting-dependent statistics only when a snapshot is
requested. Recording a sample remains constant-time apart from removing the
oldest value when the 240-sample window is full.

## Measurement Boundaries

Measurement begins immediately before the composition loader starts resolving a
system and ends only after a complete immutable composition is returned. The
duration uses `Time.get_ticks_usec()` and is converted to milliseconds.

Each job is timed individually. Concurrent jobs are not measured by dividing a
batch wall-clock duration by the number of systems.

Rules:

- a valid completed composition records one timing sample;
- a null, partial or failed result increments failures and records no duration;
- a cache hit records cache behavior but no generation duration;
- a cache miss records the miss, then the requested source records its own
  duration if composition succeeds;
- canceled or stale interest records neither a failure nor a duration when the
  shared job itself remains valid;
- metrics and their enabled state never enter `UniverseIdentity`.

## Integration

The composition service owns no display logic. It receives the shared metrics
component and records cache outcomes plus completed worker-job durations. The HUD
receives snapshots on the main thread and formats them separately from the
collector.

Until the asynchronous composition service is implemented, the same collector
can wrap the existing `LoadSystemComposition` execution boundary. The API remains
stable when execution moves to `WorkerThreadPool`.

The metrics-enabled setting remains centralized in `game_settings.tres`. When it
is disabled, the HUD omits the composition section and collection performs no
sample retention.

## Error Handling

Invalid duration values, negative elapsed time and unknown sources are rejected
without altering valid statistics. A failed composition increments the failure
counter for its known source. Snapshot consumers receive copied arrays or scalar
values and cannot mutate collector state.

The HUD never treats the absence of samples as zero-millisecond generation. It
uses `--` to distinguish “not measured” from an extremely fast operation.

## Testing

Unit tests cover:

- independent procedural and catalog samples;
- arithmetic mean, nearest-rank P95 and maximum;
- the rolling limit of 240 samples;
- failures excluded from timing samples;
- cache hits, misses and zero-lookup rate;
- defensive snapshots;
- disabled collection;
- invalid inputs leaving state unchanged.

HUD tests cover:

- empty metrics rendered with `--`;
- populated metrics rendered in milliseconds;
- existing map statistics remaining visible;
- disabled metrics omitting the composition section;
- catalog errors preserving the stable error-only text.

Integration tests cover one procedural success, one catalog success, one failure
and a repeated request served from cache without adding another generation
sample.

## Acceptance Criteria

- Debug HUD distinguishes procedural, catalog and cache measurements.
- Only real composition requests produce samples.
- Cache hits do not distort generation time.
- Mean, P95, maximum, counts and cache rate are correct and bounded.
- Empty state is explicit and does not display a false zero duration.
- Metrics can be disabled without changing generated universe data.
- Existing debug information and catalog-error behavior are preserved.
