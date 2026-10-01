# Shared fixtures

Golden test data that both apps must agree on. A fixture is a list of feature frames plus the lift report the web prototype (`web/src/lib/insights/lift.ts`) produces for them.

```
fixtures/
  lift-<name>.json   { "binSpecVersion": 1, "gate": {...}, "frames": [...], "expected": { LiftReport } }
```

- Regenerate from `web/`: `npx tsx scripts/export-fixtures.ts`. Don't hand-edit.
- `ios/AsthmaCore` tests load every `lift-*.json` and must match `expected` exactly (counts, `gated`, ordering; rates to 1e-9).
- When a bin edge changes, bump `binSpecVersion` and regenerate.

| File | What |
|------|------|
| `lift-demo-gate.json` | Demo diary (10 inhaler, 24 usual) with the demo gate, plus the template headline |
| `lift-demo-default-gate.json` | Same frames, production gate |
| `lift-edge-small.json` | Too few samples, unknown bands, infinite lift |
| `bands-v1.json` | Raw value → band edge cases (PM2.5, ozone, temp, humidity, pollen, smoke, heat, season) |

Run the iOS side with `ios/scripts/test-core.sh`.
