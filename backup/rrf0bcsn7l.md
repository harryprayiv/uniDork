<!-- unison-causal: #rrf0bcsn7l -->
<!-- unison-prev:   #3qbcqiqsgt -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #rrf0bcsn7l -->
<!-- generated: 2026-07-24T15:54:17Z -->

# uniDork snapshot `#rrf0bcsn7l`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #3qbcqiqsgt #rrf0bcsn7l

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
    
    11. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
        ↓
    12. Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    13. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
        ↓
    14. Resolve.runWith : Boolean -> Config ->{IO, Exception} ()
    
    15. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
        ↓
    16. Stage.partitionWorkDb : Config
        -> [(a, Text)]
        ->{IO, Exception} [(Nat, (a, Text))]
    
    17. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    18. Stage.runProbeAt : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    19. Stage.runProbeStage : Config ->{IO, Exception} ()
        ↓
    20. Stage.runProbeStage : Config ->{IO, Exception} ()
    
    21. Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
        ↓
    22. Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
    
    23. sweepStaleStaging : '{IO, Exception} ()
        ↓
    24. sweepStaleStaging : '{IO, Exception} ()
    
    25. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
        ↓
    26. Tv.Move.run : Config
        -> Optional Text
        -> Boolean
        ->{IO, Exception} ()
    
    27. Tv.Resolve.identify : Config ->{IO, Exception} ()
        ↓
    28. Tv.Resolve.identify : Config ->{IO, Exception} ()
    
    29. Tv.Resolve.run : Config ->{IO, Exception} ()
        ↓
    30. Tv.Resolve.run : Config ->{IO, Exception} ()
    
    31. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
        ↓
    32. Tv.Resolve.runWith : Boolean
        -> Config
        ->{IO, Exception} ()
    
    33. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
        ↓
    34. Tv.Stage.runProbeAtTv : Config
        -> Text
        -> Text
        ->{IO, Exception} ()
    
    35. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
        ↓
    36. Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
    
    37. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
        ↓
    38. uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
    
    39. uniDork.batchedRun : Config ->{IO, Exception} ()
        ↓
    40. uniDork.batchedRun : Config ->{IO, Exception} ()
    
    41. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
        ↓
    42. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    43. uniDork.runBatchSafe : Config
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
    44. uniDork.runBatchSafe : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    45. Versions.run : Config ->{IO, Exception} ()
        ↓
    46. Versions.run : Config ->{IO, Exception} ()
    
    47. Versions.sessionGroups : Nat
        ↓
    48. Versions.sessionGroups : Nat
    
    49. Versions.stampNfos : Config
        -> Boolean
        ->{IO, Exception} ()
        ↓
    50. Versions.stampNfos : Config
        -> Boolean
        ->{IO, Exception} ()
    
    51. versionsRun : '{IO, Exception} ()
        ↓
    52. versionsRun : '{IO, Exception} ()

  Added definitions:

    53. Art.bannerEntryFromJson   : '{unison_json_1_3_5.Decoder} ( Text,
                                    Text)
    54. Art.bannerOne             : Boolean
                                  -> Text
                                  -> Optional Text
                                  -> [(Text, Text)]
                                  -> ( (Nat, Nat, Nat),
                                    [(Text, Text)])
                                  -> (Text, Nat)
                                  ->{IO, Exception} ( ( Nat,
                                    Nat,
                                    Nat),
                                    [(Text, Text)])
    55. Art.bannersFromJson       : '{unison_json_1_3_5.Decoder} [( Text,
                                    Text)]
    56. Art.curlJson              : [Text]
                                  -> Text
                                  ->{IO, Exception} Either
                                    Text Text
    57. Art.curlToFile            : Text
                                  -> Text
                                  ->{IO, Exception} Either
                                    Text ()
    58. Art.extractNfoTmdbId      : Text -> Optional Nat
    59. Art.healTvdb              : Config
                                  -> [(Text, Text)]
                                  ->{IO, Exception} ()
    60. Art.loadShowsMeta         : Config
                                  ->{IO, Exception} [( Text,
                                    Text)]
    61. Art.lookupText            : Text
                                  -> [(Text, Text)]
                                  -> Optional Text
    62. Art.movieChunk            : Config
                                  -> Text
                                  ->{IO, Exception} [( ( ( Text,
                                    Text),
                                    Text),
                                    Text)]
    63. Art.movieChunkSql         : postgres.Query
                                    b
                                    (Text -> b)
                                    (((Text, Text), Text), Text)
    64. Art.movieOne              : Boolean
                                  -> Optional Text
                                  -> (Nat, Nat, Nat)
                                  -> ( ((Text, Text), Text),
                                    Text)
                                  ->{IO, Exception} ( Nat,
                                    Nat,
                                    Nat)
    65. Art.movies                : Config
                                  -> Boolean
                                  ->{IO, Exception} ()
    66. Art.pickBanner            : Text -> Optional Text
    67. Art.posterFromJson        : '{unison_json_1_3_5.Decoder} Optional
                                    Text
    68. Art.posterOf              : Text -> Optional Text
    69. Art.readFanartToken       : '{IO, Exception} Optional
                                    Text
    70. Art.resolvePoster         : Optional Text
                                  -> Text
                                  -> Text
                                  ->{IO, Exception} Optional
                                    Text
    71. Art.showRoots             : Config
                                  ->{IO, Exception} [(Text, Nat)]
    72. Art.showsMetaSql          : postgres.Query
                                    r r (Text, Text)
    73. Art.extractNfoTmdbId.test : [test.Result]
    74. Art.posterOf.test         : [test.Result]
    75. Art.tvBanners             : Config
                                  -> Boolean
                                  ->{IO, Exception} ()
    76. Art.tvdbFor               : Optional Text
                                  -> [(Text, Text)]
                                  -> Nat
                                  ->{IO, Exception} Optional
                                    Text
    77. Art.tvdbFromJson          : '{unison_json_1_3_5.Decoder} Optional
                                    Nat
    78. Art.updateShowTvdbSql     : Command
                                    a (Text -> Text -> a)

  Name changes:

    Original                                                                                                              Changes
    79. lib.alvaroc1_jwt_0_0_1.lib.base.math.Natural.internal.bitWidth                                                 ┐  80. Versions.sessionGroups (added)
    81. lib.base.math.Natural.Deprecated.internal.bitWidth                                                             │  
    82. lib.html_2_2_0.lib.base_2_9_1.math.Natural.internal.bitWidth                                                   │  
    83. lib.unison_base_7_12_1.math.Natural.Deprecated.internal.bitWidth                                               │  
    84. lib.unison_blog_engine_2_1_2.lib.shareSdk_2_7_0.lib.svg_1_0_0.lib.file.lib.base.math.Natural.internal.bitWidth │  
    85. lib.unison_blog_engine_2_1_2.lib.unison_base_3_21_0.math.Natural.internal.bitWidth                             ┘  
    
    86. Versions.sessionSettleMicros                                                                                      87. Art.throttleMicros (added)
    
    88. Versions.stampChunk                                                                                               89. Art.chunkRows (added)
```
```
