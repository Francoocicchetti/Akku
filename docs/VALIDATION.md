# Validation and current limits

Public preview 7.1.1, September 30, 2026.

## What was checked

The local test run passed **3,387 checks** on a MacBook Air 13-inch M5, model `Mac17,3`, running macOS 27. The integration count depends on the real apps open during the run; sixteen user-facing apps were detected. No user's app list or personal location data is included in this repository.

| Area | Checks |
|---|---:|
| Budget, boundaries and persistence | 239 |
| Learning, forecasts, alerts, hardware and classification | 114 |
| Native storage, apps and hardware integration | 48 |
| Prior journey/migration/calibration/charging models | 45 |
| Companion moods, quiet mode, use time and return advice | 47 |
| Native manual location and home replacement | 14 |
| Automatic sessions and weekly aggregation | 39 |
| Daily app/place-history models | 34 |
| Energy scheduling, checkpoints, backoff and animation | 80 |
| Battery panel, gaps, retention and calendar boundaries | 41 |
| Language selection, interpolation and catalog completeness | 2,667 |
| Daily-routine autonomy | 19 |

The source audit covers 457 current localizable templates; the catalog retains 529 entries in French, Simplified Chinese, German and Brazilian Portuguese. English/Spanish templates are also tested. Completeness tests do not establish linguistic quality. Native-speaker review is welcome.

The daily-routine tests cover insufficient observations, minimum exposure, weighted consumption, full-charge units, changing daily rates, confidence limits, old/future data, invalid values, repeated dates, zero-drop intervals and consumption across recharges. Synthetic fixtures remain separate from user data.

Animation policy tests confirm immediate short bursts on appearance/mood changes, a blink within the burst and the eighteen-second rest. The deterministic periodic schedule produces 51 callbacks per minute; actual UI work depends on visibility and state changes. This is not a watt-hour benchmark.

The preceding 7.1 native UI review confirmed the new routine-learning screen, removal of manual activity/time controls, larger companion, enabled animation setting and preserved battery panel. Numerical multi-day routine projections were checked with isolated fixtures because enough real days had not yet accumulated. The public 7.1.1 change narrows the advertised support scope and updates documentation/feedback resources.

## What is not yet established

- Physical validation across all MacBook Air/Pro M1–M5 configurations and older compatible macOS versions.
- Reliable empirical coverage of the predicted ranges across weeks of real use.
- Measured total Akku energy use across models, or proven battery-lifespan improvement.
- Exact per-app energy, exact call detection, instant departure detection or remote tracking of an offline Mac.
- Developer ID signing and Apple notarization of this preview.
- Professional translation or complete accessibility certification.

To help test: use your normal workflow, note model/macOS/brightness/apps and power state, repeat comparable sessions on different days, and describe observed versus predicted behavior. There is no need to discharge to zero. Redact personal information before sharing an export. Automated success does not remove these limitations.
