# Residuals

## Functional failure

`continuity-10s` is `fail` with primary residual class `debug-spike defect`.
The exact selected Continuity Camera was available and candidate-capable, but
the harness terminated the attempt as `camera_start` before the first frame.
It emitted no underlying AVCaptureDevice error category, so permission denial,
device ownership, format configuration, or another platform cause cannot be
classified truthfully from this evidence.

No second camera or system preference was used as fallback. The terminal event
count is exactly one and the terminal clip count is zero.

## Termination cleanup

After writing the terminal event, the Debug process remained alive beyond the
accepted 35-second termination-cleanup expectation. Computer Use could not
attach to the activation-prohibited harness in one bounded attempt and exposed
no permission surface. The run-owned Debug executable was terminated exactly;
the outer hardware command exited 143 inside its 310-second bound. Cleanup of
the inner and outer temporary roots then succeeded.

This termination behavior is a functional Debug-harness residual even though
the operational outer timeout prevented an unbounded wait.

## TCC and environment

No Camera or Microphone prompt was observed or acted on. TCC was not reset or
changed. Because the harness did not preserve the camera-start error and
Computer Use could not attach, the signed harness authorization state remains
an `environment or signing residual`; it is not asserted as denied,
restricted, authorized, or not determined.

## Evidence-only measurements

No camera frame or candidate media existed. Realized dimensions, frame rate,
codecs, duration, byte rate, finalization overhead, CPU, memory, sync offset,
and drift remain unavailable with disposition `evidence_only`.

## Required next dependency

Review must decide whether to repair the Debug harness so it retains a compact
camera-start error category and completes termination after this failure. Do
not repeat hardware capture merely to guess the missing category.
