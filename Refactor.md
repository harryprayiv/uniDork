Honest read first: you have three real problems and a pile of cosmetic ones. I'll name them in priority order so you don't conflate "this is annoying" with "this is broken."

## What's actually broken

**1. The TMDB-ID-from-NFO bug is the painful one.** Your NFO carries an authoritative TMDB ID, and `Tmdb.scoreCandidate` discards it. It only knows normalized title plus year. When two films share both (a re-release in the same year as a reboot, a remake in the same year as a documentary), every candidate goes to `Low "title and year mismatch"` and you skip. The fix is twenty lines: thread the NFO TMDB ID into scoring and return `High` if any candidate's `tmdbId` matches, regardless of title/year. If the NFO says `tmdb=12345` and no result contains 12345, that's its own actionable signal (TMDB renumbered, or the NFO is wrong); print a warning. Do this in isolation, ship it, then start the bigger work.

**2. Sidecar JSON files are not a data model.** They're a filesystem cache with the worst of both worlds: no transactions, no cross-queries, basename collisions, no GC when source folders disappear. Moving to Postgres is correct. Be honest about what you lose: `cat` and `jq` for ad-hoc inspection. You'll be typing `psql` queries instead. If that bothers you, keep emitting the JSON as a debug artifact, but make the DB the source of truth.

**3. "One command" is two problems.** (a) Sequencing steps in one process is trivial. (b) Making each step idempotent so re-running doesn't double-work requires you to define precisely what "already probed/identified/renamed" means. Solve (b) first. (a) falls out.

## Cosmetic stuff worth noting

- `Db.upsertWith` takes 21 PreparedCommand arguments. Wrap them in a record.
- `Db.foreach_` is hand-rolled `traverse_`. There's almost certainly a stdlib version.
- `Stage.sidecarPath` keys by folder basename. Two folders with the same basename in different parents collide. Database keys should be full paths.
- ffprobe and rhash run sequentially per video. They're independent. Background one or use `parallel` better.
- The shell-to-Unison boundary at JSON sidecars is the worst of both languages. Either keep shell doing all the I/O work (write straight to Postgres via `psql`) or move ffprobe invocation into Unison via `Process`. Don't half-and-half.

## The plan

### Phase 0: TMDB ID trust signal (do this first, alone)

Add `Optional Nat` for NFO TMDB ID to `Tmdb.scoreCandidate`. New rule: NFO TMDB ID match beats title/year match. Print a warning when NFO claims an ID that's absent from the search results. Plumb it through `Tmdb.reportFolder` (identify) and verify it's already honored in `Rename.processFolder` (it is, but the warning path isn't). Also fix `uniDork.identify` to handle loose videos (mirror what `uniDork.rename` does).

This is a single afternoon. It does not depend on any of the schema work.

### Phase 1: Staging schema

Decide once: same DB as library (`dork`) with a `staging` schema, or a separate `dork_staging` DB. I'd pick same-DB-different-schema. One connection config, clear visual separation, easy to TRUNCATE staging without touching library.

Tables:

```sql
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.videos (
  video_path       TEXT PRIMARY KEY,        -- full path, not basename
  folder_path      TEXT NOT NULL,
  crc32            TEXT NOT NULL,
  size_bytes       BIGINT NOT NULL,
  duration_sec     DOUBLE PRECISION NOT NULL,
  video_codec      TEXT NOT NULL,
  width            INTEGER NOT NULL,
  height           INTEGER NOT NULL,
  bit_depth        INTEGER NOT NULL,
  pix_fmt          TEXT NOT NULL,
  video_bit_rate   BIGINT,
  audio_codec      TEXT,
  audio_channels   INTEGER,
  audio_layout     TEXT,
  source_mtime     TIMESTAMPTZ NOT NULL,    -- for staleness checks
  probed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE staging.tmdb_searches (
  search_key       TEXT PRIMARY KEY,        -- hash of (title, year), not folder name
  query_title      TEXT NOT NULL,
  query_year       INTEGER NOT NULL,
  response_json    JSONB,
  error            TEXT,
  fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE staging.tmdb_details (
  tmdb_id          INTEGER PRIMARY KEY,
  response_json    JSONB NOT NULL,
  fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE staging.outcomes (
  id               BIGSERIAL PRIMARY KEY,
  source           TEXT NOT NULL,
  outcome          TEXT NOT NULL,
  target           TEXT,
  message          TEXT,
  occurred_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON staging.outcomes (source, occurred_at DESC);
```

Outcomes are append-only so you keep history.

### Phase 2: Shell probing writes to Postgres

`unidork-stage-probe` keeps doing ffprobe + rhash. It builds the JSON in `jq` as it does today, then pipes that to `psql` with an `INSERT ... ON CONFLICT (video_path) DO UPDATE`. SQL-in-shell is ugly, but it keeps your bash pipeline intact and avoids adding a new binary to the chain.

Tmdb caches: same treatment, but now Unison writes them. Replace `Tmdb.readCache` / `Tmdb.writeCacheEntry` with `staging.tmdb_searches` upserts. Same for `Tmdb.cachedDetails`.

### Phase 3: Idempotency

Each step's skip-rule, written explicitly so you can sanity-check them:

- **Probe**: skip if `staging.videos` has a row where `source_mtime >= mtime(video_file)`.
- **Identify**: skip if a search exists in `staging.tmdb_searches` younger than N days AND the NFO mtime hasn't changed since last identify outcome. Cheap, so honestly just always re-run.
- **Rename**: skip if `source` no longer exists. The rename either already happened or someone moved it manually.
- **Library ingest**: unchanged. Reads from rename target.

### Phase 4: One command

`uniDork.stage` (Unison) or `unidork-stage` (shell wrapper): probe → identify → rename → ingest, in order, with per-step summaries. Exit non-zero on first hard failure, but soft-fail (continue) on per-folder errors.

Keep `unidork-stage-probe`, `uniDork.identify`, `uniDork.rename`, and `uniDork.batchedRun` available individually. Don't delete them. You'll want them for debugging exactly once and be glad you kept them.

### Phase 5: Cleanup

`unidork-cleanup-staging`:
- `DELETE FROM staging.videos WHERE video_path NOT IN (...current disk state...)`
- `DELETE FROM staging.outcomes WHERE source NOT IN (...)`
- Leave `tmdb_searches` and `tmdb_details` alone. They cost rate-limit budget; never auto-delete.

Run it at the end of `unidork-stage` automatically. Standalone command for forced cleanup.

## Hard questions before you start

1. **Folder basename as key**: do you ever process two folders with the same basename from different parents? If yes, today's code silently corrupts caches. Switch to full paths everywhere.
2. **NFO mtime tracking**: if the user edits an NFO, should identify re-run? You probably want yes, which means storing NFO mtime on the outcome row.
3. **Loose videos with no parseable year**: today they fail silently. Worth an interactive fallback or a `staging.unmatched` table you can review later.
4. **Where does the rename land in the library DB?** Today rename moves files but doesn't ingest. `unidork-import` re-scans on the next cron. Do you want rename to write directly to `movies`, or keep the two-step (rename → re-scan)? Two-step is simpler and more recoverable. Don't merge them.

## What to do this week

Phase 0 today or tomorrow. It's small, it has visible payoff, it doesn't touch the schema. Then sit on it for a day and see if the bug you described actually disappears. If it does, start Phase 1 over the weekend. Don't try to do the whole plan in one sitting; the schema is the part most likely to get reworked once you start using it.