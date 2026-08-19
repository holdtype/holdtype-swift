# Recording Cache And History Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.CACHE`, `SETTINGS.HISTORY`
- Read when: completed-recording retention or transcript recovery controls is in scope.
- Do not read when: only active recording capture is in scope.
- Maximum size: 100 physical lines.

## Recording Cache

- Dedicated section has default-off Keep completed recordings. Off deletes
  completed attempts and disables/hides retention/list, but existing files can be cleared.
- Enabled policy is last N (default 10) or explicit unlimited. Show total size,
  app-owned count, and rows with file/date/size plus Reveal and Delete.
- Refresh after cleanup/retention changes. Provide Reveal Cache and Clear Cache.
  Destruction affects only app-owned cache, never keys, settings, transcripts,
  usage, or unrelated files. UserDefaults stores policy, not per-file metadata.
- History may show Play only when an accepted row's cached file exists.

## Transcript Recovery History

- Keep Transcript Recovery History defaults on and owns bounded accepted rows
  plus recoverable failed attempts. Turning off immediately clears entries and
  stops accepted writes; Clear does the same bounded cleanup.
- Clear/disable removes temporary retry audio, not normal recording cache, key,
  usage, or settings. A legacy saved off value migrates once to current on by
  default; subsequent explicit choices persist.
- Detailed retention and retry ownership remains with `transcript-history.md`.
