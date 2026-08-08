# Residuals

## Unknown active authorization result

The accepted active permission route was invoked once and closed with
`camera_authorization_unknown`. This category does not distinguish a failure
to establish active application state before the authorization harness from an
unknown authorization status after activation. The required active state and
`requestAccess` start are therefore not established.

Functional result is `fail` with residual class `environment or signing
residual`. The result is not granted, already authorized, denied, restricted,
timed out, or cancelled.

## Computer Use observation

The run-owned Debug process had exited before bounded Computer Use observation.
No Camera prompt was observed and no UI action occurred. No retry, System
Settings fallback, or alternate automation surface was used.

## Unexercised domains

Camera enumeration/capture, microphone/audio, media, product scenes, storage,
provider/Keychain, and all quantitative measurements were not run. No capture
retry is authorized by this evidence.
