# R09 residuals

| Residual | Class | Disposition |
| --- | --- | --- |
| The sole attempt reached camera probe, passthrough, and final probe, then `stored_sample_exact_v1` failed with `video_preservation_failed` / `reading_failed` | debug-spike defect | The emitted closed dimension is retained. The evidence does not attribute it to a specific reader operation, comparator condition, finalizer, media artifact, or platform behavior. Zero Ready clips were produced. |
| Stored-sample counts and encoded-byte totals were not emitted on the failed preservation path | product-threshold input awaiting Phase 0C | Values remain null/evidence-only; codec, format, dimensions, cadence, transform, timestamp bounds, probe results, and passthrough stage are retained from the validated handoff. |
| Exact media durations, file bytes, start/finalization latency, CPU, and memory were not emitted | product-threshold input awaiting Phase 0C | Fields remain blank/evidence-only and are not reconstructed from cleaned raw media. |
| No visible/audible controlled markers were present | product-threshold input awaiting Phase 0C | Sync offset and drift are unavailable and no claim is made. |

The event handoff was published once, identity/digest validated, consumed once,
and removed through the accepted W07-R3 authority. The raw script root and
private enumeration/orchestration root were removed after classification; the
unrelated pre-existing Phase 0B root was preserved. No permission request, TCC
action, fallback, transcode, downsample, second microphone owner, capture retry,
retained media file, or Ready clip occurred.

Next dependency: `DV-P0B-CAPTURE-R09-REVIEW`.
