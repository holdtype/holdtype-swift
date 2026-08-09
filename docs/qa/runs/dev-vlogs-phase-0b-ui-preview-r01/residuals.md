# Residuals

## Environment or signing residual

The isolated HoldType app reported Camera authorization as `not_determined`.
The protocol forbids requestAccess and TCC/System Settings mutation, so live
frames, mirroring, indicator behavior, release after capture, and reacquisition
could not be exercised.

## Measurement residual

The Computer Use app-access elicitation delayed visual inspection beyond the
30-second visual window-discovery target. Exact run-owned process discovery
completed in 12.396 seconds, and the complete UI session remained bounded at
260.809 seconds. The 43.984-second Start-to-terminal observation is an upper
bound containing Computer Use transport time, not a product latency.

## Protected-owner differential

Recording Cache, ActiveRecordings, TranscriptionRecovery, and the default Dev
Vlogs destination matched their aggregate baselines. The shared preferences
plist changed size and digest during the session while one pre-existing
HoldType process remained active. The run therefore does not attribute that
change and does not claim byte-identical History persistence.

## UI cleanup detail

Computer Use closed the preview window, then its post-action state lookup
returned `noWindowsAvailable`. The exact run-owned app process still existed
without a window and exited after one identity-revalidated bounded TERM. No
pre-existing HoldType process was signaled.
