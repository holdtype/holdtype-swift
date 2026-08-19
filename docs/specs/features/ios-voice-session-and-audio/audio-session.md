# iOS Foreground Audio Session

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.session@1`
- Read when: AVAudioSession, routes, cues, interruption, or local finalization matters.
- Do not read when: only provider processing matters.
- Maximum size: 100 physical lines.

App owns recording/cues/playback session. Nonverbal cues; haptic/text fallback.
Warnings at 60/30/10/8/6 then 5…1 relative to limit; omit one-minute Start
warning. Private routes may play in-capture tones; speaker uses haptics + final
15-second text. Calls/Siri/alarms/route/mute/lock/scenes/media loss/reset are
explicit; never invisible continue, silent new attempt, or retained unneeded session.

Configure inactive `playAndRecord`, `default`, only HFP+defaultToSpeaker. No
preferred input/speaker override; freeze input UID/type/data-source. No mix/
duck/spoken/A2DP/AirPlay/muted-override/alert suppression; defer iOS26 HQ/far-field.
HFP allowed. During capture/tail, missing/muted/changed input stops with valid-
partial. Output-only continues only if exact input, recorder, format/rate/channels/
I/O valid; serialized token rejects stale callbacks. Interruption never auto-resumes.

Media loss: arming cancels; retained capture retires objects/token and descriptor-
validates—bounded non-empty recovery with unknown duration if needed, exact empty
Discard-only, uncertainty blocked; finalizing preserves source/Pending; reset only
rebuilds on later Start. Haptics permitted; no speaker warning pips. Start cue has
2-second watchdog plus full revalidation; success stop cue post-close only.

Activate only after preflight. Terminal deactivation stops all then
notifyOthersOnDeactivation. Cue toggle, not Ring/Silent, is reliable control.
Finalization may hold one named background assertion, max ten seconds/system
earlier, for close/completion/copy/journal only. Always end; expiry preserves
checkpoint, starts no provider, resumes foreground. No microphone keepalive or
P4 audio background mode.
