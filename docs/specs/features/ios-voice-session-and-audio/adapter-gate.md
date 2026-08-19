# iOS Voice Adapter And Recorder Gate

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.adapters@1`
- Read when: platform adapters, permissions, recorder selection, or target isolation matters.
- Do not read when: only product presentation matters.
- Maximum size: 100 physical lines.

UIKit/AVFAudio adapters stay containing-app; Core gets none of their types.
App plist declares exactly `NSMicrophoneUsageDescription = HoldType uses the
microphone to record speech you choose to transcribe.` before requests; keyboard
gets no mic/audio plist/entitlement/link, no Speech string/background mode.

iOS17 adapter reads shared recordPermission, requests only explicit undetermined
Start, fails closed unknown; late result revalidates token/scene/consent/key/storage.
Persistence pins descriptor source before recorder URL. AVAudioRecorder is fail-
closed candidate with identity/xattrs/protection/link/mode/path checks after init,
prepare, and close.

Signed bounded real-recording probe is required because prepare may overwrite URL
without inode guarantee; Simulator is insufficient. Failure selects descriptor-
backed AudioToolbox/AVAudioEngine without weakening source contract. Delegate is
not sole stop; all events/actions converge idempotently, no auto-resume.

UI elapsed uses admitted monotonic clock only. Canonical duration/bytes come from
post-close descriptor media. Locked Complete protection is blocked recovery, not
absence/corruption/success. iOS26 HQ/far-field remains out. This milestone may
fake-test adapters but production composition is separate.
