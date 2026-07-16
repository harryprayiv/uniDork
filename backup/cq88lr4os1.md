<!-- unison-causal: #cq88lr4os1 -->
<!-- unison-prev:   #s0v2etvito -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #cq88lr4os1 -->
<!-- generated: 2026-07-16T15:04:48Z -->

# uniDork snapshot `#cq88lr4os1`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #s0v2etvito #cq88lr4os1

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Stage.loadFreshCache : Config
        ->{IO, Exception} Map Text (Int, Int)
        ↓
    4.  Stage.loadFreshCache : Config
        ->{IO, Exception} Map Text (Int, Int)
    
    5.  Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    6.  Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    7.  Stage.runProbeStage : Config ->{IO, Exception} ()
        ↓
    8.  Stage.runProbeStage : Config ->{IO, Exception} ()
    
    9.  Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    10. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    11. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    12. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()

  Added definitions:

    13. Stage.cacheLoadChunk           : Nat
    14. Stage.partitionWorkDb          : Config
                                       -> [(a, Text)]
                                       ->{IO, Exception} [( Nat,
                                         (a, Text))]
    15. Stage.selectFreshCacheChunkSql : postgres.Query
                                         r
                                         (Text ->{g, g1} r)
                                         ((Text, Int), Int)
    16. Stage.smallProbeThreshold      : Nat
```
```
