# iOS V1.1 Compact History

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.history@1`
- Read when: accepted History, Saved Recording, policy, or History failures matter.
- Do not read when: only Recording Cache retention/playback details matter.
- Maximum size: 100 physical lines.

- Accepted History is local, app-private, text-only, newest 20. One canonical
  Pending may appear separately as a Saved Recording without entering its repository.
- Each row uses accepted `resultID`, exact text, and internal ordering date.
  Present newest-first flat full text: no detail route/date/time. One-tap Copy;
  eligible Play immediately before Copy; trailing swipe Delete; no Share/extra tap.
  Confirmed Clear All and Save History policy stay in toolbar/Settings.
- One owner serializes append/Delete/Clear All. Storage failure is a nonblocking
  warning after Voice success. Commit Latest before append; always continue
  exact Pending metadata/audio cleanup. After relaunch, idempotently append the
  committed result if Save History remains on, without provider repeat or
  retaining Pending solely for unavailable History.
- Accepted History owns no audio/failed attempt. Row Play resolves separate
  Recording Cache by `resultID`; Pending card uses canonical Pending playback
  and disappears only after success or explicit deletion.
- Successful selected-limit audio is an exception shown newest-first in an
  independent `Saved Recordings` section, capped at five, with Play and exact
  Discard. It is not accepted text. It survives relaunch, Save History off,
  Clear Accepted History, and default Delete Immediately cache policy.
- New installs enable Save History and disable Recording Cache. History and
  Recording settings own controls/copy.
- Disabling History requires confirmation and atomically writes disabled plus
  no entries before success. Cancel/failure leaves enabled record and entries.
  Enabling affects later success only; no generation/cutover protocol.
- States are loading, disabled, empty, list, unavailable. Only true load failure
  says `History Unavailable` with Retry; enabled empty says `No History Yet`.
  Failed Delete/Clear/enable/disable preserves confirmed presentation and warns;
  destructive success appears only after atomic replacement.
