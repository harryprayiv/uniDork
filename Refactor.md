One correction before the plan, because it matters for what "boom" proved: I told you to expect the re-probing note, and it didn't print. That's because the trust gate HIT, meaning a `files` row already pointed at the buffer path, almost certainly from the import-buffer run you did during Phase 2 verification. So you accidentally certified the **hit path** (trusted CRC, zero recompute, the important one), and the miss path remains untested. Fine trade. Do still run the five verification queries and the `diff -r` against your backup once; one console line is a claim, not a verification.

Now the unification plan. The custody chain today has exactly one break and one pile of waste, and everything follows from fixing those.

# uniDork Custody Unification — Refactor Plan

## The core insight that makes this cheap

`rename --apply` relocates the video with `renameFile`, which is `rename(2)`. It only works within one filesystem (it would fail with EXDEV otherwise, and it doesn't), and within one filesystem it is a metadata operation: the bytes never move. Therefore **the CRC verified at staging is still valid at the buffer path, by construction.** The only reason import-buffer re-reads every byte of every buffer file is that rename never told the database the file moved. Fix that one omission and the redundant re-hash of the entire buffer evaporates. That is the FileBot property you're after: identity is established once, at first contact, and every subsequent step transfers custody instead of re-establishing it.

## Phase 1 — rename becomes custody-preserving (the keystone)

`Rename.executeOne`, on the success branch only (after `renameFile` returns), replaces the narrow `recordProposedSql` write with one command that moves the row with the file:

- `UPDATE files SET original_path = <target video path>, original_name = <target video basename>, proposed_name = ..., proposed_folder = ..., stage = 'buffer' WHERE crc32 = ... AND size_bytes = ...` (keyed on content identity; size comes from the already-decoded ProbeResult).
- Upsert a `probe_cache` row for the new path (stat the renamed file for mtime; `Stage.fileStat` exists). This is what makes any later buffer walk a cached skip.
- Delete the stale `probe_cache` row for the old intake path (one new trivial DELETE command).
- `DuplicateRemoved` branch: touch nothing; the surviving copy owns its own row.

Be clear-eyed: this **reverses your earlier deliberate decision** that rename doesn't flip stage. The approval semantics shift with it: the buffer directory IS the review queue, and `move` IS the act of approval. import-buffer stops being a required step in the happy path. You flagged the two-step as a possible annoyance back then; you're now confirming it annoyed you. Good, but it should be a conscious reversal, not a drive-by.

## Phase 2 — import-buffer demoted to reconcile/audit

After Phase 1 this needs almost no code: `runProbeAt`'s existing probe_cache gate already skips everything rename recorded. Its remaining job is recording files that uniDork didn't put in the buffer (manual drops, disaster recovery). Update the help text to say so, and add a one-line summary (N cached / N probed) so a healthy run visibly reports near-zero probes. Optional: alias it `reconcile`.

## Phase 3 — the chain verb (the FileBot moment)

New `unidork process`: `probe-stage` → `resolve` → `rename --apply`, sequenced exactly the way `import-all` chains (sequence, don't weld), ending with a printed trailer: "review the buffer, then: unidork move". Plumb through `cli` and the orchestrator case block. **It stops at the buffer on purpose.** I recommend NOT building a `--promote` full-auto flag yet: `move` trusts the NFO id with no re-match, so full-auto would mean zero identity checks between torrent name and library. If you ever want one-shot, the prerequisite is a verification gate at promotion (re-match title/year/runtime against the NFO id), which is a separate piece of work. `run` stays as the library-maintenance verb.

## Phase 4 — excise the stage_probes zombies

This came out of reading your codebase and it's worse than cosmetic: `stage_probes` is not created by `createSchema` (only `dropDdl` mentions it), yet `Stage.selectProbeSql`, `Stage.selectLargestInFolderSql`, `Stage.cachedCountSql`, `Stage.readFromDb`/`readSidecar`, `Stage.upsertProbeSql`/`upsertProbeWith`/`upsertBatch`, `Rename.deleteProbeBySourceSql`, and `Rename.selectRenamedTargetByCrcSql` all query it. Every one of those is wrapped in `catch` and silently returns None/false. Concrete consequence: `identify`'s runtime tiebreaker (`largestInFolderWith`) has been returning None unconditionally, so the runtime disambiguation between same-title candidates **never fires in identify**. Port that lookup to `files` (it has `duration_sec` as a column; you don't even need to decode probe_json), then delete the zombie definitions. Use UCM `dependents` on each before deleting so nothing live gets orphaned. This is the "trimmed down" you asked for, plus a silent bug fix.

## Phase 5 — `unidork verify`, custody as a checkable invariant

Cheap pass: for every `files` row with stage in (buffer, library), confirm the path exists and on-disk size equals `size_bytes`; for `library_movies`, the existing `crc32 <> folder_checksum` audit plus folder_path existence. `verify --deep <name|all>` rehashes and compares against the stored CRC. This turns "full verified custody" from a design intention into a command that can prove it any day, which is what you actually want before pointing `paths.library` at `_Movies`.

## Build order and dependencies

1 is the keystone and blocks 2. 3 depends on nothing but reads better after 1. 4 is independent (do it second, it shrinks the codebase before further work). 5 is independent. Suggested order: **1 → 4 → 3 → 5**, testing each via `run` thunk, then `compile cli ./bin/unidork-import` + `direnv reload` before any `unidork` invocation.

## Decisions I need from you before writing code

1. Verb name: `process`, `intake`, or something else?
2. Confirm the Phase 1 reversal (rename flips stage, move = approval). 
3. import-buffer: keep the name or rename to `reconcile`?

---

# End-to-end acceptance test (rename → library)

This block works against the **current** binary too, as a baseline: today, step 5 will print the re-probing note at `move` (the custody break, since these intake files were never import-buffer'd at their future buffer paths). After Phase 1 lands, the same block must run with **no re-probe note**. Same script, red to green. Caveat: `rename --apply` is a batch verb, it renames everything associated in intake, so either run this when intake holds just your test folder or accept the batch.

```fish
# 0. preflight
echo $UNIDORK_PATH_INTAKE
echo $UNIDORK_PATH_BUFFER
echo $UNIDORK_PATH_LIBRARY

# 1. pick one small movie folder in intake and back it up
ls $UNIDORK_PATH_INTAKE
set src "<exact intake folder name>"
set backup /home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/e2e-backup
mkdir -p $backup
cp -a "$UNIDORK_PATH_INTAKE/$src" $backup/

# 2. stage and match
unidork probe-stage
unidork identify          # eyeball the verdict for $src; if SKIP, pick another folder
unidork resolve

# 3. capture the staged CRC (the custody anchor for the whole test)
psql -At -c "SELECT crc32, original_path FROM files WHERE stage = 'staging' ORDER BY probed_at DESC LIMIT 5"
set crc XXXXXXXX          # paste the CRC for your test file

# 4. rename into the buffer
unidork rename --apply

# ACCEPTANCE (post Phase 1): the row moved with the file
psql -At -c "SELECT stage, original_path FROM files WHERE crc32 = '$crc'"
#   expect: buffer | /...AMC/TEST/<new folder>/<new file>
set folder (basename (psql -At -c "SELECT proposed_folder FROM files WHERE crc32 = '$crc'"))
ls "$UNIDORK_PATH_BUFFER/$folder"
bat "$UNIDORK_PATH_BUFFER/$folder/movie.nfo"   # your manual review gate

# 5. promote
unidork move "$folder"
# ACCEPTANCE: NO "note: not trusted from cache, re-probing" line

# 6. five-point verification
test -d "$UNIDORK_PATH_BUFFER/$folder"; and echo "STILL IN BUFFER (bad)"; or echo "gone from buffer (good)"
ls -la "$UNIDORK_PATH_LIBRARY/$folder"
psql -At -c "SELECT stage, original_path FROM files WHERE crc32 = '$crc'"
psql -At -c "SELECT a.tmdb_id, a.confidence, a.match_source FROM associations a JOIN files f ON f.file_id = a.file_id WHERE f.crc32 = '$crc'"
psql -At -c "SELECT folder_checksum, crc32, title FROM library_movies WHERE crc32 = '$crc'"

# 7. the custody seal: rehash the final library bytes against the CRC staged at intake
set finalvideo (find "$UNIDORK_PATH_LIBRARY/$folder" -type f \( -name '*.mkv' -o -name '*.mp4' -o -name '*.avi' \))
set got (rhash --crc32 -p '%C' "$finalvideo" | string upper)
test "$got" = "$crc"; and echo "CUSTODY VERIFIED end to end: $crc"; or echo "CRC MISMATCH: staged $crc, library $got"
```

Step 7 is the one that earns the word "verified": one independent hash of the final artifact equal to the hash taken at first contact, with rename(2) semantics and rsync transfer verification covering every hop in between.

Answer the three decisions and tell me which phase to write first; you'll get complete pasteable definitions, and anything I can't verify against your libraries gets flagged.