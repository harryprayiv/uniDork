<!-- unison-causal: #n9eiqd2sku -->
<!-- unison-prev:   #e28pdd7s1v -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #n9eiqd2sku -->
<!-- generated: 2026-07-06T01:30:11Z -->

# uniDork snapshot `#n9eiqd2sku`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #e28pdd7s1v #n9eiqd2sku

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
        ↓
    4.  Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
    
    5.  Tv.Resolve.identify : Config ->{IO, Exception} ()
        ↓
    6.  Tv.Resolve.identify : Config ->{IO, Exception} ()
    
    7.  Tv.Resolve.run : Config ->{IO, Exception} ()
        ↓
    8.  Tv.Resolve.run : Config ->{IO, Exception} ()
    
    9.  Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
        ↓
    10. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()

  Added definitions:

    11. Resolve.resolveChunkSize              : Nat
    12. Resolve.selectUnresolvedChunkSql      : postgres.Query
                                                r
                                                (Int
                                                ->{g, g1} r)
                                                ( ( ( ( ( Int,
                                                  Text),
                                                  Float),
                                                  Optional Text),
                                                  Optional Int),
                                                  Optional Int)
    13. Tv.Resolve.selectUnresolvedTvChunkSql : postgres.Query
                                                r
                                                (Int
                                                ->{g, g1} r)
                                                ( ( ( ( ( ( Int,
                                                  Text),
                                                  Optional Text),
                                                  Optional Int),
                                                  Optional Int),
                                                  Optional Text),
                                                  Text)
```
```
