## Part 1: The current data flow, exactly as it stands

### The four pipeline stages

The program is one Unison namespace driven by `uniDork.cli`, dispatching on argv to four subcommands: `import`, `probe-stage`, `identify`, `rename`. The Nix orchestrator wraps these plus the bash probe scripts and Postgres lifecycle.

**`import`** (`batchedRun` → `batchedMain`) walks the *library* roots (your already-organized collection), reads each folder's `.nfo`, parses it into a `Movie` record via the `Nfo.*` parsers, optionally enriches runtime from an ffprobe sidecar, and upserts into `movies` plus its ten child tables (`movie_video_streams`, `movie_audio_tracks`, `movie_genres`, etc.), keyed on `folder_checksum`. This stage is about your *existing* library and is largely orthogonal to the staging bug you've been fighting. It's keyed on a checksum parsed out of the folder name (`Nfo.parseFolderName` reading the `~` suffix), which is itself fragile, but it's not where the pain is right now.

**`probe-stage`** (`Stage.runProbeStage`) is the new Unison replacement for `probe.nix`'s bash. Flow:

1. `collectWork staging` lists the staging dir, partitions into subfolders and loose top-level videos, and produces `[(Optional folderPath, videoPath)]`.
2. `partitionWork pqCached work` stats each file, checks `stage_probes` for a fresh-enough row via `isCachedWith` (compares `probed_at` against file mtime), drops cached ones, sorts the rest largest-first.
3. `probeBatch`/`runChunk` forks `Stage.probeJobs` (4) concurrent probes per chunk. Each `forkProbe` runs `probeWithCrc`: `rhash --crc32` then `ffprobe -show_format -show_streams`, decoded through `Stage.RawProbe.fromJson` into a `Stage.ProbeResult`.
4. Each successful result is upserted into `stage_probes` (now per-chunk, after our durability fix), keyed on `source_path`, storing `folder_path`, `video_basename`, `crc32`, and the full `probe_json`.

`stage_probes` is the one table that currently does the right thing: it's keyed by file location and holds file-intrinsic data (CRC, codec, resolution, duration, audio tracks). The problem isn't this table's contents — it's that `source_path` is the key, and `source_path` is mutable (a rename invalidates it), which is the stale-row bug you hit.

**`identify`** (`uniDork.identify`) is the read-only TMDB dry run. For each staging folder/loose video it calls `reportFolderWith`/`reportLooseVideoWith`, which:

1. Reads the probe row for runtime (`Stage.readWith` / `largestInFolderWith`).
2. Reads the NFO if present (`tryReadFolder`).
3. Builds a `Tmdb.ParsedRelease` via `buildParsedRelease` — which prefers NFO title/year, falling back to `parseReleaseName` scraping the filename.
4. Queries `tmdb_search_cache` (or hits the API and caches) via `cachedSearchWith`.
5. Scores candidates (`scoreCandidate`), picks a winner (`pickBestWithRuntime`, which can pull `tmdb_details_cache` for runtime tiebreaking).
6. Prints a verdict. Writes nothing but cache rows.

**`rename`** (`renameWith` → `runOneWith`/`runOneLooseWith` → `processFolderWith`/`processLooseVideoWith` → `executeMoveWith`) repeats almost all of `identify`'s work — re-reads the probe row, re-reads the NFO, re-parses the release name (twice: once in `checkAgreement`, once in `buildParsedRelease`), re-queries the caches, re-scores, re-picks — and *then* renders a target name and moves the file. The render pulls tokens from a `Rename.Context` built from the TMDB result + probe result + the original filename.

### The four tables and what they hold

- `movies` (+ 10 children): the *library* import target. Keyed on `folder_checksum`. Holds a denormalized blend of NFO-parsed and probe-derived data.
- `stage_probes`: keyed on `source_path` (mutable). Holds file-intrinsic probe data + CRC. Correct in spirit, wrong in key.
- `tmdb_search_cache`: keyed on `source_path` (mutable). Caches the raw search response per staged item.
- `tmdb_details_cache`: keyed on `tmdb_id`. Caches the full details payload. This is the *only* table keyed on something stable and content-appropriate.
- `rename_log`: append-only audit. We already stopped using it as truth.

## Part 2: Why this is wrong

There are five distinct structural faults. They're worth naming separately because they have different fixes.

**Fault 1 — the key is the mutable path.** `stage_probes` and `tmdb_search_cache` are keyed on `source_path`. The moment `rename` moves or renames a file, that key is stale. Every "cycling through the same videos," every "renames a file already renamed," every stale-row error traces to this. The CRC is computed, used transiently to build a name, and thrown away as a key — even though it is the *only* stable identifier you have. You said it exactly: once the checksum is computed it should be *the* key referring to that exact video file. Right now it's a column, not the key.

**Fault 2 — file identity and movie identity are conflated.** The current design treats "this file" and "this movie" as one thing. They are not. One movie (TMDB id 27205, *Inception*) can correspond to many files (different rips, resolutions, cuts, each with its own CRC). One file is exactly one movie (or zero, if unmatched). This is a one-movie-to-many-files relationship, and the schema models it as one-to-one by stapling TMDB data conceptually onto the per-file probe row at rename time. The consequence: a wrong TMDB match contaminates the only record of the file, and re-querying a movie re-does work that should be cached once per movie, not once per file. You identified this precisely — TMDB association can be *wrong*, so it must not be welded to the file record.

**Fault 3 — the filename is treated as a data source.** `extractGroup`, `extractTags`, `editionKeywords`, `isLikelyGroupToken` all mine the release name for naming data. Release names are adversarial garbage. The `{group}` bug (capturing `~CRC` as a group, doubling the checksum) is the symptom; the disease is that the filename feeds the *output* naming at all. The filename's only legitimate job is to seed a TMDB title/year guess *when there's no NFO*, and then be discarded. Everything in the output name should come from probe (file-intrinsic) or TMDB (movie-intrinsic).

**Fault 4 — work is repeated, parsed and queried multiple times per item.** `parseReleaseName` runs twice per folder during rename. The NFO is read during `import` and again during `identify` and again during `rename`. The probe JSON is decoded, re-encoded to DB, re-decoded. TMDB resolution (search + score + pick) happens in full during `identify` and *again, identically*, during `rename`. There is no single point where an item's identity is *resolved once and recorded*. You said it: parse/query only once in the chain per item. Right now resolution is recomputed at every stage that needs it.

**Fault 5 — the rename decision is entangled with the rename execution.** `executeMoveWith` does TMDB lookup, detail fetch, name rendering, conflict detection, the move, NFO writing, subtitle fetching, and DB cleanup, all in one function. There's no separable "what should this become" artifact. You want to compose renaming schemes on the fly — that's impossible when the naming decision is buried inside the side-effecting move. The verdict (what the new name should be) needs to be a *value* you can compute, inspect, store, and re-render under a different format, independent of moving anything.

## Part 3: The target architecture

Three tables, cleanly separated by what kind of thing they describe, joined only at rename time. This is your design; I'm formalizing it.

### Table A — `files` (file-intrinsic, keyed by CRC32)

The checksum is the primary key. One row per physical video file, describing *only* what's true of the bytes on disk.

```
crc32            TEXT PRIMARY KEY
original_path    TEXT NOT NULL          -- where we last saw it
original_name    TEXT NOT NULL          -- basename as found
size_bytes       BIGINT NOT NULL
duration_sec     DOUBLE PRECISION NOT NULL
probe_json       TEXT NOT NULL          -- full ffprobe-derived StreamDetails
video_codec      TEXT, width INTEGER, height INTEGER, bit_depth INTEGER, ...
proposed_name    TEXT                   -- last rendered target basename (nullable)
proposed_folder  TEXT                   -- last rendered target folder (nullable)
probed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

Key properties: keyed on `crc32`, so it survives any rename or move — the file *is* its checksum. `original_path`/`original_name` are just "last known location," updated freely, never load-bearing for identity. `proposed_name`/`proposed_folder` are the *rendered* target under the current format; they're a cache of the naming decision, recomputable, nullable, and explicitly *not* identity. Audio/subtitle/video stream detail lives in `probe_json` (or normalized children if you prefer, but JSON is fine and you already have the codec). This table never holds TMDB data. A wrong match cannot corrupt it.

### Table B — `movies` (movie-intrinsic, keyed by TMDB id)

One row per *movie*, growing as you query TMDB. This is the reusable knowledge base.

```
tmdb_id          INTEGER PRIMARY KEY
imdb_id          TEXT, tvdb_id TEXT
title            TEXT NOT NULL
original_title   TEXT, original_language TEXT
year             INTEGER
runtime_min      INTEGER                -- TMDB's claimed runtime
overview TEXT, tagline TEXT, mpaa TEXT, vote_average DOUBLE PRECISION, vote_count INTEGER
details_json     TEXT NOT NULL          -- full Tmdb.Details (genres, cast, crew, etc.)
collection       TEXT
fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

This *is* your existing `tmdb_details_cache` promoted to a first-class entity. Keyed on `tmdb_id` (stable, correct). Holds everything taxonomic. Reused across every file that matches this movie. Querying movie 27205 once serves all rips of *Inception* forever.

### Table C — `associations` (the join, file ↔ movie)

This is the table whose key insight you articulated: a movie has an *array* of checksums associated with it.

```
crc32            TEXT NOT NULL REFERENCES files(crc32) ON DELETE CASCADE
tmdb_id          INTEGER NOT NULL REFERENCES movies(tmdb_id) ON DELETE CASCADE
confidence       INTEGER NOT NULL       -- the match score, retained
match_source     TEXT NOT NULL          -- 'nfo_id' | 'title_year' | 'manual' | ...
associated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
PRIMARY KEY (crc32, tmdb_id)
```

One file maps to one movie *primarily*, but the table permits the many-to-one (many files → one movie) and records *how* and *how confidently* the match was made. Because the association is separate, a bad match is a row you delete and replace — it never touched `files` or `movies`. You can override a match manually (`match_source = 'manual'`) without re-querying TMDB. You can compare a file's probed `duration_sec` (from `files`) against the movie's claimed `runtime_min` (from `movies`) *across the join* — exactly the cross-check you mentioned, now trivial because the two durations live in their proper tables and meet only here.

### The new pipeline

The stages become sharply separated by responsibility:

**`probe`** — populates `files` only. For each staged video: compute CRC, ffprobe, upsert into `files` keyed on CRC. `original_path`/`original_name` recorded. No TMDB, no naming. Idempotent on CRC: re-probing the same bytes is a no-op upsert. *This alone fixes the stale-key bug* — the key is now content, not location.

**`resolve`** (replaces `identify` as the operational pass; `identify` becomes its dry-run printout) — for each file in `files` lacking an association: build the title/year hint (NFO first, filename fallback — the *only* filename use), query TMDB search (cache by a stable key — title+year, not path), score, pick. On a confident pick: ensure the `movies` row exists (fetch details once if absent), then write the `associations` row. Release-name parsing happens *exactly once here*. The verdict is persisted, not recomputed downstream.

**`rename`** — pure consumer. For each file with an association: join `files` + `movies` + `associations`, render the target name from the *current format string*, check the filesystem (`targetHasCrc`, `pathExists`), move. Because naming inputs are all in the DB and the format is a parameter, you can re-render under any scheme on the fly — `rename --format '{n} ({y})/{n}'` reads the same three tables and produces a different layout, no re-probing, no re-querying. The "compose a renaming scheme on the fly" requirement falls out for free.

**The naming function becomes pure and composable.** `renderName : Format -> FileRecord -> MovieRecord -> Text`. It takes the three-table data and a parsed format, returns a string. No IO, no DB, no filename mining. `executeMoveWith` shrinks to: render (pure) → filesystem checks → move. The decision (`proposed_name`) is a value you can store in `files`, inspect, diff against the current on-disk name, and regenerate.

### What gets deleted

`extractGroup`, `extractTags`, `isLikelyGroupToken`, `editionKeywords`, the `{group}`/`{tags}` tokens, and their tests — the entire filename-as-data-source apparatus. `Rename.Context` loses everything but the file and movie records. The `rename_log`-as-truth machinery (already removed). The double-parse in `checkAgreement` collapses into the single `resolve` parse.

### Migration note

Your `movies`+children library schema (from `import`) and this new staging schema (`files`/`movies`/`associations`) currently collide on the name `movies`. You'll want to rename one. I'd suggest the library import table becomes `library_movies` and the new TMDB knowledge base takes `movies`, since the latter is the genuinely movie-keyed entity. We'll need to decide whether `import` (library) and the staging pipeline should *share* the new `movies` knowledge base — they probably should, since a library movie and a staged movie can be the same TMDB id.

---

That's the full map. The next step is schema DDL for `files`, `movies`, `associations`, then the `probe` rewrite (CRC-keyed upsert), then `resolve` (the single resolution pass writing associations), then `rename` as a pure consumer with a composable `renderName`. I'd deliver these as complete pasteable files in that dependency order.

Before I write DDL, one decision that shapes everything downstream: **the staging pipeline and the library `import` should share one `movies` knowledge base?** Sharing is cleaner (one movie is one movie) but couples the two flows; separating is simpler now but duplicates TMDB data if a staged film later lands in your library. Which way do you want it?



This is a code refactoring task, not a research task, so I'm going to ignore the research tooling and work directly on the code.

Before I touch anything, the design doc (Part 3) ends on an open decision that determines the entire schema, and you never answered it: should the staging pipeline and the library `import` flow share one `movies` knowledge base, or stay separate? That isn't a detail I should silently pick. Sharing means one TMDB id is one row regardless of whether it arrived via library or staging; separating keeps two parallel worlds and duplicates TMDB data. Everything downstream (table names, foreign keys, migration) forks on this.

The second thing I need to be blunt about: the instruction "make no mistakes" against a single-namespace Unison codebase I cannot compile is not a promise I can honestly make. I can't run `ucm` here, I can't typecheck against `@runarorama/postgres` or `@unison/http`, and several identifiers in your own code carry "swap this if it doesn't resolve" comments (`Handle.isEOF`, `FilePath.exists`), which tells me even you aren't certain of the exact base API surface. Anyone who tells you they'll emit flawless, paste-and-run Unison for a rewrite this size without a compiler is lying to you. What I can do is write code that is internally consistent with the idioms already in your files and flag every spot where I'm relying on an identifier I can't verify.

A few specific things I want to confirm before writing DDL and the `probe`/`resolve`/`rename` rewrite, because guessing wrong here wastes a whole pass:

1. **Shared vs separate `movies`** — the open question above. My recommendation is share, with the library table renamed `library_movies` and the TMDB knowledge base taking `movies`, exactly as the doc proposes. Confirm or override.

answer: 

2. **CRC collision policy.** CRC32 is 32 bits. Across a library of thousands of rips you will eventually get two genuinely different files with the same CRC32. Your whole identity model keys on it. Do you want `files` to key on `crc32` alone (collision = silent data corruption), or on `(crc32, size_bytes)` as a composite (collision-resistant, still survives rename)? This changes the PK and every FK in `associations`.

anser: on `(crc32, size_bytes)` as a composite (collision-resistant, still survives rename)

3. **Scope of this pass.** Do you want me to deliver the full set — DDL, `probe`, `resolve`, `rename` with the pure `renderName`, plus the deletions — in one go, or stage it as the doc suggests (DDL first, then each stage, so you can `ucm` each layer before the next)? Given that I can't compile, I'd argue staging is the only sane path, but it's your call.

Answer those three and I'll start emitting whole files in dependency order, marking each as new or replacing a named existing definition.


Here is the output of my program right now:

 ~/g/uniDork   nfo_expand     
   ucm                                                                                                                                                                            uniDork-devshell-env

  Now starting the Unison Codebase Manager (UCM)...


   _____     _
  |  |  |___|_|___ ___ ___
  |  |  |   | |_ -| . |   |
  |_____|_|_|_|___|___|_|_|

  👋 Welcome to Unison!

  You are running version: release/1.1.0


  📚 Read the official docs at https://www.unison-lang.org/docs/

  Hint: Type 'projects' to list all your projects, or 'project.create' to start something new.

uniDork/main> run Stage.runProbeStage
[stage-probe] 10 video(s) found
[stage-probe] to probe: 10, cached: 0
  start: Lucky Bastard 2014 1080p WEB E-AC3 H265.mp4
  start: Inhabitants 2025 1080p WEB-DL AAC2.0 H265.mp4
  start: The Great Outdoors 1988 REMASTERED 1080p BluRay HEVC x265 BONE.mkv
  start: The.Sheriff.2026.1080p._.10bit.DDP5.1.x265-FaS.mkv
  start: Ratatouille (2007) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
  start: Body Heat 1981 Criterion 1080p BluRay HEVC x265 5.1 BONE.mkv
  start: Inheritance 2025 1080p WEB-DL HEVC H265 E-AC3 5.1.mkv
  start: Kubo and the Two Strings (2016) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
   done: Lucky Bastard 2014 1080p WEB E-AC3 H265.mp4
   done: Inhabitants 2025 1080p WEB-DL AAC2.0 H265.mp4
   done: The Great Outdoors 1988 REMASTERED 1080p BluRay HEVC x265 BONE.mkv
   done: The.Sheriff.2026.1080p._.10bit.DDP5.1.x265-FaS.mkv
   done: Ratatouille (2007) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
   done: Body Heat 1981 Criterion 1080p BluRay HEVC x265 5.1 BONE.mkv
   done: Inheritance 2025 1080p WEB-DL HEVC H265 E-AC3 5.1.mkv
   done: Kubo and the Two Strings (2016) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
  start: Tarzan (1999) (1080p BluRay x265 10-bit AAC 5.0) [WeSLeY].mkv
  start: City Wide Fever (2026) (1080p BluRay x265 10bit r00t).mkv
   done: Tarzan (1999) (1080p BluRay x265 10-bit AAC 5.0) [WeSLeY].mkv
   done: City Wide Fever (2026) (1080p BluRay x265 10bit r00t).mkv
[stage-probe] done

  ()

uniDork/main> run renameGo
[rename] 3 associated file(s)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Fuze.2025.1080p.WEBRip.10Bit.DDP.5.1.x265-NeoNoir.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Fuze (2026) [1.7 GB.1080p.x265.10b.96min] ~15E748D3
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Fuze (2026) [1.7 GB.1080p.x265.10b.96min] ~15E748D3/Fuze (2026) [x265_10b_1918x802_2.6 Mbps_EAC3-5.1] ~15E748D3.mkv)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Animal.Farm.2025.1080p.WEBRip.10Bit.DDP.5.1.x265-NeoNoir.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Animal Farm (2026) [1.3 GB.1080p.x265.10b.94min] ~BA9B1D84
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Animal Farm (2026) [1.3 GB.1080p.x265.10b.94min] ~BA9B1D84/Animal Farm (2026) [x265_10b_1920x800_2.0 Mbps_EAC3-5.1] ~BA9B1D84.mkv)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9/Avatar Fire and Ash (2025) [x265_10b_1920x1040_8.2 Mbps_EAC3-7.1_~9EB399A9] ~9EB399A9.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9/Avatar Fire and Ash (2025) [x265_10b_1920x1040_8.2 Mbps_EAC3-7.1] ~9EB399A9.mkv)
[rename] done

  ()

uniDork/main> run Stage.runProbeStage
[stage-probe] 10 video(s) found
[stage-probe] to probe: 0, cached: 10
[stage-probe] done

  ()

uniDork/main> run Resolve.run
[resolve] 10 unresolved file(s)
  file 11 -> tmdb:313297 (50%)
  file 12 -> tmdb:37135 (50%)
  file 10 -> tmdb:1297860 (50%)
  file 13 -> tmdb:1408324 (50%)
  file 5 -> no confident match
  file 8 -> tmdb:2062 (50%)
  file 6 -> tmdb:2617 (50%)
  file 4 -> tmdb:180850 (50%)
  file 9 -> no title/year hint
  file 7 -> tmdb:1287809 (50%)
[resolve] done

  ()

uniDork/main> run renameGo
[rename] 11 associated file(s)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Fuze.2025.1080p.WEBRip.10Bit.DDP.5.1.x265-NeoNoir.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Fuze (2026) [1.7 GB.1080p.x265.10b.96min] ~15E748D3
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Fuze (2026) [1.7 GB.1080p.x265.10b.96min] ~15E748D3/Fuze (2026) [x265_10b_1918x802_2.6 Mbps_EAC3-5.1] ~15E748D3.mkv)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Animal.Farm.2025.1080p.WEBRip.10Bit.DDP.5.1.x265-NeoNoir.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Animal Farm (2026) [1.3 GB.1080p.x265.10b.94min] ~BA9B1D84
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Animal Farm (2026) [1.3 GB.1080p.x265.10b.94min] ~BA9B1D84/Animal Farm (2026) [x265_10b_1920x800_2.0 Mbps_EAC3-5.1] ~BA9B1D84.mkv)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9/Avatar Fire and Ash (2025) [x265_10b_1920x1040_8.2 Mbps_EAC3-7.1_~9EB399A9] ~9EB399A9.mkv
  note: previously renamed this file -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9
  DUPLICATE -> source removed (already at /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Avatar Fire and Ash (2025) [11 GB.1080p.x265.10b.197min] ~9EB399A9/Avatar Fire and Ash (2025) [x265_10b_1920x1040_8.2 Mbps_EAC3-7.1] ~9EB399A9.mkv)
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Kubo and the Two Strings (2016) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
    SUB en -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Kubo and the Two Strings (2016) [2.5 GB.1080p.x265.10b.101min] ~974EC841/Kubo and the Two Strings (2016) [x265_10b_1920x802_3.5 Mbps_AAC-7.1] ~974EC841.en.srt
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Kubo and the Two Strings (2016) [2.5 GB.1080p.x265.10b.101min] ~974EC841/Kubo and the Two Strings (2016) [x265_10b_1920x802_3.5 Mbps_AAC-7.1] ~974EC841.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Tarzan (1999) (1080p BluRay x265 10-bit AAC 5.0) [WeSLeY].mkv
    SUB en -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Tarzan (1999) [2.8 GB.1080p.x265.10b.88min] ~9C4F43C5/Tarzan (1999) [x265_10b_1918x1080_4.5 Mbps_AAC-5] ~9C4F43C5.en.srt
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Tarzan (1999) [2.8 GB.1080p.x265.10b.88min] ~9C4F43C5/Tarzan (1999) [x265_10b_1918x1080_4.5 Mbps_AAC-5] ~9C4F43C5.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Inheritance 2025 1080p WEB-DL HEVC H265 E-AC3 5.1.mkv
    SUB en -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Inheritance (2025) [2.1 GB.1080p.x265.8b.98min] ~954A028D/Inheritance (2025) [x265_8b_1920x1080_3.0 Mbps_EAC3-5.1] ~954A028D.en.srt
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Inheritance (2025) [2.1 GB.1080p.x265.8b.98min] ~954A028D/Inheritance (2025) [x265_8b_1920x1080_3.0 Mbps_EAC3-5.1] ~954A028D.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/City Wide Fever (2026) (1080p BluRay x265 10bit AC3 5.1 r00t)/City Wide Fever (2026) (1080p BluRay x265 10bit r00t).mkv
    SUB en not found
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/City Wide Fever (2026) [3.6 GB.1080p.x265.10b.73min] ~8FC6B0E1/City Wide Fever (2026) [x265_10b_1488x1080_7.0 Mbps_AC3-5.1] ~8FC6B0E1.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Ratatouille (2007) (1080p DS4K BluRay x265 10-bit HDR AAC 7.1) [WeSLeY].mkv
    SUB en error: unexpected response status: 500: Internal Server Error
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Ratatouille (2007) [1.9 GB.1080p.x265.10b.111min] ~C4B14BE3/Ratatouille (2007) [x265_10b_1920x802_2.4 Mbps_AAC-7.1] ~C4B14BE3.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/The Great Outdoors 1988 REMASTERED 1080p BluRay HEVC x265 BONE.mkv
    SUB en -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/The Great Outdoors (1988) [1.6 GB.1080p.x265.8b.90min] ~A77DB2CA/The Great Outdoors (1988) [x265_8b_1920x1038_2.5 Mbps_AAC-2.0] ~A77DB2CA.en.srt
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/The Great Outdoors (1988) [1.6 GB.1080p.x265.8b.90min] ~A77DB2CA/The Great Outdoors (1988) [x265_8b_1920x1038_2.5 Mbps_AAC-2.0] ~A77DB2CA.mkv
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/Lucky Bastard 2014 1080p WEB E-AC3 H265.mp4
    SUB en not found
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/Lucky Bastard (2014) [1.3 GB.1080p.x265.8b.94min] ~F7AFB5E6/Lucky Bastard (2014) [x265_8b_1920x1080_1.8 Mbps_EAC3-2.0] ~F7AFB5E6.mp4
processing: /home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies/The.Sheriff.2026.1080p._.10bit.DDP5.1.x265-FaS/The.Sheriff.2026.1080p._.10bit.DDP5.1.x265-FaS.mkv
    SUB en -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/The Sheriff (2026) [1.6 GB.1080p.x265.10b.107min] ~CD81F170/The Sheriff (2026) [x265_10b_1920x800_2.1 Mbps_EAC3-5.1] ~CD81F170.en.srt
    SUB es not found
    SUB th not found
  RENAMED -> /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies/The Sheriff (2026) [1.6 GB.1080p.x265.10b.107min] ~CD81F170/The Sheriff (2026) [x265_10b_1920x800_2.1 Mbps_EAC3-5.1] ~CD81F170.mkv
[rename] done

  ()

I have to run Resolve to actually associate the files with a tmdb id.  No problem but perhaps we can just build that into the end of the checksum part.