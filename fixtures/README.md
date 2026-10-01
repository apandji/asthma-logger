# Shared fixtures

Golden test data that both apps must agree on. A fixture is a list of feature frames plus the lift report the web prototype (`web/src/lib/insights/lift.ts`) produces for them.

```
fixtures/
  lift-<name>.json   { "binSpecVersion": 1, "gate": {...}, "frames": [...], "expected": { LiftReport } }
```

- Generate `expected` from the web prototype; don't hand-edit it.
- `ios/AsthmaCore` tests load every `lift-*.json` and must match `expected` exactly (counts, `gated`, ordering; rates to 1e-9).
- When a bin edge changes, bump `binSpecVersion` and regenerate.

First fixture to add: the synthetic demo frames from `web/src/lib/insights/demo-frames.ts`.
