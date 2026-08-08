# Residuals

## HoldType row absent

The visible System Settings Camera privacy list contained no HoldType row.
There was therefore no exact switch to verify or enable. The result is
`holdtype_row_absent` with residual class `environment or signing residual`;
it does not establish an authorization decision.

No directly actionable Camera switch exists for the user on the observed
surface. HoldType must first appear in the Camera application list before its
switch can be enabled or verified. The next action must be chosen after
independent review; this packet did not invoke another permission request.

## Cleanup observation

Closing the packet-opened System Settings window and issuing its UI quit
gesture left the packet-started process resident. After fresh exact identity
validation, TERM was sent only to that run-owned PID and it exited within the
bounded cleanup wait. No pre-existing application process was terminated.
