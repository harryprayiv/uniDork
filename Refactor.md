# uniDork: Buffer→Library Promotion + Split Import — Implementation Plan

## Context for the implementing session

This plan extends a Unison movie-metadata pipeline (uniDork) that has just completed two refactor passes: config threading (all runtime config flows from `config.nix` → env vars → a threaded `Config` record read once via `Config.fromEnv`) and library/staging unification (one CRC-keyed `files` table holds both staging and library video probe data; library `import` self-probes via `Stage.probeWithCrc` and verifies CRCs against folder-name claims; sidecars are deleted).

Key existing facts the implementer must know:

- `files` table is keyed on `(crc32, size_bytes)`, holds file-intrinsic probe data, has `original_path`/`original_name` as mutable "last known location" columns. CRC is verified (computed from bytes), not trusted from filenames.
- `library_movies` is keyed on `folder_checksum` (the CRC *parsed from the folder name* — a claim), and now also has `crc32`/`size_bytes` columns holding the *verified* CRC (equal to `folder_checksum` when the name was honest; the mismatch query `WHERE crc32 <> folder_checksum` is the integrity audit).
- `import` (`batchedRun` → `batchedMain` → `collectFolders` → `processBatch` → `processOne`) currently walks `library.roots`, and has a resume gate (`alreadyImported`: skip folders whose `library_movies` row exists with non-null `crc32`) plus a `--force` flag.
- The compiled binary is `bin/unidork-import.uc`, produced by `compile cli ./bin/unidork-import` in UCM. **Critical workflow note: `unidork import` runs the compiled `.uc`, NOT the live UCM namespace.** Test changes via `run <thunk>` against the namespace first, then `compile cli ./bin/unidork-import` + `direnv reload` to update the binary. Mixing these (editing namespace, testing via `unidork`) silently tests stale code — this bit the previous session repeatedly.
- The orchestrator (`nix/orchestrator.nix`) is a `writeShellApplication` that exports `UNIDORK_*` env vars (normalized scheme: `UNIDORK_DB_HOST/PORT/USER/NAME`, `UNIDORK_CACHE_FFPROBE/STAGE`, `UNIDORK_PATH_CONFIG/STAGING/RENAME_TARGET`, `UNIDORK_FORMAT_MOVIE`, `UNIDORK_TOKEN_TMDB/SUB`, `UNIDORK_TUNE_PROBE_JOBS/SUB_LANGS`) and dispatches subcommands to the binary.
- `Config` is a record: `Config.Db`, `Config.Cache`, `Config.Paths`, `Config.Tuning` sub-records. Field accessors on sub-records use the full path (`Config.Paths.staging`, not `Config.staging`). Constructors for dotted-name records double the name (`Config.Paths.Paths`, `Config.Tuning.Tuning`).
- A known cosmetic issue: postgres connection teardown prints benign-but-ugly stderr ("threadWait... Bad file descriptor", "Unexpected EOF", "Postgres abandoned connection"). This is upstream-library noise escaping a filter; an issue is filed. **Do not attempt to fix this as part of this work — it is unrelated and not in scope.**

## Design decisions already made (do not relitigate)

1. **Three import commands replace one.** `import-buffer` (scans rename buffer), `import-library` (scans real library, = current behavior), `import-all` (runs both in sequence, buffer first). This keeps the prototype buffer flow separate from production library until trusted; the user invokes them deliberately.

2. **`move` is the promotion verb**: relocates a folder from the rename buffer to the real library, makes it official in the database. It is a single Unison operation (matches the other commands; not split into bash+Unison).

3. **rsync, shelled from Unison**, is the relocation mechanism — not `mv`. rsync provides transfer integrity (dest bytes == source bytes, verified) regardless of filesystem boundary. Combined with the trusted DB CRC32 (source bytes == what-was-verified-at-probe-time), this gives end-to-end integrity without recomputing the CRC32 at the destination. `move` shells `Process.start "rsync" [...]`, parses exit code, proceeds with DB updates only on rsync success.

4. **The move trust gate keys on `files`, NOT `library_movies`.** The principle: "a file may only travel on a verified checksum." A file in the buffer has a `files` row (CRC verified during staging probe) but no `library_movies` row (import hasn't run on it). So the gate is: query `files WHERE original_path = <current buffer location>`.
   - **Found with CRC** → verified, trust it. rsync-move, update `files.original_path`, write `library_movies`. No recompute.
   - **Not found** → never probed. `Stage.probeWithCrc` at the *current* (buffer) location first, write the `files` row, *then* proceed with the move. ("Move also probes, only if necessary.")

5. **Destination-is-library is enforced in code.** `move` refuses to relocate anywhere not under the configured library root. The destination library folder must be a configured library path; the code checks and errors otherwise.

6. **`move` writes the `library_movies` promotion row.** Promotion (becoming a library citizen) happens at move time, and `move` is the writer. `import-buffer` does NOT pre-promote — buffer files stay out of `library_movies` until `move`. (This keeps prototype separate from production per the user's explicit instruction to not mix prototype flows into production tables prematurely. Note: this means `import-buffer`'s exact responsibility needs clarification — see Open Questions.)

7. **Config gains two distinct path concepts**: a **rename buffer root** (where rename-output lands, currently `rename.targetDir`) and a **real library root** (promotion destination). These are different fields. `import-library` scans the library root; `import-buffer` scans the buffer root; `move` reads buffer, writes library.

8. **Lookup key for the source file's `files` row is `original_path`** (the file's current location). Re-deriving `(crc32, size_bytes)` would mean recomputing the CRC — the exact cost being avoided.

9. **rsync invocation caveat**: for a destination that doesn't exist yet (fresh promotion), plain `rsync --remove-source-files` already gives transfer integrity (rsync always checksums what it transfers to confirm receipt). `--checksum` only matters for skip-if-identical when the dest exists, and costs a full read of both ends. The implementer should NOT cargo-cult `--checksum`; use the invocation that gives transfer integrity for a fresh-destination move without an unnecessary full re-read. Confirm exact flags against this reasoning (likely `rsync -a --remove-source-files --partial` plus whatever gives a clean verified transfer; `--remove-source-files` only deletes source on verified success). Verify rsync semantics rather than assuming.

## Work breakdown (dependency order)

### Phase 1 — Config additions

- Add to `nix/config.nix`: a `renameBuffer` path (migrate the current `rename.targetDir` value here) and a `library` *destination* path (single root for promotion, distinct from the scan-list `library.roots`). Decide whether `library.roots` (the scan list) and the promotion-destination root are the same value or separate; likely the destination is one specific root, while `roots` is the scan list — clarify (see Open Questions).
- Add corresponding `UNIDORK_PATH_*` exports to `nix/orchestrator.nix` and `nix/devshell.nix` (normalized naming, e.g. `UNIDORK_PATH_BUFFER`, `UNIDORK_PATH_LIBRARY`).
- Extend the Unison `Config.Paths` record with the new fields, and `Config.fromEnv` to read the new env vars with fallback defaults. Remember: dotted-record constructor is `Config.Paths.Paths`; accessors are `Config.Paths.<field>`.
- This phase is verifiable in isolation: `Config.fromEnv` typechecks and the new fields read.

### Phase 2 — Split import into three commands

- `import-library`: the existing `import` flow unchanged, scanning the library root(s). Rename the current `import`/`batchedRun` path or alias it.
- `import-buffer`: same machinery (`collectFolders`/`processBatch`/`processOne`) but pointed at the buffer root. **Open question on its DB target** (see below) — does it write `library_movies`, or `files`-only, or is it a no-op placeholder until move is trusted?
- `import-all`: runs `import-buffer` then `import-library` in sequence (buffer first per the user). Mirror how `cmd_run` chains stages in the orchestrator — sequence, don't weld.
- Update `cli` dispatch and the orchestrator `case` block with the three verbs.
- The `--force` flag and resume gate carry through to whichever import commands populate `library_movies`.
- Verify: each command runs against its correct root; `import-library` against production behaves exactly as the old `import` did (regression check).

### Phase 3 — `files` path-update command + `library_movies` promotion write

- New prepared command: `UPDATE files SET original_path = ..., original_name = ... WHERE crc32 = ... AND size_bytes = ...` (key on content identity, not the old path).
- New prepared query: lookup `files WHERE original_path = <buffer location>` returning the row (CRC, size, probe data) — the move trust gate.
- The `library_movies` promotion write reuses the existing `upsertWith`/`upsertMovieSql` path (which already writes verified `crc32`/`size_bytes`), invoked at move time with the destination path.

### Phase 4 — `move` operation

- New Unison `Library.moveToLibrary` (or similar): per buffer folder:
  1. Find the video file in the buffer folder; get its current path.
  2. Query `files` by `original_path`. Found-with-CRC → trust; not-found → `Stage.probeWithCrc` at current location, write `files` row, continue.
  3. Compute destination path under the configured library root (folder keeps its rename-assigned name). **Enforce** destination is under the library root; error otherwise.
  4. Shell `rsync` (correct flags per Phase 0 caveat) to relocate the folder buffer → library. Parse exit code.
  5. On rsync success: `UPDATE files SET original_path/original_name` to the new location; write the `library_movies` promotion row. On rsync failure: touch nothing in the DB, report the error.
- New `move` subcommand in `cli` and orchestrator.
- The move carries the *whole folder* (video + .nfo + subtitles + artwork), not just the video; the `files`/`library_movies` updates concern the video inside it.

### Phase 5 — Validation

- Test `move` via `run <thunk>` against the namespace first (per the compiled-binary workflow note).
- Validate end-to-end on the *test buffer folder* (not production library): a buffer file with a `files` row gets rsync-moved, `files.original_path` updates to the library location, `library_movies` row appears, source folder is gone from buffer, dest folder is in library, CRC never recomputed (confirm by absence of rhash cost / by timing).
- Validate the not-found path: a buffer file with no `files` row gets probed-then-moved.
- Validate the enforcement: attempting to move to a non-library destination errors.
- Only after the buffer flow is proven end-to-end does the user consider running it against real production data — per the explicit "don't throw prototypes into production prematurely" instruction.

## Open questions the implementing session MUST resolve before coding

These were not fully settled and the implementer should ask rather than guess:

1. **What does `import-buffer` actually write?** Decision 6 says `move` is the sole writer of `library_movies` for buffer files, to keep prototype out of production. But then what is `import-buffer`'s job — does it write `files` rows only (staging-probe the buffer so move's trust gate finds them), or is it redundant with what `probe-stage`/`resolve` already did to produce the buffer contents? Possibly `import-buffer` is unnecessary if rename-output already has `files` rows from staging. Clarify the buffer's DB state at rest and what, if anything, `import-buffer` adds.

2. **Is the promotion-destination library root the same as `library.roots` (the scan list), or a separate single field?** `library.roots` is a list scanned by import; the move destination is one root. Resolve whether they share a value or are distinct config.

3. **Exact rsync flags** — per Phase 0 caveat, confirm the invocation that gives verified transfer for a fresh-destination folder move with `--remove-source-files`, without an unnecessary `--checksum` full-reread. Verify against actual rsync semantics.

4. **Folder-name source for the destination** — the buffer folder already has its rename-assigned name (`Movie (Year) [...] ~CRC`). Confirm the destination keeps that exact folder name under the library root (almost certainly yes), so move is a pure relocation, not a re-render.

## Constraints / style (from user preferences)

- Whole pasteable file/definition outputs, no patchy fragments.
- No em dashes in delivered code/comments.
- Unison gotchas seen this project: dotted-record constructors double the name; sub-record accessors use full path; functions taking args and returning `()` have no leading `do` (only `'{...} ()` thunks do); `compile` the binary after namespace `update` or `unidork` runs stale code; keep the scratch file small and `update` aggressively (large scratch causes minutes-long recheck).
- `getEnv`, `Failure.message`, `Stage.probeWithCrc`, `Stage.upsertFileWith`, `Process.start`, `renameFile`/`Process` for shelling are all confirmed present in this codebase's API surface.
- The implementer cannot compile against the user's `@runarorama/postgres`/`@unison/http` libraries remotely; deliver internally-consistent code and flag every unverifiable identifier.