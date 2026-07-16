<!-- unison-causal: #mrrbcfgfmq -->
<!-- unison-prev:   #cq88lr4os1 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #mrrbcfgfmq -->
<!-- generated: 2026-07-16T15:31:37Z -->

# uniDork snapshot `#mrrbcfgfmq`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #cq88lr4os1 #mrrbcfgfmq

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Rename.sweepStaleStaging : Config ->{IO, Exception} ()
        ↓
    4.  Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    5.  Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
        ↓
    6.  Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
    
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
    
    11. sweepStaleStaging : '{IO, Exception} ()
        ↓
    12. sweepStaleStaging : '{IO, Exception} ()
    
    13. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    14. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    15. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    16. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()

  Added definitions:

    17. Rename.sweepStaleStagingChunkSql : postgres.Query
                                           r
                                           (Int ->{g, g1} r)
                                           (Int, Text)

  Removed definitions:

    18. Stage.cacheLoadChunk           : Nat
    19. Stage.cacheRowToPair           : ((Text, Int), Int)
                                       -> (Text, (Int, Int))
    20. Stage.isCachedLocal            : Map Text (Int, Int)
                                       -> Text
                                       -> Int
                                       -> Int
                                       -> Boolean
    21. Stage.loadFreshCache           : Config
                                       ->{IO, Exception} Map
                                         Text (Int, Int)
    22. Stage.partitionWork            : Map Text (Int, Int)
                                       -> [(a, Text)]
                                       ->{IO, Exception} [( Nat,
                                         (a, Text))]
    23. Stage.selectFreshCacheChunkSql : postgres.Query
                                         r
                                         (Text ->{g, g1} r)
                                         ((Text, Int), Int)
    24. Stage.selectFreshCacheSql      : postgres.Query
                                         r r ((Text, Int), Int)

  Name changes:

    Original                         Changes
    25. Stage.smallProbeThreshold    26. Rename.sweepChunkSize (added)
                                     27. Stage.smallProbeThreshold (removed)
```
```
