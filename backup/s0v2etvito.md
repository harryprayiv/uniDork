<!-- unison-causal: #s0v2etvito -->
<!-- unison-prev:   #n9eiqd2sku -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #s0v2etvito -->
<!-- generated: 2026-07-16T14:51:53Z -->

# uniDork snapshot `#s0v2etvito`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #n9eiqd2sku #s0v2etvito

  Updates:

    1. cli : '{IO, Exception} ()
       ↓
    2. cli : '{IO, Exception} ()
    
    3. Tv.Rename.applyTv : Config
       -> Boolean
       -> '{IO, Exception} ()
       ↓
    4. Tv.Rename.applyTv : Config
       -> Boolean
       -> '{IO, Exception} ()
    
    5. Tv.Rename.executeEpisode : Boolean
       -> PreparedQuery r1 a1 Text
       -> PreparedQuery r a Text
       -> Text
       -> Text
       -> [FormatPart]
       -> [FormatPart]
       -> [FormatPart]
       -> [Text]
       -> EpisodeJob
       ->{IO, Exception, Postgres, RenameCatalog} TvRenameOutcome
       ↓
    6. Tv.Rename.executeEpisode : Boolean
       -> Map Text Text
       -> Map Text Season
       -> Text
       -> Text
       -> [FormatPart]
       -> [FormatPart]
       -> [FormatPart]
       -> [Text]
       -> EpisodeJob
       ->{IO, Exception, RenameCatalog} TvRenameOutcome

  Added definitions:

    7. Tv.Rename.chunkSeasons  : PreparedQuery r a Text
                               -> [EpisodeJob]
                               ->{Postgres} Map Text Season
    8. Tv.Rename.chunkShowNfos : PreparedQuery r a Text
                               -> [EpisodeJob]
                               ->{Postgres} Map Text Text
    9. Tv.Rename.seasonKey     : Nat -> Nat -> Text
```
```
