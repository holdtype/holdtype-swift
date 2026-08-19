# Historical Capture Transfer And Relaunch

- Node type: leaf
- Status: Historical
- Read when: tracing retired descriptor-bound capture-to-Pending handoff.
- Do not read when: using it as current capture or recovery authority.
- Maximum size: 100 physical lines.

Normal Done or Recover moved completed capture through preparing-pending before
creating/adopting one protected Pending destination. Copy streamed from the
already-open source descriptor to exact staging, bound source physical identity
and media metadata in xattrs, validated protection/markers/media, no-overwrite
published, then committed a matching journal. Repeated recovery resumed the
same attempt and never minted another destination.

Crash cases distinguished empty inventory, exact zero-byte owned staging,
complete/incomplete bound staging, bound final audio without journal, journal
with durably absent audio, and every corrupt/foreign/multiple/ambiguous case.
Only exact owned residues could be removed/recreated; uncertainty preserved
both owners and blocked new capture.

Source reached transferred only after destination audio/journal and same-phase
durability were confirmed. Provider launch additionally required source removal
or durable transferred state. Confirmed Discard proved no matching/ambiguous
Pending owner, wrote discarding, then identity-pinned unlink/sync; retry never
deleted a recreated path.

Passive launch classified residues without provider/settings/consent/mic/audio-
session work. It performed only tightly named cleanup/retirement, never adopted
orphans or created/repaired journals. The bounded scavenger limited entries,
removals, logical bytes, elapsed time, and EINTR; ordinary logs exposed only
compact aggregate actions.
