<!-- unison-causal: #222bvrknv9 -->
<!-- unison-prev:   #34gist1fl1 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #222bvrknv9 -->
<!-- generated: 2026-07-04T01:43:01Z -->

# uniDork snapshot `#222bvrknv9`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #34gist1fl1 #222bvrknv9

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Stage.partitionWork : PreparedQuery r a1 Int
        -> [(a, Text)]
        ->{IO, Postgres} [(Nat, (a, Text))]
        ↓
    4.  Stage.partitionWork : PreparedQuery r a1 Int
        -> [(a, Text)]
        ->{IO, Postgres} [(Nat, (a, Text))]
    
    5.  Stage.probeCacheFreshSql : postgres.Query
          a (Text ->{g4, g5} Int ->{g2, g3} Int ->{g, g1} a) Int
        ↓
    6.  Stage.probeCacheFreshSql : postgres.Query
          a (Text ->{g4, g5} Int ->{g2, g3} Int ->{g, g1} a) Int
    
    7.  Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    8.  Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    9.  Stage.runProbeStage : Config ->{IO, Exception} ()
        ↓
    10. Stage.runProbeStage : Config ->{IO, Exception} ()
    
    11. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    12. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    13. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    14. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
```
```
