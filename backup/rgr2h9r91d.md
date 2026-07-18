<!-- unison-causal: #rgr2h9r91d -->
<!-- unison-prev:   #i56mao3afh -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #rgr2h9r91d -->
<!-- generated: 2026-07-18T22:17:51Z -->

# uniDork snapshot `#rgr2h9r91d`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #i56mao3afh #rgr2h9r91d

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Db.createSchema : Config ->{IO, Exception} ()
        ↓
    4.  Db.createSchema : Config ->{IO, Exception} ()
    
    5.  Db.migrate : Config ->{IO, Exception} ()
        ↓
    6.  Db.migrate : Config ->{IO, Exception} ()
    
    7.  Db.resetSchema : Config ->{IO, Exception} ()
        ↓
    8.  Db.resetSchema : Config ->{IO, Exception} ()
    
    9.  initDb : '{IO, Exception} ()
        ↓
    10. initDb : '{IO, Exception} ()
    
    11. mig : '{IO, Exception} ()
        ↓
    12. mig : '{IO, Exception} ()
    
    13. Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    14. Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    15. myPg.singleIO : PostgresClientConfig
        -> '{g, IO, Exception, Postgres} a
        ->{g, IO, Exception} a
        ↓
    16. myPg.singleIO : PostgresClientConfig
        -> '{g, IO, Exception, Postgres} a
        ->{g, IO, Exception} a
    
    17. Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    18. Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
    
    19. Rename.sweepMissing : Config ->{IO, Exception} ()
        ↓
    20. Rename.sweepMissing : Config ->{IO, Exception} ()
    
    21. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
        ↓
    22. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    23. resetDb : '{IO, Exception} ()
        ↓
    24. resetDb : '{IO, Exception} ()
    
    25. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
        ↓
    26. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
    
    27. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
        ↓
    28. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
    
    29. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    30. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    31. Stage.runProbeStage : Config ->{IO, Exception} ()
        ↓
    32. Stage.runProbeStage : Config ->{IO, Exception} ()
    
    33. Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
        ↓
    34. Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
    
    35. sweepMissing : '{IO, Exception} ()
        ↓
    36. sweepMissing : '{IO, Exception} ()
    
    37. sweepStaleStaging : '{IO, Exception} ()
        ↓
    38. sweepStaleStaging : '{IO, Exception} ()
    
    39. Tv.Db.createSchema : Config ->{IO, Exception} ()
        ↓
    40. Tv.Db.createSchema : Config ->{IO, Exception} ()
    
    41. Tv.Db.resetTvSchema : Config ->{IO, Exception} ()
        ↓
    42. Tv.Db.resetTvSchema : Config ->{IO, Exception} ()
    
    43. Tv.initDb : '{IO, Exception} ()
        ↓
    44. Tv.initDb : '{IO, Exception} ()
    
    45. Tv.Move.moveShow : Boolean
        -> Text
        -> FilePath
        ->{IO, Exception, TvMoveCatalog} ()
        ↓
    46. Tv.Move.moveShow : Config
        -> Boolean
        -> Text
        -> FilePath
        ->{IO, Exception} ()
    
    47. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    48. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    49. Tv.Rename.applyTv : Config
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    50. Tv.Rename.applyTv : Config
        -> Boolean
        -> '{IO, Exception} ()
    
    51. Tv.Resolve.identify : Config ->{IO, Exception} ()
        ↓
    52. Tv.Resolve.identify : Config ->{IO, Exception} ()
    
    53. Tv.Resolve.run : Config ->{IO, Exception} ()
        ↓
    54. Tv.Resolve.run : Config ->{IO, Exception} ()
    
    55. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
        ↓
    56. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
    
    57. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    58. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    59. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    60. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
    
    61. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
        ↓
    62. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
    
    63. uniDork.batchedRun : Config ->{IO, Exception} ()
        ↓
    64. uniDork.batchedRun : Config ->{IO, Exception} ()
    
    65. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
        ↓
    66. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    67. uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    68. uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
    
    69. uniDork.runBatchSafe : Config
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
    70. uniDork.runBatchSafe : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    71. Versions.run : Config ->{IO, Exception} ()
        ↓
    72. Versions.run : Config ->{IO, Exception} ()
    
    73. versionsRun : '{IO, Exception} ()
        ↓
    74. versionsRun : '{IO, Exception} ()

  Added definitions:

    75. Tv.Move.withCatalog : Config
                            -> '{IO, Exception, TvMoveCatalog} a
                            ->{IO, Exception} a
```
```
