<!-- unison-causal: #oofgq67o4j -->
<!-- unison-prev:   #2lfv0d8028 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #oofgq67o4j -->
<!-- generated: 2026-07-04T05:38:42Z -->

# uniDork snapshot `#oofgq67o4j`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #2lfv0d8028 #oofgq67o4j

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Move.printProgress : Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
        ↓
    4.  Move.printProgress : Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
    
    5.  Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    6.  Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    7.  Progress.report : Text
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
        ↓
    8.  Progress.report : Text
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
    
    9.  Rename.executeOne : Boolean
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> Optional Text
        -> [Text]
        -> RenameRow
        ->{IO, Exception, RenameCatalog} Rename.Outcome
        ↓
    10. Rename.executeOne : Boolean
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> Optional Text
        -> [Text]
        -> RenameRow
        ->{IO, Exception, RenameCatalog} Rename.Outcome
    
    11. Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    12. Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
    
    13. Rename.runStep : Boolean
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> Optional Text
        -> [Text]
        -> RenameRow
        ->{IO, Exception, RenameCatalog} ()
        ↓
    14. Rename.runStep : Boolean
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> Optional Text
        -> [Text]
        -> RenameRow
        ->{IO, Exception, RenameCatalog} ()
    
    15. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
        ↓
    16. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    17. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
        ↓
    18. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
    
    19. Stage.partitionWork : PreparedQuery r a1 Int
        -> [(a, Text)]
        ->{IO, Postgres} [(Nat, (a, Text))]
        ↓
    20. Stage.partitionWork : PreparedQuery r a1 Int
        -> [(a, Text)]
        ->{IO, Postgres} [(Nat, (a, Text))]
    
    21. Stage.runChunk : Text
        -> PreparedCommand r1 a2
        -> PreparedCommand r a1
        -> [(a, Text)]
        ->{IO, Exception, Postgres} ()
        ↓
    22. Stage.runChunk : Text
        -> PreparedCommand r1 a2
        -> PreparedCommand r a1
        -> [(a, Text)]
        ->{IO, Exception, Postgres} ()
    
    23. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    24. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    25. Stage.runProbeStage : Config ->{IO, Exception} ()
        ↓
    26. Stage.runProbeStage : Config ->{IO, Exception} ()
    
    27. sweepStaleStaging : '{IO, Exception} ()
        ↓
    28. sweepStaleStaging : '{IO, Exception} ()
    
    29. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    30. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    31. Tv.Rename.applyTv : Config
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    32. Tv.Rename.applyTv : Config
        -> Boolean
        -> '{IO, Exception} ()
    
    33. Tv.Rename.executeEpisode : Boolean
        -> PreparedQuery r1 a1 Text
        -> PreparedQuery r a Text
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> [FormatPart]
        -> EpisodeJob
        ->{IO, Exception, Postgres, RenameCatalog} TvRenameOutcome
        ↓
    34. Tv.Rename.executeEpisode : Boolean
        -> PreparedQuery r1 a1 Text
        -> PreparedQuery r a Text
        -> Text
        -> Text
        -> [FormatPart]
        -> [FormatPart]
        -> [FormatPart]
        -> EpisodeJob
        ->{IO, Exception, Postgres, RenameCatalog} TvRenameOutcome
    
    35. Tv.Stage.runChunk : Text
        -> Text
        -> PreparedCommand r1 a1
        -> PreparedCommand r a
        -> [((), Text)]
        ->{IO, Exception, Postgres} ()
        ↓
    36. Tv.Stage.runChunk : Text
        -> Text
        -> PreparedCommand r1 a1
        -> PreparedCommand r a
        -> [((), Text)]
        ->{IO, Exception, Postgres} ()
    
    37. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    38. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    39. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    40. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
    
    41. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
        ↓
    42. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
    
    43. uniDork.batchedRun : Config ->{IO, Exception} ()
        ↓
    44. uniDork.batchedRun : Config ->{IO, Exception} ()
    
    45. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
        ↓
    46. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    47. uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    48. uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
    
    49. uniDork.runBatchSafe : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
        ↓
    50. uniDork.runBatchSafe : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()

  Added definitions:

    51. Rename.cleanOrphanCacheSql : Command a a
    52. Stage.effectiveMtime       : Text -> Int ->{IO} Int
    53. Rename.firstSizeMatch      : FilePath
                                   -> Nat
                                   -> [Text]
                                   ->{IO} Optional Text
    54. Stage.newestNfoMtime       : Text ->{IO} Int
    55. kernel.mem.rssMb           : '{IO} Nat
```
```
