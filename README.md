# uniDork

PostgreSQL-backed movie **and TV** library organization in Unison.

[![License: AGPL v3](https://www.gnu.org/graphics/agplv3-155x51.png)](https://www.gnu.org/licenses/agpl-3.0.html)

A FileBot replacement for Kodi users, typed end to end, reproducibly built with
Nix. Two parallel pipelines, one for movies and one for episodic TV, sharing the
same identity model, the same `files` table, and the same three-directory
discipline.

## Why Unison

This project is an experiment in content addressing all the way down. Unison
code is itself content-addressable: every function is identified by the hash of
its abstract syntax tree, not by a name in a file. uniDork extends that idea
into the data layer. File identity is a CRC32 of the video bytes; the CRC32 is
embedded in folder and file names. The same title ripped twice produces two
different rows. A renamed or relocated folder still resolves to the same row.
The on-disk layout, the database, and the language all agree about what identity
means: bytes, not labels.

A Haskell port would be trivial. I continue to choose not to.

## Quick start on a fresh machine

```sh
git clone <repo> ~/git/uniDork
cd ~/git/uniDork
direnv allow                 # or: nix develop

unidork secrets              # confirm all three API keys resolve
unidork backup --init        # once, with the backup volume mounted
unidork bootstrap            # cluster + schema, or restore the newest backup
unidork all --dry-run        # walk every stage, touch no file
unidork all --apply          # for real
```

`bootstrap` is the only command you need to remember for a new box. It ensures
the Postgres cluster, then either restores the newest verified dump from
`database.backup.dir` and swaps it in, or creates an empty schema if there is no
dump. It finishes by running the secrets check.

If you skip `bootstrap`, pipelines refuse to start against a schemaless database
and tell you so, rather than dying inside Unison with a `relation does not
exist` stack trace.

## Two commands do everything

```sh
unidork movies --apply       # the whole movie pipeline, in order
unidork tv     --apply       # the whole TV pipeline, in order
unidork all    --apply       # movies then TV
```

Each stage runs as a separate `unidork-import` process, so every stage gets a
fresh heap. Stage order lives in the orchestrator's stage table and nowhere
else.

### Pipeline flags

| flag | effect |
| --- | --- |
| *(none)* | print the ordered plan, exit non-zero. The safe default. |
| `--list` | print the ordered plan, exit 0 |
| `--dry-run` | run every stage; destructive stages touch no file |
| `--apply` | run for real, after a throttled auto-backup |
| `--from=ID` | start at stage `ID`. This is how you resume after a crash. |
| `--to=ID` | stop after stage `ID` |
| `--only=ID,ID` | run exactly these stages, in table order |
| `--skip=ID,ID` | run everything except these |

In the plan output, `!` marks a stage that writes to the filesystem and `*`
marks a domain-agnostic stage that is deferred and run once after every domain
has finished.

## Stages

Movies, in order:

| id | writes files | what it does | import verb |
| --- | --- | --- | --- |
| `probe` | | intake to `files(stage=staging)` | `movie-probe` |
| `resolve` | | staging files to TMDB associations | `movie-resolve` |
| `rename` | yes | staging to buffer, via `UNIDORK_FORMAT_MOVIE` | `movie-rename` |
| `sweep` | yes | drop emptied staging dirs and stale rows | `sweep-stage` |
| `subs` | yes | fetch missing subtitle sidecars in the buffer | `movie-subs` |
| `move` | yes | buffer to library | `movie-move` |
| `index` | | library dirs to `files` + `library_movies` | `movie-index` |
| `versions` | | detect multi-copy editions, database only | `movie-versions` |
| `nfo` | yes | stamp version tags into `movie.nfo` | `movie-nfo` |
| `artwork` | yes | fetch artwork into library folders | `movie-artwork` |
| `artscan` | | inventory artwork on disk to `artwork_log` | `artwork-scan` |

TV, in order: `probe` `resolve` `rename` `sweep` `move` `artwork` `artscan`.

`artscan` is domain-agnostic. It appears in both tables so stage selection still
works, but it is queued during the run and executed exactly once after every
domain finishes. Running it per domain would waste a full library scan and, in
`all`, would inventory movie artwork before TV artwork had been fetched.

`sweep` also appears in both tables and is **not** deduplicated: movie staging
is swept after movie rename, TV staging after TV rename. Both are needed.

### Escape hatch

```sh
unidork stage <verb> [args]      # run one unidork-import verb directly
unidork stage help               # every verb the binary understands

unidork stage movie-move "Blade Runner (1982)" --dry-run
unidork stage movie-identify     # read-only match report, no writes
unidork stage tv-reconcile       # re-probe the TV buffer
unidork stage sweep-missing      # delete rows with stage='missing'
```

## The pipeline: three directories, one direction

Media flows through three real directories per kind, tracked by two columns on
every file row: `stage` (`staging` to `buffer` to `library`) and `media_kind`
(`movie` or `episode`).

```text
intake  --probe-->  files(staging)  --resolve-->  associations
   |                                                   |
   +-------------------- rename --apply ---------------+
                             |
                             v
buffer  --rename-->  files(buffer)   [awaiting your approval]
   |
   +---------------------- move -----------------------+
                                                       |
                                                       v
library --index-->  files(library) + catalog rows
```

Movies use `intake` / `buffer` / `library`. TV uses `tvIntake` / `tvBuffer` /
`tvLibrary`. Same shape, different roots, different `media_kind`. There is no
separate "destination" field: `move` writes to the library root, `index` reads
from it.

- **intake** is where fresh downloads land. Read-only to uniDork.
- **buffer** is the holding pen between rename and promotion. `rename` writes
  renamed folders here; `move` reads here and **deletes from here** on a
  successful promotion. Review here before promoting.
- **library** is your actual library. `move` writes here; `index` reads here to
  catalogue.

All roots are configured in `nix/config.nix` under `paths`.

### The `stage` and `media_kind` columns

- `staging` means probed in intake, resolvable.
- `buffer` means renamed into the buffer. **Excluded from** `resolve`; its
  identity comes from the NFO that `rename` wrote.
- `library` means promoted, or catalogued directly, into the library.
- `missing` means the source file vanished and `sweep` retired the row.

`media_kind` partitions the resolvers: `resolve` matches `media_kind = 'movie'`
and `stage <> 'buffer'`; `tv-resolve` matches `media_kind = 'episode'` and
`stage = 'staging'`.

### `move`, per movie buffer folder

1. Enforce that the destination is under the configured `library` root.
2. Refuse if the destination folder already exists. `move` cannot overwrite.
3. Find the video, look up its `files` row by buffer path, verify the on-disk
   size matches the stored size. On match the stored CRC32 is trusted with no
   rehash. On miss or mismatch, fall back to a name-based path update.
4. Same filesystem, atomic rename. Cross filesystem, rsync to
   `.unidork-partial` under the library root, then commit. This is the point of
   no return.
5. Update the `files` row to the new path and `stage='library'`, by identity
   where verified and by name otherwise.

**Blast radius** of one movie `move` is exactly one folder added to the library
and one removed from the buffer.

### `tv-move`, the same but it merges

If the destination show folder does **not** exist, `tv-move` behaves like movie
`move`. If it **does** exist, it merges: `mergeTree` on the same filesystem, or
`rsync` into the existing tree cross-filesystem. Existing video files at the
destination are skipped, never overwritten.

This is a deliberately wider blast radius than movie `move`: a `tv-move` can
touch an existing show folder. It still only writes under `paths.tvLibrary`.

## Database and safety

```sh
unidork bootstrap [--empty]      # first run on a new machine
unidork schema                   # create/migrate movie and tv schemas
unidork status                   # row counts and backup inventory
unidork gc                       # table sizes, dead tuples, stranded rows
unidork backup [--init|--list]   # verified, checksummed dump
unidork backups                  # list dumps
unidork restore <file|latest>    # restore into a FRESH side database
unidork restore <f> --swap       # ...then swap names
unidork start | stop             # postgres lifecycle (start == ensure, safe)
unidork psql                     # interactive session
unidork clean-stage              # truncate probe_cache, forces re-probe
```

`restore` is non-destructive by design. Without `--swap` it restores into
`<db>_restored_<ts>` and leaves your live database untouched, which means
**without `--swap` your data is not live**. If a pipeline then complains that
`probe_cache` does not exist, you restored without swapping.

`--swap` preserves the old database as `<db>_pre_restore_<ts>`. Nothing ever
reaps those. `unidork gc` lists them; drop them yourself when satisfied.

`--apply` takes a throttled auto-backup first, skipped if the newest dump is
younger than `database.backup.autoIntervalHours`. Dumps are verified with
`pg_restore --list` before being renamed off `.partial`, get a `.sha256`
sidecar, and are pruned to `database.backup.keep`.

## Secrets

Three API keys, all consumed by the Unison side as **file paths**, never as
values, so nothing ever lands in the Nix store or a process listing.

| variable | sops key | runtime path |
| --- | --- | --- |
| `UNIDORK_TOKEN_TMDB` | `unidork/tmdb_token` | `/run/secrets/unidork/tmdb_token` |
| `UNIDORK_TOKEN_SUB` | `unidork/opensubtitles_key` | `/run/secrets/unidork/opensubtitles_key` |
| `UNIDORK_TOKEN_FANART` | `unidork/fanart_key` | `/run/secrets/unidork/fanart_key` |

Resolution order at runtime, implemented in `nix/secrets.nix`:

1. the variable is already exported, use it
2. `/run/secrets/unidork/<key>` is readable, use it
3. otherwise `$HOME/.config/uniDork/<legacy-name>`

`unidork secrets` prints which source is actually in play per key, plus a
truncated sha256 so you can compare two machines without printing a key.

Provisioning is a NixOS module, `nixosModules.unidork`, which adds three
namespaced `sops.secrets` entries and nothing else. It deliberately sets no
global sops-nix option, so it cannot disturb other secrets on the host. See
`SECRETS.md` for rotation and adding a machine.

## Configuration

Everything lives in `nix/config.nix`. Nix is the source of truth; the Unison
side reads env vars with fallbacks and never reads a config file.

| section | controls |
| --- | --- |
| `repo` | repo dir, Unison project/branch/Share target |
| `database` | host, name, user, port, data dir, `backup.{dir,keep,autoIntervalHours}` |
| `paths` | `intake` `buffer` `library` and the `tv*` trio |
| `rename` | `movieFormat`, `tvFormat` format DSL strings |
| `secrets` | the API key table: env var, sops key, legacy filename |
| `artwork` | which kinds per domain, TMDB and fanart.tv throttles |
| `subs` | subtitle languages and inter-request delay |
| `tuning` | probe jobs, chunk sizes, stage timeout, memory limits, `GHCRTS` |
| `ide` | VS Code extensions and settings, synced by `unidork-ide-sync` |

**Going to production:** change `paths.library` and `paths.tvLibrary` to your
real library paths. Before the first production `move`, verify with
`echo "$UNIDORK_PATH_LIBRARY"` inside the devshell. Those env vars are the only
thing controlling where `move` writes.

The TV format string must contain exactly two `/` separators: show, season,
file.

`tuning` is currently single-valued and applied identically on every host.
There is no per-machine dimension yet; the `# blade:` comments are aspirational,
not wired.

## Memory

Stages run inside a systemd user scope with `MemoryHigh` and `MemoryMax` when a
session bus exists, and with `GHCRTS` set from `tuning.ghcRts`. Override with
`UNIDORK_MEM_HIGH`, `UNIDORK_MEM_MAX`, `UNIDORK_GHCRTS`,
`UNIDORK_TUNE_STAGE_TIMEOUT`.

Every stage is a separate process, so resident memory resets between stages.
Within a stage, RSS climbs to a working-set plateau and stays there; this is GHC
heap growth, not a leak. On a 6967-title library the observed peaks are roughly
980 MB for `index`, 1030 MB for `versions`, and 1440 MB for `nfo`. Size
`memoryMax` above the `nfo` figure or that stage will be killed.

## What works

- **Stage probing.** `probe` and `tv-probe` walk intake, CRC32 via rhash plus
  ffprobe, write `files` rows keyed on `(crc32, size_bytes)`. TV probing skips
  extras and sample dirs and recurses to a bounded depth.
- **TMDB identification.** `resolve` matches movies by normalized title, year
  proximity, and a runtime tiebreaker. `tv-resolve` matches episodes by parsed
  `SxxEyy`, with folder-derived season and episode fallbacks, resolving the show
  by NFO id, `{tmdb-...}` or `{imdb-...}` folder tags, IMDB `find`, or
  title/year search. Search, details, and season payloads are all cached in
  Postgres.
- **Rename pipelines.** FileBot-style format DSL for both domains, writing
  renamed folders from intake into the buffer.
- **Full NFO emission.** Movies emit a complete Kodi `movie.nfo` with
  uniqueids, ratings, cast, and fileinfo/streamdetails. TV emits a `tvshow.nfo`
  per show and an `episodedetails` NFO per episode, with multi-episode
  (`SxxEyyEzz`) support.
- **Sidecar subtitles.** `subs` harvests subtitle files already present next to
  the source, then fetches the remaining languages from subdl by IMDB or TMDB
  id, saved as language-tagged sidecars.
- **Promotion.** `move` and `tv-move` promote reviewed buffer folders with
  identity verification, including merge-into-existing for TV shows.
- **Library import.** `index` catalogues the movie library into
  `library_movies` keyed on `folder_checksum`, self-probing and CRC-verifying.
- **Version and edition detection.** `versions` clusters multiple copies of the
  same TMDB id into editions by frame-rate-normalized runtime, so a PAL
  speed-up and its NTSC source land in one edition while a real extended cut
  lands in another. Copies are ranked by resolution, bit depth, bitrate, and
  codec.
- **Kodi version stamping.** `nfo` writes `hasvideoversions`,
  `videoassettitle`, and `isdefaultvideoversion` into each `movie.nfo`,
  idempotently, so Kodi groups the copies as versions of one movie.
- **Artwork.** `artwork` fetches posters, fanart, and clear logos from TMDB, and
  TV banners from fanart.tv, throttled per provider. `artscan` inventories what
  is actually on disk into `artwork_log` so you can query coverage.
- **Backups.** Verified, checksummed, pruned, and taken automatically before
  every `--apply`.
- **Secrets.** sops-nix provisioning with a legacy fallback and a doctor
  command.
- **Audio language analysis.** `Relang.*` decides default-track flips
  (computed, not yet applied).

## What's next

- **Apply the Relang decision.** `Relang.decide` computes the correct default
  audio track but nothing remuxes to apply it.
- **Subtitle muxing.** Movie subs are fetched as sidecars; muxing into the MKV,
  and any TV subtitle fetch at all, is unimplemented.
- **Per-host tuning.** One `tuning` block for every machine. A small box needs
  different memory ceilings and probe concurrency than the workstation.
- **Machine-readable output.** The orchestrator's stage table is
  pipe-delimited text inside a shell function and the default mode prints a plan
  and exits non-zero. Both are fine for a human and wrong for anything driving
  uniDork over HTTP. A `--json` mode comes before any web control panel.
- **A re-match gate at promotion**, optional. `move` trusts the NFO id and does
  not re-match.
- **Dead config.** `config.cache` and the `UNIDORK_CACHE_*` env vars are read
  into a Unison record that nothing consumes. Remove them.

None of this will involve Haskell, no matter how convenient that would be.

## Codebase workflow

```sh
unidork push          # push to Unison Share, commit a causal-hash snapshot
unidork snapshot      # render the namespace to snapshots/namespace.u, commit
unidork log-change    # archive scratch.u into changes/, commit
unidork logs          # list log files
```

`snapshot` is the slow one: it runs `edit.namespace .` through a UCM transcript.
`push` records the causal hash in `.unidork-snapshot-hash` and writes a diff
summary under `backup/`. Restore by causal hash, never from the diff text.

## Stack

Unison (`@unison/base`, `@unison/json`, `@unison/xml`, `@unison/http`,
`@runarorama/postgres`), PostgreSQL, Nix flakes, sops-nix,
ffmpeg, rhash for CRC32, rsync for promotion, jq. No Python. No Docker. And
though I adore it, no Haskell here.

## Build

```sh
nix build                        # the orchestrator
nix build .#unidork --no-link    # same, no ./result symlink, quiet failure
nix build .#unidork-import       # the compiled Unison binary wrapper
nix build .#unidork-secrets      # the secrets doctor alone
```

`./result/bin/unidork-import` runs the compiled pipeline without ucm.

### Working on the code

The compiled binary (`bin/unidork-import.uc`) is **not** the live UCM namespace.
After editing definitions, test via `run <thunk>` against the namespace, then
`compile cli ./bin/unidork-import` and `direnv reload` to update the binary.
Editing the namespace and testing via `unidork` silently tests stale code.

The orchestrator and the secrets doctor are `writeShellApplication`, which runs
shellcheck as a build phase and treats every finding as fatal, including `info`
level. The Postgres helpers are `writeShellScriptBin` and are not linted.

### Unison Share

[Unison Share repo](https://share.unison-lang.org/@harryprayiv/uniDork/code/main)

## License

[AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html).
