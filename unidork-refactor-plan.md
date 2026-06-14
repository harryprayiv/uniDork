# uniDork Unification Refactor Plan

Document version: 1.0
Date: 2026-06-07
Owner: Harry (PissiBoi), machine winsmuth, runtime user bismuth
Current position: **Phase 4 in progress.** TV move brought to full movie-safety parity (4.4 step 1, executed and verified on live library, 15 shows). Probe and resolve assessed and intentionally left as separate paths (D13, D14). Remaining: 4.4 step 2 (assess unified move driver), 4.3 (rename parity).
---

## 0. Handoff protocol (read this first if you are an LLM)

This document is the single source of truth for a multi-session refactor of uniDork, a Unison-language media pipeline (movies + TV) backed by PostgreSQL and packaged with Nix flakes. If you are picking up mid-refactor:

1. Read Section 11 (Status Tracker) to find the current phase and the last completed checkbox.
2. Read Section 8 (Unison working agreements) before producing any code. These conventions are non-negotiable and were established through painful trial and error in prior sessions.
3. All code is delivered as **one complete canonical scratch payload** per session: a single pasteable block the user adds to a UCM scratch file. Never diffs, never "change this line", never partial snippets.
4. New SQL command/query definitions and helper functions are delivered **without type signatures**. The runarorama postgres library's codec builders produce inferred effect-variable signatures (g, g1, g46...) that do not round-trip through the pretty-printer reliably.
5. Destructive operations (anything that moves, renames, or deletes files, or drops/truncates tables) must be called out explicitly and gated. Never bury one in a script.
6. Shell commands shown to the user must be fish-compatible.
7. After any UCM code change, the compiled binary must be regenerated (`compile` in UCM to refresh `bin/unidork-import.uc`, exact invocation in Section 8.4). A stale compiled binary is the historically most common source of "the feature I just wrote does not exist" confusion.

---

## 1. Goals and non-goals

### Goals
1. **Parity**: every safety and quality feature present in one pipeline (movies or TV) exists in both, unless a documented reason says otherwise.
2. **Deduplication**: one shared kernel and shared drivers; movie/TV variance isolated into small, explicit specification values.
3. **Idiomatic Unison**: abilities used where they pay rent (effects, testability, dry-run), plain parameterization where they do not; dead code removed; builtins replace shelling out where builtins exist.
4. **Stretch**: migrate file identity from CRC32 to a collision-resistant hash without slowing the pipeline or churning the existing library's filenames.

### Non-goals
- No new features beyond parity (no new metadata sources, no UI).
- No renaming of files already promoted to the library. The on-disk library is treated as settled.
- No Docker, no JS/Python/TS tooling. Nix flakes only.

---

## 2. Current state inventory

### 2.1 Live entry points (cli verb -> call chain)

| Verb | Chain | Destructive |
|---|---|---|
| `probe-stage` | `Stage.runProbeStage` -> `runProbeAt` (intake, "staging") | no |
| `import-buffer` / `reconcile` | `runProbeAt` (buffer, "buffer") | no |
| `import-library` | `uniDork.batchedRun` -> `batchedMain` -> `processBatch` -> `processOne` -> `Db.upsertWith` | no (DB writes only) |
| `import-all` | reconcile + import-library | no |
| `identify` | `Resolve.identify` -> `runWith true` (dry run) | no |
| `resolve` | `Resolve.run` -> `resolveOne` -> writes `associations` | DB only |
| `rename` | `Rename.runNew` -> `executeOne` | **yes** (moves files into buffer, deletes crc-tag duplicates) |
| `process` | probe-stage + resolve + rename | **yes** |
| `move` | `Move.run` -> `moveBatch` -> `moveChunk` -> `moveOne` | **yes** (promotes to library) |
| `tv-init` | `Tv.Db.createSchema` | DDL only |
| `tv-probe` | `Tv.Stage.runProbeTv` -> `runProbeAtTv` | no |
| `tv-identify` | `Tv.Resolve.identify` (dry run) | no |
| `tv-resolve` | `Tv.Resolve.run` -> `Tv.Resolve.resolveOne` | DB only |
| `tv-rename` | `Tv.Rename.applyTv` -> `executeEpisode` | **yes** |
| `tv-process` | tv-probe + tv-resolve + tv-rename | **yes** |
| `tv-move` | `Tv.Move.run` -> `moveShow` | **yes** (merges into library) |

### 2.2 Schema inventory

Created by `Db.createSchema` (movies): `library_movies`, child tables (`movie_video_streams`, `movie_audio_tracks`, `movie_subtitles`, `movie_actors`, `movie_genres`, `movie_tags`, `movie_countries`, `movie_studios`, `movie_directors`, `movie_credits`), `movies` (tmdb_id PK, via `tmdbMoviesDdl`), `files`, `probe_cache`, `associations`, `tmdb_search_cache`, indexes.

Created by `Tv.Db.createSchema`: `shows`, `episodes`, `episode_associations`, `tmdb_tv_search_cache`, `tmdb_season_cache`, plus `files` ALTERs (media_kind, hint_show_tmdb_id, hint_imdb_id, hint_season, hint_episode).

**Referenced but never created** (orphan tables, queries silently fail through `catch`):
- `stage_probes` (referenced by `Stage.selectProbeSql`, `Stage.selectLargestInFolderSql`, `Stage.upsertProbeSql`, `Rename.deleteProbeBySourceSql`, `Rename.selectRenamedTargetByCrcSql`)
- `rename_log` (referenced by `Rename.insertLogSql`, `Rename.selectRenamedTargetByCrcSql`)

Both appear in `Db.dropDdl` but in no create path. See 2.4 for the live bug this causes.

### 2.3 Dead or broken code (candidates for deletion)

Verify each with `dependents <name>` in UCM before deleting. This inventory was built from a flat dump and may miss callers.

**Old kodi_id movies schema, superseded by tmdbMoviesDdl, now broken at runtime** (the live `movies` table has no `kodi_id` column):
`Db.createTableSql`, `Db.moviesDdl`, `Db.createIndexSql`, `Db.insertMovieSql`, `Db.updateMovieSql`, `Db.updateArraysSql`, `Db.upsertSql`, `Db.upsertMovie`, `Db.upsertOne`, `Db.upsertMovies`, `Db.smokeTest`, `actorsAsJson`, `audiosAsJson`, `subtitlesAsJson`, `textsAsJson` (last four only if their sole callers are the above).

**stage_probes / rename_log era** (querying tables that do not exist):
`Stage.upsertProbeSql`, `Stage.upsertProbeWith`, `Stage.upsertBatch`, `Stage.readFromDb`, `Stage.readSidecar`, `Stage.selectProbeSql`, `Stage.selectLargestInFolderSql` (see bug below), `Stage.largestInFolderWith` (caller of it), `Stage.sidecarPath`, `Stage.cacheRoot`, `Rename.deleteProbeBySourceSql`, `Rename.deleteProbeRowWith`, `Rename.selectRenamedTargetByCrcSql`, `Rename.insertLogSql`, `Rename.writeOutcome`, `Rename.writeOutcomeWith`, `Rename.logDir`, `Rename.Outcome.parts` (if only the log writers use it), `Rename.Outcome.toJson` (verify).

**File-based caches superseded by DB caches**:
`Tmdb.cachePath`, `Tmdb.cacheRoot`, `Tmdb.readCache`, `Tmdb.writeCacheEntry`, `Tmdb.cachedDetails`, `Tmdb.cachedDetailsRaw`, `Tmdb.detailsCachePath`, `Tmdb.detailsCacheRoot`, `Tmdb.cachedSearch`, `Tmdb.readDbCache`, `Tmdb.writeDbCache` (the non-`With` per-call-connection variants), `Tmdb.reportFolder`, `Tmdb.reportLooseVideo` (superseded by the `With` variants).

**Hardcoded-path constants made redundant by Config** (replace remaining uses with Config threading, then delete):
`Subs.tokenPath`, `Subs.readToken`, `Tmdb.tokenPath`, `Tmdb.readToken`, `Tmdb.stagingDir`, `Rename.subLanguages`, `Rename.fileFormat`, `Rename.folderFormat`, `Stage.probeJobs` (Config.Tuning exists), `Rename.isStagingChild`, `Rename.maybeFetchSubs` (the Details variant; `maybeFetchSubsM` is the live one), `Rename.fileBaseName`, `Rename.folderName`, `Rename.applyFormat`, `Rename.resolveToken`, `Rename.Context` (the Tmdb.Result-based render path looks superseded by MovieRecord rendering).

**Dev scratch** (move to a `dev` namespace or delete): `debugFailureText`, `debugNfo`, `demo`, `moveTest`, `moveTestOne`, `probeBufferTest`, `probeStageTest`, `resolveTest`, `tvIdentifyTest`, `tvProbeTest`, `tvRenameTest`, `tvResolveTest`, `mig`, `initDb`, `resetDb`, `Tv.initDb`, `showPaths`.

**Stubs**: `Nfo.extractChecksum` returns None unconditionally.

### 2.4 Live bugs found during planning review

These are findings from reading the code, not from runtime evidence. Each gets a fix slot in the phase plan.

1. **Data-loss risk in duplicate detection (both pipelines).** `Rename.targetHasCrc` decides a file is a duplicate by substring-matching `~CRC32` in target-folder filenames, and on a hit the source file is **deleted** (`DuplicateRemoved`). CRC32 is 32 bits. Within one TV season folder holding 20+ episodes, a chance crc-tag collision against an unrelated episode would silently delete a source episode. The check uses neither size nor full identity. Fix: duplicate determination must verify against DB identity (hash AND size_bytes), with the filename tag treated as a display label only. This fix is independent of the checksum migration and lands early (Phase 0.5).
2. **`identify` runtime tiebreaker is silently dead.** `Tmdb.reportFolderWith` queries `stage_probes` via `largestInFolderWith` to get probe minutes for `pickBestWithRuntime`. The table does not exist; the `catch` swallows the error and returns None, so the runtime tiebreaker never fires in `identify`. Either query `files.probe_json` instead or accept and document the degradation. (`resolve` is unaffected: it gets duration from `files`.)
3. **TV cross-filesystem move rsyncs directly into the live library.** `Tv.Move.moveShow` rsyncs to the final destination with no `.unidork-partial` staging and no sweep. A crash mid-rsync leaves a half-written show in the library, and in the merge case it rsyncs **into an existing live show folder**. Movies already solved this (partialRoot, sweepPartial, stage-then-commit). TV must adopt it.
4. **TV move has no identity verification.** `Tv.Move.updatePathSql` updates `files` rows keyed only by `original_path`, with no crc/size re-verification against disk. Movies verify identity (`loadIdentity`, size check, re-probe fallback) before touching DB. TV must adopt it.
5. **`hint_season` / `hint_episode` are written, never read.** `Tv.Stage.episodeHints` extracts them, `Tv.Stage.upsertFileSql` stores them, `Tv.Resolve.resolveOne` re-parses `original_name` from scratch. Either consume the hints in resolve or stop collecting them.
6. **Movie resolve ignores IMDB ids.** TV captures `hint_imdb_id` and has a TMDB `find` fallback; movies parse NFO imdb ids (`Nfo.parseMovieId`) but `Resolve.FileRow` has no imdb field and no find-by-imdb path. Parity item.
7. **`Db.smokeTest` writes to a schema that no longer exists** (kodi_id columns). It would fail at runtime. Covered by the 2.3 purge.

---

## 3. Parity gap matrix

Legend: M = movies have it, T = TV has it, target = both.

| Capability | M | T | Plan |
|---|---|---|---|
| Probe: cached gating by (path, mtime, size) | yes | yes | shared driver |
| Probe: recursive directory walk with depth limit, sample filtering | no (1 level + loose) | yes (depth 4) | spec field: walk strategy |
| Resolve: NFO tmdb id hint | yes | yes | shared |
| Resolve: IMDB id hint + TMDB find fallback | **no** | yes | adopt for movies |
| Resolve: runtime tiebreaker against TMDB runtime | yes | **no** | adopt for TV (episode runtimes exist in season cache) |
| Resolve: consumes stored season/episode hints | n/a | **no** (re-parses) | wire hints in |
| Rename: enforceUnderRoot on source and destination | **no** | yes | adopt for movies |
| Rename: duplicate check verified against DB identity | **no** (filename tag only) | **no** | fix both (bug 1) |
| Rename: subtitle fetch on promote | yes | **no** | adopt for TV (subdl type=tv; verify API params, Section 9) |
| Rename: sidecar NFO generation | yes (movie.nfo) | yes (tvshow.nfo + episode nfo) | spec hook |
| Move: verified file identity before promotion | yes | **no** | adopt for TV (bug 4) |
| Move: chunked batches, fresh prepared statements per chunk (OOM fix) | yes | **no** | adopt for TV |
| Move: progress + ETA reporting | yes | **no** | adopt for TV |
| Move: stage-then-commit with partial root + crash sweep | yes | **no** | adopt for TV (bug 3) |
| Move: merge into existing destination | no (aborts) | yes | keep asymmetric **by design**: movies abort (a duplicate movie folder is an anomaly), shows merge (a show accretes seasons). Document in decision log. |
| Move: details fetch gate before promotion | yes | n/a (sidecars written at rename) | document |
| Library reconciliation (import-library equivalent) | yes | **no** | out of scope for this refactor; logged as future work |
| Audio default selection (Relang) | standalone, unwired | unwired | out of scope; future work |

---

## 4. Design assessment: abilities vs parameterization

Blunt version, since that was requested.

**The movie/TV split is mostly a data-shape problem, and abilities are the wrong tool for data-shape variance.** Unison ability operations have fixed monomorphic-per-instantiation signatures. There are no associated types. A hypothetical `ability Media` with `movieHandler` and `tvHandler` would force every operation onto a lowest-common-denominator row type, which means encoding episodes as degenerate movies. That representation collapse is exactly the category of thinking that produced the `selectRenamableSql` stage-filter incident. Rejected.

**Where abilities do pay rent here is effects**, and there are three concrete wins:

1. **`Proc` ability** (subprocess execution). Today `Process.start` + `drainHandle` + exit-code plumbing is hand-rolled in at least eight places (ffprobe, rhash, stat x2, date, mv, rm, rmdir, rsync). One ability, one IO handler, one scripted pure handler for tests.
2. **`Fs` ability** (file mutations: move, remove, removeTree, mkdirp, write). The IO handler does the real thing. A **dry-run handler** performs real reads but logs intended mutations instead of executing them. This gives `rename --dry-run` and `move --dry-run` for free across both pipelines, which directly serves the standing requirement that destructive operations be surfaced explicitly. Caveat to document: dry-run state diverges (a simulated move is invisible to a later exists-check), acceptable for plan preview.
3. **`Catalog`-style abilities over Postgres** (e.g. `FileCatalog` for shared file-row ops, `MovieCatalog`, `TvCatalog` for kind-specific ops, `MetaApi` for TMDB/subs with the cache living in the handler). This is the structural fix for the worst smell in the codebase: `Move.moveOne` threads **25+ prepared statements as positional arguments**, and `processOne` is similar. Handlers close over prepared statements opened once per connection, so driver code signatures shrink to the domain row. Bonus: an in-memory handler enables driver tests without Postgres, the same pattern already proven in cheeblr's effectful layer.

**Kind variance (movie vs TV) is handled by plain values**: small spec records of functions passed to shared drivers. No cleverness. The spec for rename, for example, carries: select-jobs catalog op, target renderer, sidecar writer, post-rename catalog op. Everything else (existence checks, root enforcement, duplicate verification, mkdir, rename, probe-cache update, outcome reporting) is one shared body.

Net judgment: abilities for Proc/Fs/Catalog/MetaApi, records of functions for movie/TV, and a large amount of plain old extraction of pure helpers. Anyone proposing a `Media` ability with kind-switching handlers should be overruled by this document.

---

## 5. Target architecture

Namespace sketch (final names settled in Phase 1; uniqueness rules in 5.6):

```
kernel.format      -- FormatPart parse/render, token tables (pure)
kernel.naming      -- sanitize, tighten, vfTag, vcTag, acTag, channelsTag,
                      gigabytes, mbps, sortTitle, aspectRatio (pure)
kernel.score       -- normalize, tokenOverlapPercent, generic pickBest
                      (popularity accessor passed in), year scoring (pure)
kernel.release     -- parseReleaseName, parseEpisodeName, parseShowFolder,
                      tokenize, year extraction (pure)
fx.Proc            -- ability + IO handler + scripted test handler
fx.Fs              -- ability + IO handler + dryRun handler
fx.Clock           -- now : Nat (epoch seconds); replaces shelling to date
db.FileCatalog     -- ability: upsertFile, loadIdentity, promoteToBuffer,
                      promoteToLibrary, probeCache ops
db.MovieCatalog    -- ability: associations, movie details cache, library upsert
db.TvCatalog       -- ability: episode associations, shows/episodes/season cache
api.MetaApi        -- ability: TMDB movie/tv/find + subdl; cached handler wraps
                      http handler, prepared statements live in handler
media.probe        -- shared probe driver + ProbeSpec (walk, hints, kind)
media.resolve      -- shared resolve scaffold + ResolveSpec
media.rename       -- shared rename driver + RenameSpec
media.move         -- shared move driver + MoveSpec (merge policy field)
movie.*            -- movie specs, movie-only types, NFO read/write
tv.*               -- tv specs, tv-only types, NFO read/write
app.cli            -- verb dispatch, Config
```

### 5.1 Pure kernel
Extraction only, no behavior change. All existing `test>` watch expressions move with their functions and must keep passing. New tests added for `pickBest` generalization (movie and TV instantiations must reproduce current behavior bit for bit).

### 5.2 Effect layer
`Proc`, `Fs`, `Clock` first (mechanical, low risk). Then `MetaApi` and the catalogs (higher risk: connection/handler lifetime must match the current one-connection-per-chunk discipline that fixed the OOM; the handler is installed inside `singleIO ... do`, per chunk, exactly where prepared statements are created today).

### 5.3 Specs
One record per driver. Fields are functions requiring the relevant abilities. Spec values are plain top-level definitions (`movie.renameSpec`, `tv.renameSpec`). Delivered without type signatures (Section 8.2).

### 5.4 Drivers
Each driver's shared body is the **union of both pipelines' safety checks**, not the intersection. Order of checks in rename, for canonical reference: source under intake root -> probe parse -> render targets -> destination under buffer root -> duplicate check (DB identity: hash AND size) -> source exists -> destination conflict -> mkdir -> sidecars -> rename -> promote -> probe cache -> outcome.

Move driver: sweep partial root -> enumerate -> plan totals -> chunk (size 25) -> per folder: identity verify (re-probe fallback) -> details gate (spec hook; no-op for TV) -> destination policy (abort vs merge, from spec) -> same-device check -> atomic rename, or rsync to partial root then commit -> source cleanup -> catalog updates -> progress report.

### 5.5 Schema changes
- New: nothing required for unification except optionally a generic API cache. Proposal: `api_cache (cache_kind TEXT, cache_key TEXT, payload TEXT, fetched_at, PRIMARY KEY (cache_kind, cache_key))` replacing `tmdb_search_cache`, `tmdb_tv_search_cache`, `tmdb_season_cache` (kinds: `movie_search`, `tv_search`, `tv_season`; keys serialized as `title|year`, `showId|season`). Old tables retained read-only during one transition release, then dropped. This deletes four read/write SQL pairs and the duplicated CachedSearch types. Decision left to Harry at Phase 3 start; the unification works without it.
- Removed from drop list after purge: `stage_probes`, `rename_log` (and their drop statements kept one release for hygiene).
- Checksum columns: Phase 5 only (Section 6).

### 5.6 Naming conventions (suffix ambiguity defense)
Prior sessions lost real time to Unison type-name suffix ambiguity. Rules for all new code:
- Record field names unique across any two types likely to be `use`d in the same body (e.g. `RenameSpec.renderTargets` not `RenameSpec.render` if anything else has `render`).
- Constructors named after their type when the bare name is common (`ProbeSpec.ProbeSpec`).
- No new type may share a final segment with an existing one (`Outcome` is already taken twice; new outcome types get fully distinct names like `MoveReport`).
- Prefer fully qualified names over `use` in any function touching both `movie.*` and `tv.*`.

---

## 6. Checksum migration (stretch goal)

### 6.1 The honest math
"Guarantee no collisions ever" is not achievable by any hash; what is achievable is collision probability so small it is below hardware-error noise. CRC32 does not clear that bar: 32 bits gives a 50% birthday collision around 77k items, roughly 1.2% at 10k, 25% at 50k. A TV library multiplies file counts by an order of magnitude over a movie library, so this stopped being theoretical the day the TV pipeline landed. The current DB identity `(crc32, size_bytes)` mitigates accidental DB collisions substantially, but the filename-tag duplicate check (bug 1) uses crc alone, and that path deletes files.

A 256-bit hash (BLAKE3) puts accidental collision probability around 2^-128 scale for any realistic n, plus adversarial collision resistance. That is the engineering meaning of "never".

### 6.2 The performance answer: yes, cake is had and eaten
The media lives on a NAS (`/home/bismuth/NAS/...`), so hashing is I/O-bound at network/disk speed (hundreds of MB/s to low GB/s). Single-threaded BLAKE3 with SIMD runs several GB/s; it will idle waiting on the NAS exactly as CRC32 does today. Wall-clock probe time should be indistinguishable. Verify empirically in Phase 5 step 1 with a benchmark on one large file before committing.

Tooling options in nixpkgs, in preference order:
1. `rhash` if the pinned version supports `--blake3` (added in newer RHash releases; **verify**: `rhash --list-hashes` inside the devshell). Best option because rhash computes multiple digests in a single read pass (`rhash --crc32 --blake3`), making the dual-hash transition window one read per file, not two.
2. `b3sum` (official BLAKE3 CLI, definitely in nixpkgs) if rhash lacks it; transition window then costs a second read per file, still I/O-bound and parallel across probe jobs.
3. `xxhsum` XXH128 as a fallback: fastest, 128-bit, but non-cryptographic; only if BLAKE3 tooling is somehow unavailable. Not preferred.

### 6.3 Migration design
- DB: add `blake3 TEXT` to `files` and `library_movies`. Identity remains `UNIQUE (crc32, size_bytes)` during transition; after backfill, add `UNIQUE (blake3)` and flip code identity to blake3 (keep crc32 column for the legacy filename tags, never drop it).
- Probe: compute both digests during transition. After flip, crc32 computed only for the filename display tag of newly named files, or dropped from new names entirely (decision below).
- Backfill: new verb `unidork rehash` walks `files` rows missing blake3, re-reads each file once, fills the column. Read-only with respect to media files. Resumable (per-row commit), chunked, progress-reported via the shared Progress module. Run it against the library at leisure; one full read of the library is the entire cost.
- Filename tags: **do not rename the existing library.** New renames get a new token `{b3short}` (first 10 hex chars of blake3, 40 bits: comfortable as a per-folder human label since authority lives in the DB). `{crc32}` token remains supported indefinitely for format-string compatibility. Default formats in `nix/config.nix` switch to `{b3short}` at flip time, Harry's call.
- Duplicate detection: already fixed in Phase 0.5 to verify against DB identity; after the flip it verifies blake3 + size. Filename tags never again decide a deletion.
- Rollback: blake3 column is additive; flipping identity back to (crc32, size) is a code-only revert at any point before old-name-tag generation stops.

---

## 7. Phased execution plan

Global invariants, every phase:
- All UCM `test>` watch expressions pass (`test` in UCM).
- `unidork identify` and `unidork tv-identify` output is unchanged on the standing fixture intake, except where a phase explicitly changes a behavior (and then the change is named in the phase notes).
- No destructive verb is executed without Harry's explicit go in that session.
- Each phase ends with a recompiled `bin/unidork-import.uc` and a `nix build` check.

### Phase 0: Baseline and purge
Objective: shrink the codebase to its live surface before building on it.
- [x] 0.1 Dependents audit complete (2026-06-07, static pass against the provided dump). Confirmed kill list delivered in session 1. Caveat: the dump is incomplete (`fetchDetailsBody`, `readShowBodyWith` referenced but not defined in it), so each deletion must clear `dependents` in UCM before execution; skipped lines get reported back.
- [x] 0.2 Dead code deleted (tier-1 batches + tier-2 sequence). `exampleMovie` and all live `test>` kept. (Tier-2 execution confirmed implicitly by clean test run; explicit confirmation requested.)
- [x] 0.3 `stage_probes` / `rename_log` references removed with the kill list; drop statements remain in `dropDdl` for one release.
- [x] 0.4 Tiebreaker fix landed (`Stage.selectProbeJsonByPathSql` + `probeMinutesForPathWith`, wired through `uniDork.identify` and the report functions). Discovery during 0.6: `uniDork.identify` is unreachable from the cli; `unidork identify` routes to `Resolve.identify`, which always had a working tiebreaker. See D11.
- [x] 0.5 Duplicate-detection safety fix landed (`crcTaggedEntries` + `anySizeMatch` in both rename paths; tag match without size match now yields Conflict, never deletion). NOT OPERATIVE until `nix build` + devshell re-entry wraps the new compiled binary.
- [x] 0.6 Verification: 152 tests passing, `status` sane (473 files, 466 library), `identify` and `tv-identify` clean. Outstanding: binary freshness (`nix build` + devshell re-entry) before the next destructive run.
- Deliverable: one scratch payload (deletions are expressed by `delete.term` / `delete.type` UCM commands listed in the session notes, not in the scratch file) plus the 0.4/0.5 code.
- Destructive ops: none. DB DDL: none.

### Phase 1: Pure kernel extraction
Objective: move pure helpers into `kernel.*` with zero behavior change.
- [x] 1.1 AMENDED per D10: no physical namespace moves. Unison names are metadata over hashes; sixty single-name `move.term` commands buy organization, not deduplication. Existing pure helpers stay in place, Section 5.1 is the kernel-by-convention map, and only NEW shared code lands under `kernel.*` / `fx.*` / `db.*`.
- [ ] 1.2 `kernel.score`: generalize `pickBest`/`popularityWinner`/`maxScore` over a popularity accessor; instantiate for `Tmdb.Result` and `ShowResult`; add tests pinning current tie-break behavior for both.
- [ ] 1.3 Unify `Tmdb.CachedSearch` and `Tv.Tmdb.CachedSearch` into one generic cached-payload type (payload decoder passed in).
- [ ] 1.4 Verification: tests, identify/tv-identify diff-clean, recompile, build.
- Destructive ops: none.

### Phase 2: Effect layer (AMENDED per D12)
Objective: dry-run for all destructive verbs + subprocess consolidation. Abilities deferred to Phase 3 where they are sound (see D12).
- [x] 2.1 AMENDED: `kernel.proc.execute` plain helper (not a Proc ability) consolidates the eight subprocess sites (ffprobe, rhash, stat, date, mv, rm, rmdir, rsync). Builtin checks for stat/date outstanding (Section 9 items 1 and 2; `find` commands issued).
- [x] 2.2 AMENDED: `fx.Fs` dry-run handler dropped as unsound (simulated mutation success would let DB promote/association writes fire against unmoved files). Dry-run is an explicit flag at the driver level, where file and DB mutations are co-located in the non-dry branch and both are suppressed. Re-evaluate handler-based dry-run when Phase 3 Catalog handlers can intercept DB writes too.
- [x] 2.3 `--dry-run` wired for rename, tv-rename, move, tv-move, process, tv-process through cli and orchestrator. New outcome constructors WouldRename/WouldRemoveDuplicate (movies) and EpWouldRename/EpWouldRemoveDuplicate (TV). Contract: dry-run creates, moves, deletes NO files; DB metadata (probe rows, associations, TMDB caches) may still be written.
- [ ] 2.4 MOVED to Phase 3: scripted handlers and driver-level tests land with Catalog/MetaApi where the testing payoff is real.
- [ ] 2.5 Verification: dry-run output reviewed by Harry on real state (rename/move/tv-rename/tv-move all with --dry-run), status counts unchanged except cache counters, then binary freshness rebuild.
- Destructive ops: none until 2.5 sign-off.

### Phase 3: Catalog and MetaApi abilities
Objective: kill prepared-statement threading. Sliced by pipeline path to keep payloads safe; handlers are LOCAL closures in the chunk/driver functions, capturing prepared statements lexically (no statement record, no giant handler signature), installed per chunk inside `singleIO`, preserving the OOM discipline.
- [x] 3.1 Ability layer started: `db.MovieCatalog` (identityFor, recordBufferFile, updateLibraryPath, recordAssociation, saveLibraryMovie) and `api.MetaApi` (movieDetails). Operations grow per slice; FileCatalog/TvCatalog land with their consuming slices.
- [x] 3.2a Move path rewritten: `moveOne dryRun libraryRoot folder` (was 31 params), handlers local to `moveChunk`. moveBatch/run untouched. Delivered, execution pending.
- [x] 3.2b Rename path: delivered as a separate `db.RenameCatalog` ability (priorTargetForCrc, promoteToBuffer, upsertProbeCache, deleteProbeCache) rather than extending MovieCatalog, because Unison handlers must be total over their ability; separate abilities keep each handler clean and leave the move path untouched. executeOne/runStep/runNew shed statement params; handler installed in runNew around the loop; renameNewCombined/cli unchanged. Execution pending.
- [ ] 3.2c Resolve path: MetaApi.searchMovies; rewrite Resolve.*; FIRST in-memory handlers + driver tests land here (absorbs old 2.4 and 3.4), since resolve is DB+API only (no file IO).
- [ ] 3.2d TV paths: `db.TvCatalog` + MetaApi tv operations (search/details/season/find); rewrite Tv.Resolve/Tv.Rename/Tv.Move. Decide then whether the shared buffer/cache ops (promoteToBuffer/upsertProbeCache/deleteProbeCache) get factored into a shared ability or duplicated for TV rename.
- [ ] 3.3 Decide D8 generic `api_cache` table (Section 5.5); if adopted, migration DDL + transition read path.
- [ ] 3.6 Verification per slice: identify/tv-identify diff-clean; dry-run battery; OOM regression check on a 100+ folder batch after 3.2a/3.2b land.
- Destructive ops: fixture pipeline runs with explicit go only.

### Phase 4: Driver unification and parity completion
Objective: one driver per stage, both pipelines on it, gap matrix closed.
- [ ] 4.1 Probe driver + specs (walk strategy, hint extractor, media_kind).
- [ ] 4.2 Resolve scaffold + specs. Parity items land here: movie imdb hint + find fallback (bug 6), TV runtime tiebreaker, TV consumes stored season/episode hints (bug 5).
- [ ] 4.3 Rename driver + specs, with the canonical check order from 5.4. Parity items: movie enforceUnderRoot, TV subtitle fetch (subdl tv params verified per Section 9 first).
- [ ] 4.4 Move driver + specs. Parity items: TV identity verification, chunking, progress, partial-root staging and sweep (bugs 3, 4). Merge policy as spec field, asymmetry documented.
- [ ] 4.5 Delete the superseded per-pipeline implementations.
- [ ] 4.6 Verification: full dry-run + real fixture pass both pipelines; crash-recovery test for TV move (kill rsync mid-transfer, confirm sweep + clean retry); duplicate-detection test (planted tag collision must yield Conflict, not deletion).
- Destructive ops: fixture runs and the crash test, explicit go each.



### Phase 5 (stretch): Checksum migration
- [ ] 5.1 Verify tooling: `rhash --list-hashes` for blake3; else add `b3sum` to devshell/orchestrator runtimeInputs. Benchmark one large NAS file: crc32-only vs dual-hash wall clock; record numbers in this document.
- [ ] 5.2 DDL: `blake3 TEXT` on `files`, `library_movies`; nullable, no constraint yet.
- [ ] 5.3 Probe computes dual hashes; all writes fill both columns.
- [ ] 5.4 `unidork rehash` backfill verb (read-only on media, resumable, progress-reported).
- [ ] 5.5 After backfill completes: `UNIQUE` on blake3, identity flip in code, duplicate detection on blake3 + size, `{b3short}` token added, default formats decision.
- [ ] 5.6 Rollback note: 5.2 through 5.4 are additive and reversible; 5.5 is the commit point.
- Destructive ops: none on media files at any step (rehash only reads).

### Phase 6 (optional polish)
- [ ] 6.1 Orchestrator help text, `status` extended (blake3 backfill coverage %, dry-run hints).
- [ ] 6.2 Decide fate of out-of-scope items: TV library reconciliation, Relang wiring.
- [ ] 6.3 Update this document to "complete", archive decision log.

---

## 8. Unison working agreements (established the hard way)

### 8.1 Toolchain gotchas
1. **Stale compiled binary** is the most common source of phantom bugs. After every UCM change: recompile (8.4), confirm with a marker print if in doubt.
2. **UCM scratch file clobbering**: UCM rewrites the scratch file after `update`. Never keep unsaved authored content in the scratch file across an `update`; the canonical payload lives in the chat/session notes, the scratch file is disposable.
3. **`do`-block layout bugs**: prior sessions hit parser issues with certain `do` layouts. When a `do` block misparses inexplicably, restructure to explicit lambda or bind-style rather than fighting indentation.
4. **Pretty-printer round-trip collisions** on inferred type variables: this is why SQL defs and codec-built Commands are delivered **without signatures** (8.2).
5. **Record-type deletion order** (learned in Phase 0): the preferred order is (1) delete the type's helper/decoder terms, (2) delete the auto-generated accessor terms by explicit name (getter, `.set`, `.modify` per field), leaving constructor names intact, (3) `delete.type`, which is batchable across types when all constructors are named. Do NOT lead with `delete.namespace Foo`: it removes the constructor name `Foo.Foo` along with the accessors, after which `delete.type` refuses with "constructors with missing names". **Critical**: a type left in that unnamed-constructor state blocks `delete.type` on OTHER, unrelated types too (the error names the broken type regardless of target). Recovery if it happens: `view Foo` to read the constructor hash (displayed like `#45ro3f1bjk#0`, ordinal included; per-codebase, never copy one from notes), `alias.term <that hash> Foo.Foo`, then `delete.type Foo`. Deletions are name-only; definitions are content-addressed, so a botched order is always recoverable via alias.

### 8.2 Delivery format
- One complete canonical scratch payload per session, fully pasteable.
- No type signatures on: SQL Command/Query definitions, helpers whose inferred signatures contain effect variables from the postgres codec builders, spec records containing effectful function fields (let inference do it).
- Parser-safe layout, learned in Phase 3: NEVER use a multi-line `match`, `if`, or `handle` expression inside parentheses as a function argument (`printLine (match x with ...)` across lines breaks the layout parser); NEVER split a match scrutinee or if condition across lines before `with`/`then`. Bind the value or message to a name first, then use it. Single-line forms inside parens are fine. `match catch do f x with` on ONE line is proven safe; the multi-line variant is not.
- UCM operations that are not code (delete.term, move.term, etc.) listed as an explicit ordered command list alongside the payload.
- Scratch hygiene (learned the hard way in Phase 3): EMPTY scratch.u between major payloads. Never layer a new payload on top of an unlanded one, and never hand-patch individual definitions across several turns. Partial/layered edits leave ghost and duplicate definitions that produce misleading type errors pointing at the wrong place (a `Text` vs `FilePath` mismatch that was really a duplicate `moveChunk`, an `applyTv` arity error that was really a stale copy). When a payload accumulates fixes, redeliver it whole into an empty file.

### 8.3 Runtime discipline
- One Postgres connection per chunk of work (`singleIO` per chunk), prepared statements opened and closed inside it. This pattern is the OOM fix; abilities handlers must preserve it.
- All driver-level errors caught per item; one bad folder never aborts a batch.
- `mv -T --`, `rm -rf --` with path sanity guards stay exactly as paranoid as they are.

### 8.4 Build and run
- UCM compile target: the flake wraps a prebuilt `bin/unidork-import.uc`; regenerate from UCM with `compile cli bin/unidork-import` (verify exact argument form with `help compile` in UCM if it errors; the output must land at `bin/unidork-import.uc`).
- Then `nix build` and run via the `unidork` orchestrator inside the devshell.
- Shell: fish.

---

## 9. Flagged uncertainties (verify before relying on them)

1. **Base IO builtins for stat/mtime/size**: shelling out to `stat` may be unnecessary. In UCM run `find : FilePath ->{IO}` and look for file size / modification time functions before keeping the Proc-based stat. I am not certain of the exact names in the pinned base version.
2. **Base time builtin**: `epochSeconds` shells to `date`. Look for an Instant/EpochTime source in base (`find now`, `find systemTime`) before keeping the Proc version.
3. **`List.foreach` or equivalent in base**: `Db.foreach_` is hand-rolled; check `find foreach` before carrying it into the kernel.
4. **rhash blake3 support** in the pinned nixpkgs rhash: `rhash --list-hashes`.
5. **subdl TV API parameters** for episode subtitles (`type=tv`, season/episode param names): verify against subdl docs before Phase 4.3; do not guess parameter names.
6. **`Tv.Nfo.readShowTmdbId`**: flagged as an open risk at the end of the last session and never verified against a real `tvshow.nfo`. Test it on a fixture before Phase 4.2 makes resolve depend on it more heavily.
7. **UCM `compile` invocation form** (8.4).

---

## 10. Decision log

| # | Decision | Alternatives rejected | Rationale |
|---|---|---|---|
| D1 | No `Media` ability for movie/TV switching | ability with movie/tv handlers | Abilities cannot abstract data-shape variance without representation collapse; collapse caused prior incidents |
| D2 | Abilities for Proc, Fs, Catalog, MetaApi | direct IO everywhere; records of prepared statements | Kills 25-arg threading at the root, enables dry-run and Postgres-free tests |
| D3 | Spec records of functions for kind variance | sum type with match in drivers | Specs keep kind code in kind namespaces; sum type would centralize churn |
| D4 | Move merge policy stays asymmetric (movies abort, shows merge) | unify on merge | A duplicate movie folder signals an anomaly worth human review; a show folder accretes seasons by design |
| D5 | Library never renamed during checksum migration | rename everything to new tags | Full-library churn for zero data-model benefit; DB is the authority, names are labels |
| D6 | BLAKE3 over xxh128/SHA-256 | xxh128 (non-crypto), SHA-256 (slower without SHA-NI) | I/O-bound either way; BLAKE3 gives crypto-grade collision resistance at no wall-clock cost |
| D7 | Duplicate deletion requires DB identity match, never filename tag alone | status quo | 32-bit tag match deleting files is an unacceptable data-loss surface (bug 1) |
| D8 | (open) generic `api_cache` table | keep three cache tables | Decide at Phase 3.3 |
| D9 | (open) default name formats switch to `{b3short}` | keep `{crc32}` in names | Decide at Phase 5.5 |
| D10 | No bulk namespace moves of existing pure helpers | Phase 1.1 as originally written | Unison names are hash metadata; move.term is single-name with no batching; cost exceeds the organizational benefit. New shared code goes under kernel./fx./db. |
| D11 | (open) `uniDork.identify` (verbose TMDB candidate report, incl. reportFolderWith/reportLooseVideoWith, probeMinutesForPathWith) is unreachable from the cli; `unidork identify` routes to `Resolve.identify`. Keep the report path; wire it as a dedicated verb or fold into the Phase 4 resolve spec dry-run reporting | delete it as dead code | Only verbose match report in the codebase; the 0.4 fix made it correct; Phase 4 wants exactly this output for resolve dry runs |

---

## 11. Status tracker

Update this section at the end of every session.

Current phase:        Phase 3 COMPLETE. Phase 4 not started.

Phase 3 slice ledger:
  3.1      ability layer started (MovieCatalog 5 ops, MetaApi movieDetails)   landed
  3.2a     movie move: moveOne 31->3 params, handlers local to moveChunk      landed, runtime-verified
  3.2b     movie rename: RenameCatalog (4 ops), executeOne/runStep/runNew     landed, runtime-verified
  3.2c     movie resolve: MetaApi +searchMovies, ResolveCatalog (recordMatch),
           pickBestWithRuntime/runtimeWinner moved onto {MetaApi},
           4 in-memory handler tests, D11 report path deleted                 landed, built
  3.2d-i   tv resolve: TvMetaApi (searchShows/showDetails/seasonFor/
           findShowByImdbApi) + TvCatalog (recordEpisodeMatch/
           lookupShowByImdbDb), resolveOne + resolveShowPick split out,
           4 in-memory handler tests                                          landed
  3.2d-ii  tv rename: RenameCatalog REUSED for the 4 buffer ops; the 2
           cache-body reads (readShowBodyWith/readSeasonBodyWith) stay
           statement-threaded, so executeEpisode keeps {Postgres} alongside
           {RenameCatalog}; applyTv installs the handler around the loop      landed
  3.2d-iii tv move: LEFT THREADED by decision. moveShow threads exactly ONE
           statement (updatePathSql); not worth an ability op. Phase 3's
           goal (kill multi-statement threading) was met where it mattered.   no change, by decision

Last completed item:  3.2d-ii (tv rename onto reused RenameCatalog). cli recovered
                      and recompiled after it went missing from the codebase
                      during a scratch round-trip (re-pasted verbatim from the
                      Phase-0 dump, compiled clean).

Phase 4 ledger:
  4.1  probe unify       DROPPED (D13). Two paths diverge structurally
                         (traversal topology, root-relative multi-file hint
                         reach, per-title probe cost); only generic scaffolding
                         is shared. A spec would carry ~80% of real logic =
                         function-level D1 collapse. Probe stays two paths.
  4.2  resolve unify     DROPPED (D14). Already shares kernel.score; outcome
                         types disjoint (5 vs 7 ctors); bodies small post
                         ability-rewrite. A spec trades readable branching for
                         a toOutcome mapper. Resolve stays two paths.
  4.4  move parity (step 1)  DONE, executed + verified on live library.
                         db.TvMoveCatalog (identityForEpisode,
                         updateEpisodePathById, updateEpisodePathByName);
                         per-episode identity verify (stored crc+size vs disk,
                         no re-probe fallback, matching movie side which has
                         none); dual-keyed update (verified -> crc+size via
                         reused Move.updateFilePathSql; unverified-but-moved ->
                         original_path via reused Tv.Move.updatePathSql + loud
                         warn); partial-root staging+commit on fresh
                         cross-device; sweepPartial once per run; chunking via
                         Move.moveChunkSize; per-chunk progress. 3.2d-iii
                         reopened and closed: TV move is now on an ability.
                         15 shows promoted, all identity N/N, 0 by-name, 0 fail.
  4.4  move driver (step 2)  NOT STARTED. Assess whether a unified move driver
                         is worth it now that TV and movie bodies are
                         structurally parallel. Open question: merge policy
                         (D4), dual-vs-single update keying, and show-vs-folder
                         unit are the variance; same "is the shared spine worth
                         the spec" question probe and resolve both answered no.
  4.3  rename parity     NOT STARTED. movie enforceUnderRoot; TV subtitle fetch
                         (verify subdl type=tv params per Section 9.5 first).

Bug status:
  bug 4 (TV identity verification)  FIXED + verified.
  bug 3 (partial-root staging)      FIXED for fresh transfers; PARTIALLY
                                    mitigated for merges (merge cross-device
                                    still rsyncs into the live folder because
                                    commitFolder/mv -T cannot land on a
                                    non-empty dir). Full merge-via-partial
                                    (rsync to partial then mergeTree) is a
                                    clean follow-up to transferShow, not yet
                                    written. Not currently exercised: all live
                                    data is same-device.

New decisions:
  D13  probe NOT unified (rationale above).
  D14  resolve NOT unified (rationale above).

Benchmark numbers:    (Phase 5.1, not yet run)
```

Session log:

| Date | Session summary | Items completed |
|---|---|---|
| 2026-06-07 | Plan authored. No code written. | none |
| 2026-06-07 | Phase 0 session 1: static audit done; scratch payload (0.4 tiebreaker fix, 0.5 duplicate-verification fix, new helpers) and ordered kill list delivered. Extra finding: selectLargestInFolderSql was never wired in; identify passed selectProbeSql into the folder-lookup slot, so the tiebreaker was doubly dead. Awaiting execution and 0.6 verification. | 0.1 |
| 2026-06-07 | Phase 0 closed: purge executed (batch deletes; constructor-name recovery for Rename.Context), 152 tests green, status/identify/tv-identify verified. D11 logged: uniDork.identify report path unreachable from cli. Phase 1 amended (D10, no bulk moves) and payload delivered: kernel.score (generalized pickBest with pinned tie-break tests), kernel.cache (generic Cached envelope with legacy "folder" field tolerance), rewritten cachedSearchWith x2, pickBestWithRuntime, pickBestShow, plus three deletion batches for the superseded CachedSearch/score defs. | 0.2 0.3 0.4 0.5 0.6 1.1(amended) |
| 2026-06-07 | Phase 2 executed by Harry (status stable, tests green). Phase 3 sliced into 3.2a-d to bound payload size; slice 3.2a delivered: db.MovieCatalog (5 ops) + api.MetaApi (movieDetails) abilities, moveOne rewritten from 31 params to (dryRun, libraryRoot, folder), handlers as local closures in moveChunk capturing prepared statements (OOM chunk discipline preserved). 2.5 dry-run battery still owed as evidence; builtin find homework outstanding. | 3.1 3.2a |
| 2026-06-07 | Phase 2 + 3a landed clean after a layered-edit thrash (parenthesized multi-line match/if/handle layout errors, then ghost/duplicate definitions in scratch from stacking payloads). Recovered by redelivering the whole Phase 2 + 3a surface into an empty scratch. Local recursive handlers compiled. Lessons recorded: 8.2 parser-safe layout, 8.2 scratch hygiene. Gated on runtime dry-run battery before 3.2b. | (3.2a confirmed landed) |
| 2026-06-07 | 3.2a runtime-verified: `unidork move -- --dry-run` produced a correct per-folder plan, identityFor + movieDetails handlers confirmed firing, status diff-clean. Ability/handler pattern proven, 3.2b unblocked. Separate bug found: the `unidork-import` (`unison run.compiled`) wrapper consumes `--dry-run` as its own option; needs `-- "$@"` in build.nix (manual workaround `<verb> -- --dry-run`). | (3.2a runtime-verified) |
| 2026-06-07 | Two small fixes delivered. Wrapper: append `--` to build.nix makeWrapper add-flags so program args pass through run.compiled (fixes --dry-run UX everywhere, no orchestrator change). Builtin swap: fileStat now uses getTimestamp.impl + getFileSize.impl, epochSeconds uses systemTime.impl, retiring the date fork and the stat fork from the per-file path; statField kept solely for device id (no builtin). `.impl` name-resolution flagged. | (Section 9 builtins applied) |
| 2026-06-07 | Wrapper + builtin swap landed and verified (real name was getSize.impl, not getFileSize.impl; UCM suggested it). move --dry-run works without `--`, builtin fileStat feeds verified identity, full dry-run battery clean, status stable. Cosmetic: ETA shows "?" at zero elapsed (faster clock). 3.2b delivered: db.RenameCatalog (priorTargetForCrc, promoteToBuffer, upsertProbeCache, deleteProbeCache), executeOne/runStep/runNew rewritten through it, handler local to runNew, move path untouched. | 3.2b |
| 2026-06-07 | 3.2b runtime-verified: `unidork process` renamed 3 real files through the RenameCatalog handler, correct names/CRCs, landed in buffer. Flagged a real pre-existing issue surfaced in the same run: backend driver errors ("threadWait: Bad file descriptor" + "Postgres abandoned connection") at probe->resolve and resolve->rename boundaries, a fiber/connection lifecycle race in the 8-way parallel probe stage. Non-fatal here but can drop writes under other timing. Awaiting Harry's call: diagnose now (needs probe-stage source) vs proceed to 3.2c. | (3.2b runtime-verified; driver-error issue opened) |
| 2026-06-07 | Driver-error issue investigated via runChunk/forkChunk and DOWNGRADED to cosmetic. forkChunk joins all probe fibers (Promise.read) before runChunk writes; DB writes are serial on the main fiber, so no concurrent Postgres use and no data risk. Errors are vendored-lib connection/handle teardown noise at singleIO close. Recommendation: leave it. Harry confirmed it predates this work. Proceeding to 3.2c (need view Resolve.run / Resolve.resolveOne). | (issue downgraded to cosmetic) |
| 2026-06-07 | 3.2c landed: movie resolve on MetaApi(+searchMovies)+ResolveCatalog, pickBestWithRuntime/runtimeWinner moved to {MetaApi}, 4 in-memory handler tests green. D11 report path (reportFolderWith/reportLooseVideoWith/uniDork.identify) deleted as the expected casualty of the runtimeWinner signature change. Several scratch round-trips (lost searchMovies handler case, pqSearch scope drift, testDetails ordering/arity) resolved by empty-and-repaste per 8.2 scratch hygiene. | 3.2c |
| 2026-06-07 | 3.2d-i landed: tv resolve on TvMetaApi (4 ops) + TvCatalog (2 ops). Decided AGAINST one shared MetaApi: TV metadata APIs differ in shape (Optional Nat year, distinct response types), so movie MetaApi handler stays total and frozen. resolveShowPick split out of resolveOne to avoid the parenthesized-multiline-match parser trap. 4 handler tests (nfoId / dryRunNoWrite / noRef / missingEp). | 3.2d-i |
| 2026-06-07 | 3.2d-ii landed: tv rename reuses RenameCatalog for the 4 buffer ops (decision: identical SQL, worth sharing; cost is one dead priorTargetForCrc handler case TV never calls). The 2 cache-body reads stay statement-threaded, so executeEpisode keeps {Postgres}. Two small fixes during landing: re-added Postgres to the signature (the threaded reads need it), and qualified one Text.++ that `use List ++` had shadowed in `step`. cli went missing from the codebase mid-session and was recovered verbatim + recompiled. | 3.2d-ii |
| 2026-06-07 | 3.2d-iii: decided to LEAVE Tv.Move threaded. moveShow threads one statement; an ability op buys nothing. Phase 3 closed. | 3.2d-iii (by decision) |
| 2026-06-07 | Phase 4 reshaped. Probe unification attempted then DROPPED (D13): caught mid-design that the two paths diverge in traversal topology and root-relative multi-file hint reach, not just hint-tuple shape; a {collect,persist} spec would have smuggled runtime root/stage through placeholders and carried 80% of logic in spec fields. Resolve also DROPPED (D14, already kernel-shared, disjoint outcomes). Move identified as the real target (asymmetric safety, not similar bodies). 4.4 step 1 delivered + executed + verified: db.TvMoveCatalog (3 ops, all reusing existing SQL), per-episode identity verify, dual-keyed update, partial staging on fresh cross-device, chunking, progress. 3.2d-iii reopened/closed. Live run promoted 15 shows, all identity N/N. Several handler-bind shadowing errors during landing (use Text ++ vs List.++ in pt-chains, a copy-paste of the wrong bind args into the by-id case) caught and fixed. | 4.4 step-1; D13; D14 |