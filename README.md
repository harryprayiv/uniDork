# uniDork

PostgreSQL-backed movie library organization, written in Unison.

[![License: AGPL v3](https://www.gnu.org/graphics/agplv3-155x51.png)](https://www.gnu.org/licenses/agpl-3.0.html)

## What this is

A filebot replacement for Kodi users. The goal is to retire the filebot AMC script with something open source, typed end-to-end, and reproducibly built via Nix.

This is a work in progress. The library import path works. The TMDB identification path runs end-to-end but is still being tuned. The rename and NFO-writing paths don't exist yet.

## What works

- Walks a list of library roots, parses Kodi-format NFO sidecars, upserts into PostgreSQL
- Folder-name parsing for technical metadata (`Movie Title [1080p x265 8bit 105min]~CHECKSUM`)
- `folder_checksum` as the unique row key, so multiple copies of the same movie coexist as separate rows
- ffprobe enrichment via a Nix-provisioned shell script that caches JSON sidecars; Unison reads the cache
- TMDB identification for folders without NFOs, querying directly from Unison via `unison_http_16_0_0`
- Strict scoring: HIGH confidence requires exact normalized title match plus exact year match

## What doesn't work yet

- Writing NFO files from a HIGH-confidence TMDB match
- Renaming files into a canonical layout
- Incremental import (every run currently re-upserts every folder)
- Long ucm sessions occasionally crash on large imports; running the compiled binary outside ucm is more stable

## Stack

Unison (`@unison/base`, `@unison/json`, `@unison/xml`, `@unison/http`, `@runarorama/postgres`), PostgreSQL, Nix flakes, ffmpeg. No Python, no Docker.

## Usage

```fish
nix develop
pg-start
ffprobe-cache
ucm
uniDork/main> run uniDork.batchedRun     # import existing library
uniDork/main> run uniDork.identify       # TMDB identification report
```

Configuration:
- `/tmp/uniDork.conf` — one absolute path per line, each a library root
- `~/.config/uniDork/tmdb-token` — TMDB v4 bearer token (mode 600)

Caches live under `~/.cache/uniDork/`. PostgreSQL data lives under `~/.local/share/uniDork/postgres/`.

## Build

```fish
nix build
```

First build fails with a hash mismatch — copy the `got:` hash into `nix/build.nix` and rerun. After that, `./result/bin/unidork-import` runs the compiled pipeline without ucm.

## License

[AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html).