# Writing Unison Without Fighting the Parser: A Field Guide for LLMs

You are about to write Unison code. Unison is superficially Haskell-shaped, and
that resemblance will hurt you: most of your errors will come from applying
Haskell instincts to a language with a stricter layout parser, no typeclasses,
no operator sections, and a fundamentally different edit workflow. Read this
before emitting any code, and re-read the checklist at the end before every
scratch file you produce.

## 1. The workflow shapes everything

Unison code lives in a content-addressed database (the "codebase"), not in
files. You edit by writing definitions into a *scratch file* (`scratch.u`),
which UCM watches and typechecks. `update` replaces existing definitions by
name. Consequences:

- **Emit whole definitions only.** There is no diffing, no partial edits, no
  "change line 12." A definition in the scratch file replaces the old one
  entirely on `update`.
- **A `match` cannot be extended.** To add one arm, re-emit the entire
  function containing the match.
- **Compiled binaries are snapshots.** `compile main ./bin/foo` freezes the
  namespace at that moment. Editing the namespace afterward does not change
  the binary. Always assume a rebuild step exists and remind the user of it.
- **UCM's pretty-printed output is NOT guaranteed to re-parse.** Output from
  `view`, `edit`, or a namespace dump is a rendering, not round-trippable
  source. In particular, raw hash references like `#p62igq83bo` appear in
  rendered output when a dependency has no name in scope, and they will fail
  to parse if you copy them into a scratch file. When you see a raw hash in
  code you were given, replace it with a named reference or restructure to
  avoid it. Never emit a raw hash in a scratch file.

## 2. The parser stops at the FIRST error

One scratch file, one error report, always the earliest failure. This means:

- Fixing an error frequently "reveals" a new error further down the file.
  The new error was already there; it was masked. Do not assume your fix
  caused it, and do not assume the file only has one problem.
- When a user reports an error, the reported line/column may point one token
  *past* the real problem (the parser reports where it gave up, which is
  often the line after the unparseable construct).
- **Use the indentation shown in the error excerpt to locate the failing
  definition.** The error prints the offending line with its original
  indentation. A binding at 4 spaces of indent is near the top level of a
  function body; a binding at 20 spaces is deep inside nested handlers. Match
  the indent depth against candidate definitions to find which one failed.
- Expectation lists in errors tell you what *position* the parser was in.
  Seeing pattern tokens (`blank`, `false`, `true`, literals) means it wanted
  a pattern (e.g. another `cases` arm). Seeing term tokens (`do`, `handle`,
  `if`, `lambda`, `force`, `quote`) means it wanted an expression (e.g. the
  right-hand side of a binding was missing or unparseable).

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

A lambda body wants a single expression. Bindings need a block context, and
an inline lambda does not reliably open one. The fix is not whitespace
massaging, and it is not wrapping in `let` (legal but layout-fragile). The
fix is **extract a named top-level function**:

```unison
subsInDir : FilePath -> Text ->{IO, Exception} [(FilePath, Text)]
subsInDir folder dirName =
  dfp = pathJoin folder dirName   -- fine: bindings in a function body parse
  somethingWith dfp

-- call site becomes:
List.flatMap (subsInDir folder) items
```

Adopt this as a hard rule: **the moment a lambda body needs more than one
expression, or a fold/match arm nests more than about three levels deep,
extract a named helper.** This is not just a parser workaround; extracted
helpers are independently testable via `test>` watch expressions, which is
the house style in well-written Unison codebases anyway.

Related layout facts:

- `then` and `else` followed by newline + indent open blocks; bindings inside
  them are fine. Same for `match` arms and `cases` arms. The fragility is
  specifically inline lambdas and very deep nesting where indentation
  arithmetic goes wrong.
- Every `if` requires an `else`. `if` is an expression. The idiom for a
  conditional side effect is `if cond then doThing() else ()`.
- Guards in match arms: `match x with n | n > 0 -> ...`.
- Multi-line binding RHS must be indented past the binding's start column.

## 4. Operators: infix only, no sections, no `$`

- **No prefix application of operators.** `Nat.> (size xs) 1` is a parse
  error. Operators apply infix only.
- Two legal forms: import then use bare (`use Nat >` ... `size xs > 1`), or
  qualified infix (`size xs Nat.> 1`, `code Nat.== 0`).
- **No operator sections.** `(> 3)`, `(1 +)` do not exist. Write a lambda:
  `(n -> n > 3)`.
- **No `$`.** Use parentheses or the pipeline operator `|>` (left-to-right:
  `x |> f |> g`).
- Unqualified operators must resolve uniquely. Bare `<` with no `use` clause
  is ambiguous across `Nat.<`, `Int.<`, `Float.<`, `Text.<` and will fail
  name resolution (a post-parse error). When you write a `use` clause like
  `use Nat + < toText`, double-check every operator you actually use in the
  body appears in it — a dropped symbol in a `use` line is invisible until
  it fails.
- `use` clauses are per-block and can appear at the top of any block, not
  just at file top.

## 5. Literals, delays, and forcing

- `Nat` literals are bare: `0`, `42`. **`Int` literals require a sign:**
  `+0`, `+7`, `-1`. Writing `0` where an `Int` is expected is a type error;
  this bites constantly in fold accumulators and DB ids. Convert with
  `Nat.toInt` / `Nat.fromInt` (the latter returns `Optional`).
- `Nat` subtraction truncates at zero (`3 - 5 == 0`). Guard comparisons
  before subtracting, or use `Int`.
- `Float` literals need the point: `0.0`. Scientific notation: `1.5e-2`.
- Char literals use `?`: `?a`, `?/`, `?\s` (space), `?\t`. `Text.split`
  takes a `Char`: `Text.split ?/ path`.
- Delayed computations: `'expr` delays, `do ...` is a delayed block, and a
  delayed thing has type `'{g} a`. Force with juxtaposed unit: `thunk()`.
  `main : '{IO, Exception} ()` is the standard entry-point shape; a
  function returning `'{IO} ()` is called like `f x ()` — note the trailing
  `()` at call sites, and note that forgetting it silently gives you an
  unforced thunk where the types allow it.
- `Text` is a rope: `++` is cheap, including in loops. Do not "optimize"
  repeated `Text.++` accumulation; it is already fine.

## 6. Everything is an expression; discards are explicit

There are no statements. A block's value is its last expression. To sequence
a side effect whose result you don't need:

```unison
_ = printLine "step 1"
_ = catch do riskyThing()
finalExpression
```

The `_ =` discard is mandatory; a bare expression mid-block is a parse
error. Sequencing many effects is a stack of `_ =` bindings ending in one
expression. `Function.ignore` exists for discarding inside expressions.

## 7. Abilities, not monads

There is no monad typeclass and no do-notation-for-monads. Effects are
tracked in ability rows on arrows: `Text ->{IO, Exception} Nat`. Key points:

- A pure function is `a -> b`; effectful is `a ->{Abilities} b`. Polymorphic
  effect rows appear as `->{g}` and unify automatically; you rarely write
  them by hand except in signatures you copy.
- `Exception` is an ability. `catch do riskyThing()` gives
  `Either Failure a`. `Exception.raise` throws.
- Custom abilities are interfaces of operations:

```unison
ability Log where
  info : Text ->{Log} ()
```

- Handlers are written with `cases` matching operation requests, where `k`
  is the continuation and `{ r }` is the completion case:

```unison
logGo = cases
  { r }              -> r
  { info msg -> k }  ->
    _ = printLine msg
    handle k() with logGo

result = handle program() with logGo
```

  Note the recursion: each operation case re-wraps the continuation with
  `handle ... with`. Forgetting the `handle k() with logGo` re-wrap handles
  only the first operation.
- This handler pattern is also how you write pure tests for effectful code:
  a "scripted" handler returns canned responses, a "recording" handler
  threads an accumulator through and returns `(result, log)`.

## 8. No typeclasses

- Equality is `Universal.eq a b` (structural, works on almost anything), or
  type-specific operators (`Nat.==`, `Text.==`) via `use`.
- No `Show`: conversion is explicit (`Nat.toText`, `Int.toText`,
  `Float.toText`), and they are different functions per type.
- No `Functor`/`Monad` polymorphism: `Optional.map`, `List.map`,
  `Either`-handling via `match` are all concrete.
- Serialization, ordering, etc. are passed as explicit values (decoder
  thunks, codec values), not derived.

## 9. Records

`type T = { a : Nat, b : Text }` generates, under the type's namespace:
accessor `T.a : T -> Nat`, setter `T.a.set : Nat -> T -> T`, and modifier
`T.a.modify : (Nat -> Nat) -> T -> T`. There is no Haskell-style record
update syntax; chain setters with `|>`:

```unison
m |> T.a.set 5 |> T.b.set "x"
```

Field names commonly collide across types (`.title`, `.name`); disambiguate
with the full path (`Movie.title m` vs `Title.display t`) or `use` clauses.
When you add a field to a record type, every constructor call site must be
re-emitted with the new arity — find them all.

Types reference their field types by hash. If you redefine type `B` and some
type `A` has a field of type `B`, you must re-emit `type A` in the same
scratch file, and so on transitively up the containment chain — otherwise
`A`'s constructor still demands the old `B` and you get an error of the form
"has type: B, but I expected: #somehash". A raw hash appearing in a type
error almost always means this: the old version of a type you just renamed
out from under something that still points at it.

When a scratch file redefines a type that already exists in the codebase,
call its constructor FULLY QUALIFIED (`Config.Tuning.Tuning`, not bare
`Tuning`) at every construction site in the same file. Bare constructor
names resolve by suffix, and with old (codebase) and new (file) versions
both live during typechecking, suffix resolution can bind to the old one —
producing arity errors like "applied to 3 arguments but has type
Nat -> [Text] -> Tuning" even though your new 3-field type is right there
in the file. Wrong-arity constructor errors during a type migration mean
resolution picked the stale version, not that your code is wrong.

## 10. Pattern matching specifics

- `match x with` arms, or `cases` as sugar for a one-argument lambda that
  immediately matches (`List.map (cases (a, b) -> a) pairs`).
- List patterns: `[]`, `x +: rest` (head/tail), `init :+ x` (init/last),
  `[a, b]` (exact). `+:` and `:+` are also the cons/snoc operators in
  expressions — same symbols, both positions.
- Nested tuple destructuring mirrors construction:
  `(((a, b), c), d) -> ...` — DB row decoders produce exactly this
  left-nested shape, and the pattern nesting must match it precisely.
- Constructors of types defined with explicit constructor names pattern-match
  by their full name when ambiguous: `Optional.None` vs a local `None`
  brought in by `use Optional None`.

## 11. Tests are watch expressions

```unison
test> myFn.test =
  use Universal eq
  List.flatMap check
    [ eq (myFn 1) 2
    , eq (myFn 0) 0
    ]
```

`test>` definitions run on file save and are cached by content hash. Failing
branches use `[Fail "message"]`. Effectful code is tested by wrapping it in
scripted handlers (section 7) so the test itself stays pure.

## 12. Miscellaneous traps, rapid fire

- No `where` clauses. Helper bindings go before use, in the function body,
  or at top level.
- Lambda syntax is `x -> body`, not `\x -> body`.
- Recursion in local bindings is fine (`go acc = ... go acc'` then `go []`),
  and is the standard loop idiom.
- `Optional`, not `Maybe`. `Some` / `Optional.None` (bare `None` only after
  `use Optional None`).
- `Boolean`, not `Bool`; `Boolean.not`, `&&`, `||`.
- Doc blocks are `{{ ... }}` with their own markup language; don't guess at
  its syntax, and don't confuse it with Markdown.
- `bug "msg" x` is `error`/`undefined`'s replacement: it aborts with a
  message and a value.
- Prefer emitting a `use` clause over fully qualifying every call, but when
  in doubt, full qualification always parses and always resolves; ambiguity
  errors list the candidates, and the fix is picking one explicitly.

## 13. Pre-emission checklist

Before you output a scratch file, verify each of these against your own
code:

1. Every definition is complete — no elided bodies, no "rest unchanged"
   inside a definition.
2. No binding appears as the first line of an inline lambda. If one does,
   extract a named helper now, not after the parse error.
3. Every operator used bare in a body appears in a `use` clause in scope, or
   is written qualified-infix. Count them.
4. Every `Int` literal has a sign. Every `Float` has a decimal point.
5. Every `if` has an `else`. Every discarded effect has `_ =`.
6. Every delayed function is forced at its call site (`f x ()`), and every
   `'{IO} ()` entry point matches the shape the caller expects.
7. No raw hash references (`#abc...`) anywhere in the file.
8. Handlers re-wrap their continuations (`handle k() with go`).
9. If you changed a record type or a function's arity, you re-emitted every
   caller and every constructor site.
10. Assume the file has more than one error; when the user reports one,
    warn them that fixing it may reveal the next.
