<!-- unison-causal: #0hprtfpdom -->
<!-- unison-prev:   #mrrbcfgfmq -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #0hprtfpdom -->
<!-- generated: 2026-07-17T13:46:21Z -->

# uniDork snapshot `#0hprtfpdom`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #mrrbcfgfmq #0hprtfpdom

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  kernel.mem.rssMb : '{IO} Nat
        ↓
    4.  kernel.mem.rssMb : '{IO} Nat
    
    5.  Move.printProgress : Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
        ↓
    6.  Move.printProgress : Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
    
    7.  Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    8.  Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    9.  Progress.report : Text
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
        ↓
    10. Progress.report : Text
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref g (Nat, Nat)
        ->{g, IO, Exception} ()
    
    11. Rename.sweepChunkSize : Nat
        ↓
    12. Rename.sweepChunkSize : Nat
    
    13. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
        ↓
    14. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    15. Rename.sweepStaleStagingChunkSql : postgres.Query
          r (Int ->{g, g1} r) (Int, Text)
        ↓
    16. Rename.sweepStaleStagingChunkSql : postgres.Query
          r (Int ->{g, g1} r) (Int, Text)
    
    17. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
        ↓
    18. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
    
    19. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
        ↓
    20. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
    
    21. Stage.probeConnChunks : Nat
        ↓
    22. Stage.probeConnChunks : Nat
    
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
    
    31. Tv.Resolve.identify : Config ->{IO, Exception} ()
        ↓
    32. Tv.Resolve.identify : Config ->{IO, Exception} ()
    
    33. Tv.Resolve.run : Config ->{IO, Exception} ()
        ↓
    34. Tv.Resolve.run : Config ->{IO, Exception} ()
    
    35. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
        ↓
    36. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
    
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
    
    47. uniDork.runBatchSafe : Config
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
    48. uniDork.runBatchSafe : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()

  Name changes:

    Original                                                      Changes
    49. lib.unison_auth_2_0_1.lib.uuid_1_0_1.UUID.Version.size ┐  50. Stage.probeConnChunks (added)
    51. Tv.Stage.maxDepth                                      ┘  
    
    52. Resolve.resolveChunkSize                                  53. Stage.partitionSessionSize (added)
```
```
