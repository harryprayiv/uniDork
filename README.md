# uniDork

PostgreSQL-backed movie library organization in Unison.

[![License: AGPL v3](https://www.gnu.org/graphics/agplv3-155x51.png)](https://www.gnu.org/licenses/agpl-3.0.html)

A filebot replacement for Kodi users, typed end to end, reproducibly built with Nix.

## Why Unison

This project is an experiment in content addressing all the way down. Unison code is itself content-addressable: every function is identified by the hash of its abstract syntax tree, not by a name in a file. uniDork extends that idea into the data layer. Every movie folder is keyed by a CRC32 of its video file, and the CRC32 is embedded directly in the folder and file names. The same movie ripped twice produces two different rows. A renamed folder still resolves to the same row. The on-disk layout, the database, and the language all agree about what identity means: bytes, not labels.

A Haskell port would be trivial. I continue to choose not to.

## What works

- **Library import.** Walks a list of roots configured in `nix/config.nix`, parses Kodi NFO sidecars with `unison_xml`, upserts rows keyed by `folder_checksum` into PostgreSQL. Multiple copies of the same film coexist as separate rows.
- **ffprobe enrichment.** A Nix-built script (`ffprobe-cache`) walks the library and writes per-file ffprobe JSON sidecars; the Unison importer reads them to populate `actual_runtime_sec`.
- **Stage probing.** A second Nix-built script (`unidork-stage-probe`) probes the staging directory directly into a `stage_probes` Postgres table, with CRC32, ffprobe JSON, and folder grouping.
- **TMDB identification.** Folders without NFOs are matched against TMDB via `unison_http`. Scoring combines normalized title match, year proximity, and a runtime tiebreaker that fetches `/movie/<id>` details when popularity alone cannot pick a winner. Search and details responses are cached in `tmdb_search_cache` and `tmdb_details_cache`.
- **Rename pipeline.** A filebot-style format DSL parses templates like `{ny} [{vf}.{vc}.{bitdepth}b.{minutes}min] ~{crc32}` into `[FormatPart]` and applies them against a `(TmdbResult, ProbeResult, originalName)` context. Outcomes (`Renamed`, `NoMatch`, `NoProbe`, `Conflict`, `RenameError`) are written to `rename_log`. Folder and file templates are configured per-deployment in `nix/config.nix`.
- **Audio language reselection.** `Relang.*` reads ffprobe audio tracks, looks up the TMDB original language, filters out commentary and audio-description tracks, ranks by channel count and codec, and decides whether to flip the default track. The decision is computed but not yet applied to the file.
- **Orchestrator.** `unidork run` chains start, probe-lib, probe-stage, import, identify. `unidork rename --apply` is the destructive step. `unidork status` reads the rowcounts.

## What's next

- **Enhanced NFO emission.** The rename step currently writes a minimal NFO containing title, year, plot, and tmdb id. The next pass writes the full Kodi schema (cast, ratings, fileinfo/streamdetails, set/collection, unique ids for imdb and tvdb) so reimporting a renamed folder reproduces the original row faithfully.
- **Duplicate management.** Multiple rows per `imdb_id` or `tmdb_id` are the trigger. The schema already supports this (`folder_checksum` is the PK, identity columns are non-unique). The missing piece is a workflow that ranks copies by resolution, bitrate, audio quality, and runtime completeness, then surfaces decisions to a reviewer or applies a deterministic policy.
- **Automated subtitle downloads.** OpenSubtitles or equivalent, keyed by `imdb_id` plus a hash so retries are cached. Subtitles get muxed into the MKV during rename, not left as sidecars.

None of this will involve Haskell, no matter how convenient that would be.

## Stack

Unison (`@unison/base`, `@unison/json`, `@unison/xml`, `@unison/http`, `@runarorama/postgres`), PostgreSQL, Nix flakes, ffmpeg, rhash for CRC32, jq for shaping ffprobe output. No Python. No Docker. No Haskell.

## Usage

```bash
nix develop
unidork run                    # full pipeline: start + probe + import + identify
unidork rename --apply         # destructive: moves files
unidork status                 # rowcounts
unidork help                   # everything else
```

Library roots are configured in `nix/config.nix` under `library.roots`. The TMDB v4 bearer token lives at `~/.config/uniDork/tmdb-token` (mode 600). Caches live under `~/.cache/uniDork/`. PostgreSQL data lives under `~/.local/share/uniDork/postgres/`.

## Build

```bash
nix build
```

`./result/bin/unidork-import` runs the compiled pipeline without ucm.

## License

[AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html).