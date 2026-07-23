<!-- unison-causal: #vt0uo5tfa6 -->
<!-- unison-prev:   #rgr2h9r91d -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #vt0uo5tfa6 -->
<!-- generated: 2026-07-23T17:06:49Z -->

# uniDork snapshot `#vt0uo5tfa6`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #rgr2h9r91d #vt0uo5tfa6

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Versions.run : Config ->{IO, Exception} ()
        ↓
    4.  Versions.run : Config ->{IO, Exception} ()
    
    5.  versionsRun : '{IO, Exception} ()
        ↓
    6.  versionsRun : '{IO, Exception} ()

  Added definitions:

    7.  type Versions.StampRow
    8.  Versions.StampRow.StampRow              : Text
                                                -> Text
                                                -> Text
                                                -> Text
                                                -> Boolean
                                                -> StampRow
    9.  Versions.Stamp.applyStamp               : Optional
                                                  ( Text,
                                                    Boolean)
                                                -> Text
                                                -> Text
    10. Versions.clearAll                       : Config
                                                ->{IO,
                                                Exception} ()
    11. Versions.Stamp.countEqText              : Text
                                                -> [Text]
                                                -> Nat
    12. Versions.StampRow.editionLabel          : StampRow
                                                -> Text
    13. Versions.fetchMultiTmdbs                : Config
                                                ->{IO,
                                                Exception} [Text]
    14. Versions.StampRow.folderChecksum        : StampRow
                                                -> Text
    15. Versions.Stamp.groupBy                  : (a ->{g} Text)
                                                -> [a]
                                                ->{g} [( Text,
                                                  [a])]
    16. Versions.Stamp.insertBeforeClose        : [Text]
                                                -> [Text]
                                                -> [Text]
    17. Versions.StampRow.isDefault             : StampRow
                                                -> Boolean
    18. Versions.Stamp.isStampLine              : Text
                                                -> Boolean
    19. Versions.Stamp.kodiLabelsForGroup       : [StampRow]
                                                -> [( Text,
                                                  ( Text,
                                                  Boolean))]
    20. Versions.Stamp.labelEdition             : Boolean
                                                -> ( Text,
                                                  [StampRow])
                                                -> [( Text,
                                                  ( Text,
                                                  Boolean))]
    21. Versions.Stamp.labelMember              : Boolean
                                                -> Text
                                                -> [Text]
                                                -> Boolean
                                                -> StampRow
                                                -> ( Text,
                                                  ( Text,
                                                  Boolean))
    22. Versions.Stamp.labelsForPair            : ( Text,
                                                  [StampRow])
                                                -> [( Text,
                                                  ( Text,
                                                  Boolean))]
    23. Versions.loadDesired                    : Config
                                                ->{IO,
                                                Exception} [( Text,
                                                  ( Text,
                                                  Boolean))]
    24. Versions.Stamp.lookupCk                 : Text
                                                -> [( Text,
                                                  ( Text,
                                                  Boolean))]
                                                -> Optional
                                                  ( Text,
                                                    Boolean)
    25. Versions.StampRow.editionLabel.modify   : (Text
                                                ->{g} Text)
                                                -> StampRow
                                                ->{g} StampRow
    26. Versions.StampRow.folderChecksum.modify : (Text
                                                ->{g} Text)
                                                -> StampRow
                                                ->{g} StampRow
    27. Versions.StampRow.isDefault.modify      : (Boolean
                                                ->{g} Boolean)
                                                -> StampRow
                                                ->{g} StampRow
    28. Versions.StampRow.tmdbId.modify         : (Text
                                                ->{g} Text)
                                                -> StampRow
                                                ->{g} StampRow
    29. Versions.StampRow.versionLabel.modify   : (Text
                                                ->{g} Text)
                                                -> StampRow
                                                ->{g} StampRow
    30. Versions.Stamp.patchOne                 : Boolean
                                                -> [( Text,
                                                  ( Text,
                                                  Boolean))]
                                                -> Nat
                                                -> (Text, Text)
                                                ->{IO,
                                                Exception} Nat
    31. Versions.Stamp.patchText                : Boolean
                                                -> Optional
                                                  ( Text,
                                                    Boolean)
                                                -> Text
                                                -> Text
                                                -> Nat
                                                ->{IO,
                                                Exception} Nat
    32. Versions.rowToStampRow                  : ( ( ( ( Text,
                                                  Text),
                                                  Text),
                                                  Text),
                                                  Int)
                                                -> StampRow
    33. Versions.runGroupChunk                  : Config
                                                -> [Text]
                                                ->{IO,
                                                Exception} ()
    34. Versions.selectNfoChunkSql              : postgres.Query
                                                  b
                                                  (Text -> b)
                                                  (Text, Text)
    35. Versions.selectStampRowsSql             : postgres.Query
                                                  r
                                                  r
                                                  ( ( ( ( Text,
                                                    Text),
                                                    Text),
                                                    Text),
                                                    Int)
    36. Versions.StampRow.editionLabel.set      : Text
                                                -> StampRow
                                                -> StampRow
    37. Versions.StampRow.folderChecksum.set    : Text
                                                -> StampRow
                                                -> StampRow
    38. Versions.StampRow.isDefault.set         : Boolean
                                                -> StampRow
                                                -> StampRow
    39. Versions.StampRow.tmdbId.set            : Text
                                                -> StampRow
                                                -> StampRow
    40. Versions.StampRow.versionLabel.set      : Text
                                                -> StampRow
                                                -> StampRow
    41. Versions.Stamp.skipMissing              : Optional
                                                  ( Text,
                                                    Boolean)
                                                -> Text
                                                -> Nat
                                                ->{IO,
                                                Exception} Nat
    42. Versions.stampChunk                     : Nat
    43. Versions.Stamp.stampLines               : Text
                                                -> Boolean
                                                -> [Text]
    44. Versions.stampNfos                      : Config
                                                -> Boolean
                                                ->{IO,
                                                Exception} ()
    45. Versions.stripCrcSuffix                 : Text -> Text
    46. Versions.Stamp.applyStamp.test          : [test.Result]
    47. Versions.Stamp.kodiLabelsForGroup.test  : [test.Result]
    48. Versions.stripCrcSuffix.test            : [test.Result]
    49. Versions.StampRow.tmdbId                : StampRow
                                                -> Text
    50. Versions.Stamp.upsert                   : Text
                                                -> a
                                                -> [(Text, [a])]
                                                -> [(Text, [a])]
    51. Versions.StampRow.versionLabel          : StampRow
                                                -> Text
    52. Versions.writeGroup                     : PreparedQuery
                                                  r1
                                                  a1
                                                  ( ( ( ( Text,
                                                    Text),
                                                    Int),
                                                    Text),
                                                    Text)
                                                -> PreparedQuery
                                                  r a Int
                                                -> PreparedQuery
                                                  rE aE Int
                                                -> PreparedCommand
                                                  rV aV
                                                -> Text
                                                ->{IO,
                                                Exception,
                                                Postgres} ()

  Name changes:

    Original                                                                                                              Changes
    53. lib.alvaroc1_jwt_0_0_1.lib.base.math.Natural.internal.bitWidth                                                 ┐  54. Versions.sessionGroups (added)
    55. lib.base.math.Natural.Deprecated.internal.bitWidth                                                             │  
    56. lib.html_2_2_0.lib.base_2_9_1.math.Natural.internal.bitWidth                                                   │  
    57. lib.unison_base_7_12_1.math.Natural.Deprecated.internal.bitWidth                                               │  
    58. lib.unison_blog_engine_2_1_2.lib.shareSdk_2_7_0.lib.svg_1_0_0.lib.file.lib.base.math.Natural.internal.bitWidth │  
    59. lib.unison_blog_engine_2_1_2.lib.unison_base_3_21_0.math.Natural.internal.bitWidth                             ┘  
```
```
