<!-- unison-causal: #hv0abt7cia -->
<!-- unison-prev:   #oimbcad67v -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #hv0abt7cia -->
<!-- generated: 2026-07-27T07:20:10Z -->

# uniDork snapshot `#hv0abt7cia`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #oimbcad67v #hv0abt7cia

  Updates:

    1.  Art.ensureSchema : Config ->{IO, Exception} ()
        ↓
    2.  Art.ensureSchema : Config ->{IO, Exception} ()
    
    3.  Art.movieChunk : Config
        -> Text
        ->{IO, Exception} [(((Text, Text), Text), Text)]
        ↓
    4.  Art.movieChunk : Config
        -> Text
        -> Text
        ->{IO, Exception} [(((Text, Text), Text), Text)]
    
    5.  Art.movieChunkSql : postgres.Query
          b (Text -> b) (((Text, Text), Text), Text)
        ↓
    6.  Art.movieChunkSql : postgres.Query
          b (Text -> Text -> b) (((Text, Text), Text), Text)
    
    7.  Art.movies : Config -> Boolean ->{IO, Exception} ()
        ↓
    8.  Art.movies : Config -> Boolean ->{IO, Exception} ()
    
    9.  Art.tvBanners : Config -> Boolean ->{IO, Exception} ()
        ↓
    10. Art.tvBanners : Config -> Boolean ->{IO, Exception} ()
    
    11. cli : '{IO, Exception} ()
        ↓
    12. cli : '{IO, Exception} ()

  Added definitions:

    13. Art.applyScan     : Config
                          -> ( [(Text, Text, Text, Text)],
                            [(Text, Text, Text)])
                          ->{IO, Exception} ()
    14. Art.deleteArtSql  : Command
                            a (Text -> Text -> Text -> a)
    15. Art.insertScanSql : Command
                            b
                            (Text -> Text -> Text -> Text -> b)
    16. Art.scanAll       : Config ->{IO, Exception} ()
    17. Art.scanChunk     : Config
                          -> Text
                          -> Text
                          ->{IO, Exception} [(Text, Text)]
    18. Art.scanChunkSql  : postgres.Query
                            b (Text -> Text -> b) (Text, Text)
    19. Art.scanItem      : Text
                          -> [Text]
                          -> ( [(Text, Text, Text, Text)],
                            [(Text, Text, Text)])
                          -> (Text, Text)
                          ->{IO, Exception} ( [( Text,
                            Text,
                            Text,
                            Text)],
                            [(Text, Text, Text)])
    20. Art.scanMovies    : Config ->{IO, Exception} Nat
    21. Art.scanTv        : Config ->{IO, Exception} Nat
```
```
