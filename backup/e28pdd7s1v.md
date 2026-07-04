<!-- unison-causal: #e28pdd7s1v -->
<!-- unison-prev:   #1938au52p0 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #e28pdd7s1v -->
<!-- generated: 2026-07-04T14:10:18Z -->

# uniDork snapshot `#e28pdd7s1v`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #1938au52p0 #e28pdd7s1v

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Stage.partitionWork : PreparedQuery r a1 Int
        -> [(a, Text)]
        ->{IO, Postgres} [(Nat, (a, Text))]
        ↓
    4.  Stage.partitionWork : Map Text (Int, Int)
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
    
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
    
    9.  Stage.sortBySize : [(Nat, a)] -> [(Nat, a)]
        ↓
    10. Stage.sortBySize : [(Nat, (a, Text))]
        -> [(Nat, (a, Text))]
    
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

  Added definitions:

    15. Stage.cacheRowToPair      : ((Text, Int), Int)
                                  -> (Text, (Int, Int))
    16. Stage.isCachedLocal       : Map Text (Int, Int)
                                  -> Text
                                  -> Int
                                  -> Int
                                  -> Boolean
    17. Stage.loadFreshCache      : Config
                                  ->{IO, Exception} Map
                                    Text (Int, Int)
    18. Stage.probeConnChunks     : Nat
    19. Stage.selectFreshCacheSql : postgres.Query
                                    r r ((Text, Int), Int)
```
```
