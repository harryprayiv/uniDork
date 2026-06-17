# uniDork

PostgreSQL-backed movie library organization in Unison.

[![License: AGPL v3](https://www.gnu.org/graphics/agplv3-155x51.png)](https://www.gnu.org/licenses/agpl-3.0.html)

A FileBot replacement for Kodi users, typed end to end, reproducibly built with Nix.

## Why Unison

This project is an experiment in content addressing all the way down. Unison code is itself content-addressable: every function is identified by the hash of its abstract syntax tree, not by a name in a file. uniDork extends that idea into the data layer. File identity is a CRC32 of the video bytes; the CRC32 is embedded in folder and file names. The same movie ripped twice produces two different rows. A renamed or relocated folder still resolves to the same row. The on-disk layout, the database, and the language all agree about what identity means: bytes, not labels.

A Haskell port would be trivial. I continue to choose not to.

## The pipeline: three directories, one direction

Movies flow through three real directories, tracked by a `stage` column on every file row:

    intake  --probe-stage-->  files(stage=staging)  --resolve-->  associations
       |                                                              |
       +---------------------- rename --apply ------------------------+
                                     |
                                     v
    buffer  --import-buffer-->  files(stage=buffer)   [awaiting your approval]
       |
       +------------------------------ move --------------------------+
                                                                      |
                                                                      v
    library --import-library-->  files(stage=library) + library_movies

- **intake** — where fresh downloads land. Read-only to uniDork. `probe-stage` reads it.
- **buffer** — the holding pen between rename and promotion. `rename --apply` writes renamed folders here. `move` reads here and *deletes from here* on a successful promotion. This is where you manually review before promoting.
- **library** — your actual library. `move` writes promoted movies here (via rsync). `import-library` reads here to catalogue.

All three are configured in `nix/config.nix` under `paths`. There is no separate "destination" field: `move` writes to `library`, `import-library` reads from `library`, one path.

### The `stage` column

Every row in `files` carries a `stage`:

- `staging` — file is in intake, probed, resolvable.
- `buffer` — file has been renamed into the buffer. **Excluded from `resolve`.** Buffer files are not auto-matched against TMDB; their identity comes from the NFO that `rename` wrote.
- `library` — file has been promoted (or catalogued directly) into the library.

`resolve` operates on everything *except* `stage='buffer'`.

## Commands

    nix develop                    # enter devshell
    unidork help                   # full command list

    # read-only / safe
    unidork status                 # rowcounts, files split by stage
    unidork identify               # read-only TMDB match report
    unidork probe-stage            # probe intake -> files (stage=staging)
    unidork resolve                # associate non-buffer files -> TMDB movies
    unidork import-library         # catalogue the library into the DB (stage=library)
    unidork import-buffer          # record buffer files into the DB (stage=buffer)
    unidork import-all             # import-buffer then import-library

    # destructive
    unidork rename --apply         # move intake files INTO the buffer (renamed)
    unidork move "<folder>"        # promote ONE buffer folder into the library
    unidork move                   # promote ALL buffer folders into the library

    # lifecycle
    unidork start | stop           # postgres
    unidork psql                   # interactive psql
    unidork clean-stage            # truncate probe_cache (forces re-probe)
    unidork run                    # start + probe-stage + import-library + resolve

### `move` — what it does, per buffer folder

1. Parse the folder's NFO. No parseable NFO -> abort, leave in buffer.
2. Read the TMDB id from the NFO. No id -> abort, leave in buffer (cannot promote an unidentified file).
3. Find the video; look up its `files` row by current buffer path. Verify on-disk size matches the stored size; if it matches, the stored CRC32 is trusted (no rehash). On miss or mismatch, re-probe at the buffer location.
4. Ensure the TMDB details row exists in `movies` (fetch + cache if absent), so the association foreign key holds. This is a network call and happens **before** the move, outside any DB transaction.
5. Enforce that the destination is under the configured `library` root.
6. **rsync the folder** `buffer/<folder>/ -> library/<folder>/` with `-a --remove-source-files` (no `--delete`). This is the point of no return.
7. On rsync success: remove the emptied source folder, update the `files` row (new path, `stage='library'`), write the association (`match_source='nfo_promote'`), and write the `library_movies` promotion row from the NFO-parsed movie.

**`move` trusts the NFO's TMDB id and does not re-match.** Identity correctness depends on `rename` having matched correctly. Review buffer folders before promoting.

**Safety:** `move` only ever writes to `paths.library` and only ever deletes from `paths.buffer`. rsync runs without `--delete`, so it can only *add* a folder to the library; it cannot remove or overwrite existing library folders. The blast radius of one `move` is exactly: one folder added to the library, one folder removed from the buffer.

## Configuration

`nix/config.nix`, under `paths`:

    paths = {
      intake  = "/.../renameQue/Movies";   # fresh downloads (read-only)
      buffer  = "/.../AMC/TEST";            # rename writes; move reads + deletes
      library = "/.../AMC/Movies";          # move writes; import-library reads
    };

**Going to production:** change `paths.library` to your real library path. Before the first production `move`, verify the destination with `echo "$UNIDORK_PATH_LIBRARY"` inside the devshell. That env var, and the `paths.library` config field, are the *only* thing controlling where `move` writes.

Format strings live under `rename.movieFormat`. The TMDB v4 bearer token lives at `~/.config/uniDork/tmdb-token` (mode 600). Caches live under `~/.cache/uniDork/`. PostgreSQL data lives under `~/.local/share/uniDork/postgres/`.

## What works

- **Stage probing.** `probe-stage` walks intake, CRC32 + ffprobe, writes `files` rows keyed on `(crc32, size_bytes)` with `stage='staging'`.
- **TMDB identification.** `resolve` matches non-buffer files via `unison_http`: normalized title, year proximity, runtime tiebreaker. Search and details cached.
- **Rename pipeline.** FileBot-style format DSL. `rename --apply` writes renamed folders (with NFO) from intake into the buffer.
- **Buffer recording.** `import-buffer` records buffer files into `files` as `stage='buffer'`, kept out of the resolve sweep.
- **Promotion.** `move` promotes reviewed buffer folders into the library: rsync relocation, file-row update, association, and `library_movies` write, trusting the NFO identity.
- **Library import.** `import-library` catalogues the library into `library_movies`, keyed on `folder_checksum`, self-probing and CRC-verifying.
- **Audio language reselection.** `Relang.*` decides default-track flips (computed, not yet applied).

## What's next

- **Enhanced NFO emission.** Rename currently writes a minimal NFO. Full Kodi schema is the next pass.
- **Duplicate management.** Multiple rows per `imdb_id`/`tmdb_id`; rank by quality and surface decisions.
- **Automated subtitle muxing.** Keyed by `imdb_id` + hash, muxed into the MKV during rename.
- **A verification gate at promotion** (optional). `move` currently trusts the NFO id; a re-match check could be added.

None of this will involve Haskell, no matter how convenient that would be.

## Stack

Unison (`@unison/base`, `@unison/json`, `@unison/xml`, `@unison/http`, `@runarorama/postgres`), PostgreSQL, Nix flakes, ffmpeg, rhash (CRC32), rsync (promotion), jq. No Python. No Docker. And though I adore it, no Haskell here.

## Build

    nix build

`./result/bin/unidork-import` runs the compiled pipeline without ucm.

### Working on the code

The compiled binary (`bin/unidork-import.uc`) is *not* the live UCM namespace. After editing definitions, test via `run <thunk>` against the namespace, then `compile cli ./bin/unidork-import` and `direnv reload` to update the binary. Editing the namespace and testing via `unidork` silently tests stale code.

### UNison Cloud

[Unison Cloud Repo](https://share.unison-lang.org/@harryprayiv/uniDork/code/main)

## License 

[AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html).
