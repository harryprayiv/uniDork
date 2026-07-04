# Writing Unison Without Fighting the Parser: A Field Guide for LLMs

You are about to write Unison code. Unison is superficially Haskell-shaped,
and that resemblance will hurt you: most of your errors will come from
applying Haskell instincts to a language with a stricter layout parser, no
typeclasses, no operator sections, hash-based identity, and a fundamentally
different edit workflow. Read this before emitting any code, and run the
checklist at the end before every scratch file you produce. Every rule in
here was paid for with a real typecheck round-trip; do not rediscover them.

## 1. The workflow shapes everything

Unison code lives in a content-addressed database (the "codebase"), not in
files. You edit by writing definitions into a *scratch file* (`scratch.u`),
which UCM watches and typechecks. `update` replaces existing definitions by
name. Consequences:

- **Emit whole definitions only.** There is no diffing, no partial edits,
  no "change line 12." A definition in the scratch file replaces the old
  one entirely on `update`. To add one arm to a `match`, re-emit the whole
  function containing it.
- **Compiled binaries are snapshots.** `compile main ./bin/foo` freezes the
  namespace at that moment. Editing the namespace afterward does not change
  the binary. After every successful `update`, remind the user to recompile
  and reload; otherwise they test stale code.
- **UCM's pretty-printed output is NOT guaranteed to re-parse.** Output
  from `view`, `edit`, or a namespace dump is a rendering, not
  round-trippable source. In particular, raw hash references like
  `#p62igq83bo` appear in rendered output when a dependency has no name in
  scope, and they fail to parse when copied into a scratch file. When you
  see a raw hash in code you were given, replace it with a named reference
  or restructure. Never emit a raw hash in a scratch file.
- **Dependencies are vendored under versioned namespaces**, and multiple
  versions of one library routinely coexist: `unison_json_1_3_5.Decoder`
  and `unison_json_1_4_2.Decoder.run` may both appear in one function, on
  purpose (types from one version, runners from another). Never "clean up"
  or upgrade a version qualifier, and when writing new code, copy the exact
  version qualification used by the nearest existing code in the codebase.
  A different version of the same-named type is a different type.

## 2. The parser and typechecker stop at the FIRST error

One scratch file, one error report, always the earliest failure. This
means:

- Fixing an error frequently "reveals" a new error further down. The new
  error was already there, masked. Expect a multi-round landing for any
  nontrivial scratch file, and say so to the user up front.
- The reported line/column may point one token *past* the real problem (the
  parser reports where it gave up, often the line after the unparseable
  construct).
- **Use the indentation shown in the error excerpt to locate the failing
  definition.** The error prints the offending line with its original
  indentation. A binding at 4 spaces is near the top of a function body; 20
  spaces is deep inside nested handlers. Match the indent depth against
  candidate definitions when the same identifier appears in several places.
- Expectation lists tell you the parser's *position*. Pattern tokens
  (`blank`, `false`, `true`, literals) mean it wanted a pattern (another
  `cases` arm). Term tokens (`do`, `handle`, `if`, `lambda`, `force`,
  `quote`) mean it wanted an expression (a binding's right-hand side was
  missing or unparseable).

## 3. Layout: where LLM-written Unison actually dies

Unison uses an offside/layout rule like Haskell's but less forgiving. The
recurring fatal pattern:

**A binding (`x = ...`) may not be the first thing in an inline lambda
body.** This does not parse:

```unison
List.flatMap
  (d ->
    dfp = pathJoin folder d      -- PARSE ERROR: "surprised to find a = here"
    somethingWith dfp)
  items
```

A lambda body wants a single expression. The fix is not whitespace
massaging and not a `let` wrapper (legal but layout-fragile). The fix is
**extract a named top-level function**:

```unison
subsInDir : FilePath -> Text ->{IO, Exception} [(FilePath, Text)]
subsInDir folder dirName =
  dfp = pathJoin folder dirName   -- fine: bindings in a function body parse
  somethingWith dfp

-- call site becomes:
List.flatMap (subsInDir folder) items
```

Hard rule: **the moment a lambda body needs more than one expression, or a
fold/match arm nests more than about three levels deep, extract a named
helper — at write time, not after the parse error.** This is also better
Unison regardless: extracted helpers are independently testable via `test>`
watch expressions, which is the house style in good Unison codebases.

Related layout facts:

- `then`, `else`, `match` arms, and `cases` arms followed by newline +
  indent open blocks; bindings inside them are fine. The fragility is
  specifically inline lambdas and very deep nesting.
- Every `if` requires an `else`. `if` is an expression. Conditional side
  effect idiom: `if cond then doThing() else ()`.
- Guards in match arms: `match x with n | n > 0 -> ...`.
- Multi-line binding RHS must be indented past the binding's start column.

## 4. Names: resolution, ambiguity, and migration traps

Unison resolves names by suffix: the bare name `title` can refer to
`Movie.title` or `Title.title` and resolves only if unique in scope. This
produces three distinct failure modes:

- **Plain ambiguity.** Bare `<` with no `use` clause is ambiguous across
  `Nat.<`, `Int.<`, `Float.<`, `Text.<`. Fix with a `use` clause or
  qualified-infix (`a Nat.< b`).
- **Ambiguity across libraries.** `sleepMicroseconds` may exist as both
  `Remote.sleepMicroseconds : Nat ->{Remote} ()` and
  `concurrent.sleepMicroseconds : Nat ->{IO, Exception} ()`. When UCM lists
  candidates, **read the candidate TYPES, not just the names** — the
  ability rows differ, and picking one can force a signature change on the
  function you are editing (see section 7 on ability widening). These are
  not interchangeable picks even though either "resolves."
- **Stale-version capture during type migration.** When a scratch file
  redefines a type that already exists in the codebase, a bare constructor
  name (`Tuning`) can suffix-resolve to the OLD codebase constructor
  instead of the file's new one, producing arity errors like "applied to 3
  arguments but has type `Nat -> [Text] -> Tuning`". Rule: **in any scratch
  that redefines a type, write its constructor fully qualified
  (`Config.Tuning.Tuning`) at every construction site in that file.**
  A wrong-arity constructor error during a migration means resolution
  picked the stale version, not that your code is wrong.

Also: `use` clauses are per-block and can appear at the top of any block.
When you write one like `use Nat + < toText`, verify every operator the
body actually uses appears in it — a symbol silently dropped from a `use`
line (easy during copy-paste) surfaces only as a later ambiguity error.
When in doubt, full qualification always parses and always resolves.

## 5. Literals, delays, and forcing

- `Nat` literals are bare: `0`, `42`. **`Int` literals require a sign:**
  `+0`, `+7`, `-1`. Writing `0` where an `Int` is expected is a type error;
  this bites in fold accumulators and DB ids. Convert with `Nat.toInt` /
  `Nat.fromInt` (returns `Optional`).
- `Nat` subtraction truncates at zero (`3 - 5 == 0`). Guard comparisons
  before subtracting, or use `Int`.
- `Float` needs the point: `0.0`. Scientific: `1.5e-2`.
- Char literals use `?`: `?a`, `?/`, `?\s`, `?\t`. `Text.split` takes a
  `Char`: `Text.split ?/ path`.
- Delays: `'expr` delays, `do ...` is a delayed block, type `'{g} a`.
  Force with juxtaposed unit: `thunk()`. A function returning `'{IO} ()`
  is invoked `f x ()` — the trailing `()` at the call site is easy to drop
  and, where types permit, drops silently. Entry points are shaped
  `main : '{IO, Exception} ()`.
- `Text` is a rope: `++` is cheap, including in accumulation loops. Do not
  "optimize" it.

## 6. Everything is an expression; discards are explicit

No statements. A block's value is its last expression. Sequencing effects:

```unison
_ = printLine "step 1"
_ = catch do riskyThing()
finalExpression
```

The `_ =` discard is mandatory; a bare expression mid-block is a parse
error. `Function.ignore` discards inside expressions.

## 7. Abilities, not monads

No monad typeclass, no monadic do-notation. Effects are ability rows on
arrows: `Text ->{IO, Exception} Nat`.

- `Exception` is an ability. `catch do riskyThing()` gives
  `Either Failure a`. `Exception.raise` throws. `Failure.message` extracts
  the text.
- Handlers use `cases` on operation requests; `k` is the continuation,
  `{ r }` the completion case:

```unison
logGo = cases
  { r }             -> r
  { info msg -> k } ->
    _ = printLine msg
    handle k() with logGo

result = handle program() with logGo
```

  Each operation case must re-wrap its continuation (`handle k() with
  logGo`); forgetting it handles only the first operation.
- **Ability widening propagates caller-ward.** If a body gains a call
  requiring `Exception`, the function's declared row must widen, and so
  must every caller declaring a narrower row, transitively, **terminating
  at the first caller already carrying that ability**. Before widening,
  trace the call chain upward, find the termination points, and re-emit
  exactly the signatures in between — usually far fewer than you fear,
  often zero beyond the function itself.
- **`printLine` is `Text ->{IO, Exception} ()`.** Adding a debug print to a
  function declared `->{IO}` is an ability widening and fails with "needs
  the {Exception} ability". Before declaring any effectful function's row,
  check the row of EVERY base function the body calls — printing, file
  stats, and env reads mostly require Exception, not just IO. When unsure,
  omit the signature, let inference supply the row, and read what it
  inferred.
- Signatures copied from rendered output may contain numbered effect
  variables (`->{g54, g55}`). Either copy them verbatim or omit the
  signature and let inference supply it. Never hand-edit the numbering.
- Handlers are also the pure-testing mechanism: a "scripted" handler
  returns canned responses; a "recording" handler threads an accumulator
  and returns `(result, log)`. Production codebases test effectful logic
  this way (`test>` + scripted handlers), keeping the DB and network out of
  tests entirely. Prefer designing new effectful code as an ability + a
  production handler + a scripted test handler.

## 8. No typeclasses

- Equality: `Universal.eq a b` (structural), or per-type operators
  (`Nat.==`, `Text.==`) via `use`.
- No `Show`: `Nat.toText`, `Int.toText`, `Float.toText` are distinct
  functions.
- No `Functor`/`Monad` polymorphism: `Optional.map`, `List.map`, `match`
  on `Either` — all concrete.
- Serialization/codecs are explicit values passed around (decoder thunks,
  codec combinators), never derived.

## 9. Types are hashes: the change-closure protocol

Names are metadata; types and terms reference each other by hash. Changing
a type's shape is therefore never local. The full protocol, in order:

1. **Type closure (upward containment).** Every type with a field of the
   changed type must be re-emitted in the same scratch, transitively.
   Change `Tuning` → re-emit `Config` → re-emit anything containing
   `Config`. Symptom of a miss: "has type: B, but I expected: #somehash".
   A raw hash in a type error almost always means a stale version of a
   type you just renamed out from under something still pointing at it.
2. **Constructor qualification.** Fully qualify the redefined type's
   constructors at every construction site in the scratch (section 4).
3. **Scratch self-consistency (term closure).** The scratch does NOT need
   every codebase function mentioning the changed type. It needs only the
   codebase terms that the scratch itself applies to values of the new
   type — grep the SCRATCH, not the codebase, and copy exactly those in
   verbatim. Symptom of a miss: "has type: Config, but I expected:
   #somehash" pointing at a call site in your scratch.
4. **Let propagation do the rest.** `update` re-typechecks downstream
   dependents against the new hashes and upgrades them automatically when
   their bodies still check (accessor-only usage always does). Anything it
   cannot handle, it reports — fix exactly those, one more round.
5. **Corollary:** never include a high-fan-out root like `main`/`cli` in a
   type-change scratch unless forced; it drags its entire call graph into
   the self-consistency requirement. Land the type change first, then the
   root in a follow-up scratch.

Plan any change to a widely-used type as a whole-closure operation BEFORE
the first update attempt. Discovering the closure one typecheck error at a
time costs one round-trip per member. In Unison, the unit of change is the
hash-closure, not the definition.

## 10. Records

`type T = { a : Nat, b : Text }` generates `T.a : T -> Nat`,
`T.a.set : Nat -> T -> T`, `T.a.modify : (Nat -> Nat) -> T -> T`. No
record-update syntax; chain setters:

```unison
m |> T.a.set 5 |> T.b.set "x"
```

Field names collide constantly across types (`.title`, `.codec`, `.name`);
disambiguate with the full path (`Movie.title m` vs `Title.display t`) or
`use` clauses. Accessors regenerate automatically when the type is updated;
constructor call sites do not — re-emit them with the new arity (and see
section 9 for everything else a field change triggers).

## 11. Pattern matching and database rows

- `match x with` arms, or `cases` as sugar for a one-argument lambda that
  immediately matches: `List.map (cases (a, b) -> a) pairs`.
- List patterns: `[]`, `x +: rest`, `init :+ x`, `[a, b]` exact. `+:`/`:+`
  are also the expression-level cons/snoc — same symbols both positions.
- **DB row tuples are left-nested to mirror codec composition.** A codec
  built as `text ~ text ~ bigint ~ text` yields rows of type
  `(((Text, Text), Int), Text)`, and the destructuring pattern must nest
  identically: `((((a, b), c), d))`. When you add a column to a query,
  add one level of nesting to every pattern that consumes its rows — a
  mismatch is a type error naming a tuple shape, and counting parens
  against the codec's `~` chain is the fastest fix.
- **Postgres codecs are validated against actual column types AT RUNTIME**,
  per query, with an unhandled "Column alignment mismatch" exception on
  first execution. `integer` means int4 and `bigint` means int8; match the
  DDL column type, not the Unison-side type (both decode to `Int`).
  Asymmetry that creates false confidence: PARAMETERS (`var integer` in a
  WHERE clause) are coerced by postgres and work even when mistyped, but
  RESULT-COLUMN codecs are checked strictly. Copying a codec choice from a
  working parameter into a SELECT decoder is therefore not evidence it is
  correct. When writing any new SELECT, read the table's DDL (or an
  existing SELECT of the same columns) and align the `~` codec chain to it
  column by column. The error dump prints both sides ("Query types" vs
  "Row types") — diff them to find the misaligned position.
- Bare `None` requires `use Optional None`; otherwise write
  `Optional.None`. Same discipline for any constructor whose suffix
  collides.

## 12. Operators quick reference

No prefix application (`Nat.> x y` is a parse error), no sections
(`(> 3)` does not exist — write `(n -> n > 3)`), no `$` (use parens or
`|>`, which pipes left-to-right). Infix works bare after `use`, or
qualified: `a Nat.+ b`.

## 13. Tests are watch expressions

```unison
test> myFn.test =
  use Universal eq
  List.flatMap check
    [ eq (myFn 1) 2
    , eq (myFn 0) 0
    ]
```

Run on file save, cached by content hash. Failure branches:
`[Fail "message"]`. Test effectful code through scripted handlers
(section 7), never through real IO.

## 14. Runtime behavior of compiled programs

Compiled Unison runs on the GHC runtime, and that leaks through in ways an
LLM must anticipate when helping someone operate the resulting binaries:

- **stdout is line-buffered only at a terminal.** Piped through `| tee` or
  redirected, it block-buffers: a long-running program appears frozen while
  output accumulates in kilobyte chunks. `stdbuf` does NOT fix this (it
  targets libc buffering; GHC ignores it). To capture a log with live
  output, allocate a pseudo-terminal: `script -qefc "cmd args" /tmp/out.log`.
  When a user reports "nothing is happening" from a piped command, suspect
  buffering before suspecting a hang; check for live child processes
  (`pgrep`, `ps`) to confirm work is proceeding.
- **The `GHCRTS` environment variable can work on compiled Unison
  binaries** (verified on ucm 1.1-compiled output). `GHCRTS="-M5G -c"`
  caps the heap and switches to compacting GC. A capped program aborts
  with "Heap exhausted; Current maximum heap size is N bytes" — that
  message means a CONFIGURED cap fired, not that the machine lacks RAM;
  read the printed size and check the environment before blaming hardware.
  A heap cap is a diagnostic instrument: it converts a slow memory leak
  into an immediate, attributable failure at a known threshold.
- **procfs pseudo-files (`/proc/self/status`, `/proc/self/statm`) report
  size 0 to stat.** Whole-file readers that preallocate from the reported
  size (`readFileUtf8`) return an EMPTY string from them — silently, no
  exception. Read procfs via a handle and `getLine`. General rule: a read
  that "succeeds" with empty content from a file you know is non-empty
  means the reader trusted a lying stat. Prefer `/proc/self/statm` for
  memory readings (one line, space-separated page counts, field 2 =
  resident pages × 4KB) — no tab parsing, no field search.

## 15. Miscellaneous traps, rapid fire

- No `where` clauses. Helpers go before use in the body, or at top level.
- Lambda syntax is `x -> body`, not `\x -> body`.
- Local recursion is the loop idiom: `go acc = ... go acc'` then `go []`.
- `Optional` not `Maybe`; `Boolean` not `Bool`; `Boolean.not`, `&&`, `||`.
- Doc blocks are `{{ ... }}` with their own markup, not Markdown. Don't
  guess its syntax; don't edit Docs unless asked.
- `bug "msg" x` replaces `error`/`undefined`.
- Underscore-prefixed parameter names (`_unused`) are the convention for
  deliberately unused arguments and do parse as parameters.

## 16. Pre-emission checklist

Run this against your own code before outputting a scratch file:

1. Every definition complete — no elided bodies, no "rest unchanged".
2. No binding as the first line of an inline lambda; helpers already
   extracted, not planned.
3. Every bare operator in every body appears in an in-scope `use` clause or
   is qualified-infix. Count them; verify none were dropped in transit.
4. Every `Int` literal signed; every `Float` has a decimal point.
5. Every `if` has an `else`; every discarded effect has `_ =`.
6. Every delayed function forced at its call site (`f x ()`).
7. No raw hash references (`#abc...`) anywhere in the file.
8. Handlers re-wrap continuations (`handle k() with go`).
9. Declared ability rows checked against every base function the body
   calls (`printLine` and friends need `Exception`, not just `IO`); when
   unsure, omit the signature and read what inference supplies.
10. If a type changed: full closure protocol from section 9 executed —
    containing types re-emitted, constructors qualified, scratch
    self-consistent, roots like `cli` deferred to a follow-up scratch.
11. If an ability row widened: caller chain traced to its termination
    points and those signatures re-emitted.
12. On any ambiguity error: candidate types read, ability rows compared,
    and downstream widening from the pick accounted for before choosing.
13. Every new SELECT's codec chain aligned column-by-column against the
    table DDL (`integer`=int4, `bigint`=int8); parameter codecs are not
    evidence for result codecs.
14. Version-qualified library references copied exactly as the codebase
    already writes them; no version "upgrades".
15. Warned the user that fixing this round's error may reveal the next,
    and that a recompile + reload is required after a successful update.