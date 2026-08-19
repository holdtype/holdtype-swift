# Multipart Scratch and Foreground Transport

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.transport`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.transport@1`
- Read when: multipart scratch identity, descriptor streaming, redirect, or authentication transport is in scope.
- Do not read when: only source validation, orphan maintenance, or provider error UI is in scope.
- Maximum size: 100 physical lines.

## Pinned scratch artifact

- Scratch is private, backup-excluded where supported, and uses random names
  containing no source filename, attempt identity, credential, or user content.
- Creation starts as exact uppercase canonical UUID plus `.multipart`, mode
  `0600`, Complete protection, xattr `com.holdtype.openai.multipart-scratch`
  exact UTF-8 `v1` with create-only/readback, and non-blocking exclusive lock.
- Before body writes, same inode publishes via
  `renameatx_np(..., RENAME_EXCL)` to exact
  `htmp-v1-<lowercase-canonical-uuid>.multipart`; there is no replacing fallback.
- Directory, staging, descriptor, and final identities are checked through one
  opened private-directory descriptor. Failure removes only operation-owned inode.
- After write/sync, read descriptor must match writer and pathname, regular
  private file with one link. Path is removed, link count becomes zero, and only
  descriptor remains. Hard link is rejected; later replacement cannot alter
  sent bytes and survives cleanup.
- Private-sandbox boundary does not claim protection from hostile same-UID
  interposition where Darwin lacks conditional unlink.

## Streaming and cleanup

- URLSession gets fresh descriptor-backed streams via upload delegate; request
  carries neither `httpBody` nor `httpBodyStream`.
- Each stream has independent offset, reads ≤64 KiB, and replays byte-identical body.
- Cleanup is idempotent on all terminal paths, never mutates source, and does
  not delay cancellation behind blocked local work. Cancellation is checked
  after each blocking operation and before pin/upload.
- Late preparation after timeout/cancel never launches upload.

## Foreground transport and redirects

- Ephemeral foreground session stores no cookies, cache, or URL credentials;
  file backing does not authorize background transfer.
- Provider URL is HTTPS without user info; normal server trust applies and all
  HTTP auth challenges are rejected.
- At most one exact-origin 307/308 replay is allowed, rebuilt from trusted POST,
  Accept, Content-Type, Content-Length, Bearer header, and body offset zero.
- Cross-origin, 301/302/303, opaque/auth-driven, unknown authorization,
  nonzero-offset, unreplayable, or second redirects are rejected before secrets/body.
- Descriptor open/read/replay failure is typed local preparation failure, not network/provider rejection.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared transport privacy.
