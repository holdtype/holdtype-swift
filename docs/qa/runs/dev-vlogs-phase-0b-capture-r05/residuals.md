# Residuals

## Functional failure

`continuity-10s` is `fail` with residual class `environment or signing
residual`. One explicit Continuity Camera identity was available and selected,
but the accepted harness returned `camera_permission_required` before camera
start or first-frame evidence. No alternate camera or system/default fallback
was attempted.

The harness created one functional attempt and no Ready clip. Its sole audio
owner started before the camera gate and was cancelled on the terminal route.
Camera-only playability, final audio/video playability, passthrough
compatibility, encoded-sample preservation, and preferred-transform
preservation remain unqualified rather than passed.

## TCC surface

No Camera prompt appeared. Computer Use was therefore not invoked, and no
system setting or TCC record was changed or reset. A later authorized runtime
must first provide an ordinary macOS Camera authorization surface for this
signed Debug identity; this packet may not manufacture permission through a
different app identity or broad System Settings change.

## Evidence-only measurements

All media, timing, sample, resource, byte-rate, and finalization measurements
are unavailable. Sync offset and drift are additionally unavailable because
the packet used no controlled physical markers. These fields remain
`evidence_only`, not failures against an invented threshold.

## Operational deviation

One pre-functional invocation was rejected as `invalid_configuration` before
an attempt event, microphone start, camera start, or media creation. The QA
wrapper had redirected `TMPDIR`, conflicting with the harness's exact
temporary-root safety check. The invocation was corrected to the accepted
script's normal internal temporary root before the single functional attempt.
No capture retry occurred.
