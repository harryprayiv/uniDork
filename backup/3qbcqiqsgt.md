<!-- unison-causal: #3qbcqiqsgt -->
<!-- unison-prev:   #vt0uo5tfa6 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #3qbcqiqsgt -->
<!-- generated: 2026-07-23T17:19:32Z -->

# uniDork snapshot `#3qbcqiqsgt`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #vt0uo5tfa6 #3qbcqiqsgt

  Updates:

    1.   cli : '{IO, Exception} ()
         ↓
    2.   cli : '{IO, Exception} ()
    
    3.   Db.createSchema : Config ->{IO, Exception} ()
         ↓
    4.   Db.createSchema : Config ->{IO, Exception} ()
    
    5.   Db.migrate : Config ->{IO, Exception} ()
         ↓
    6.   Db.migrate : Config ->{IO, Exception} ()
    
    7.   Db.resetSchema : Config ->{IO, Exception} ()
         ↓
    8.   Db.resetSchema : Config ->{IO, Exception} ()
    
    9.   initDb : '{IO, Exception} ()
         ↓
    10.  initDb : '{IO, Exception} ()
    
    11.  mig : '{IO, Exception} ()
         ↓
    12.  mig : '{IO, Exception} ()
    
    13.  Move.run : Config
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
         ↓
    14.  Move.run : Config
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
    
    15.  myPg.runIO : net.Connection {IO, Exception}
         -> Map Text Text
         -> '{h, IO, Exception, PostgresMessaging} a
         ->{h, IO, Exception} a
         ↓
    16.  myPg.runIO : net.Connection {IO, Exception}
         -> Map Text Text
         -> '{h, IO, Exception, PostgresMessaging} a
         ->{h, IO, Exception} a
    
    17.  myPg.singleIO : PostgresClientConfig
         -> '{g, IO, Exception, Postgres} a
         ->{g, IO, Exception} a
         ↓
    18.  myPg.singleIO : PostgresClientConfig
         -> '{g, IO, Exception, Postgres} a
         ->{g, IO, Exception} a
    
    19.  myPg.withConnection : PostgresClientConfig
         -> net.Connection {IO, Exception}
         -> '{g, IO, Exception, Postgres} a
         ->{g, IO, Exception} a
         ↓
    20.  myPg.withConnection : PostgresClientConfig
         -> net.Connection {IO, Exception}
         -> '{g, IO, Exception, Postgres} a
         ->{g, IO, Exception} a
    
    21.  Rename.runNew : Config
         -> Text
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    22.  Rename.runNew : Config
         -> Text
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
    
    23.  Rename.sweepMissing : Config ->{IO, Exception} ()
         ↓
    24.  Rename.sweepMissing : Config ->{IO, Exception} ()
    
    25.  Rename.sweepStaleStaging : Config ->{IO, Exception} ()
         ↓
    26.  Rename.sweepStaleStaging : Config ->{IO, Exception} ()
    
    27.  resetDb : '{IO, Exception} ()
         ↓
    28.  resetDb : '{IO, Exception} ()
    
    29.  Resolve.runWith : Boolean
         -> Config
         ->{IO, Exception} ()
         ↓
    30.  Resolve.runWith : Boolean
         -> Config
         ->{IO, Exception} ()
    
    31.  Stage.partitionWorkDb : Config
         -> [(a, Text)]
         ->{IO, Exception} [(Nat, (a, Text))]
         ↓
    32.  Stage.partitionWorkDb : Config
         -> [(a, Text)]
         ->{IO, Exception} [(Nat, (a, Text))]
    
    33.  Stage.runProbeAt : Config
         -> Text
         -> Text
         ->{IO, Exception} ()
         ↓
    34.  Stage.runProbeAt : Config
         -> Text
         -> Text
         ->{IO, Exception} ()
    
    35.  Stage.runProbeStage : Config ->{IO, Exception} ()
         ↓
    36.  Stage.runProbeStage : Config ->{IO, Exception} ()
    
    37.  Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
         ↓
    38.  Subs.Fix.run : Config -> Boolean ->{IO, Exception} ()
    
    39.  sweepMissing : '{IO, Exception} ()
         ↓
    40.  sweepMissing : '{IO, Exception} ()
    
    41.  sweepStaleStaging : '{IO, Exception} ()
         ↓
    42.  sweepStaleStaging : '{IO, Exception} ()
    
    43.  Tv.Db.createSchema : Config ->{IO, Exception} ()
         ↓
    44.  Tv.Db.createSchema : Config ->{IO, Exception} ()
    
    45.  Tv.Db.resetTvSchema : Config ->{IO, Exception} ()
         ↓
    46.  Tv.Db.resetTvSchema : Config ->{IO, Exception} ()
    
    47.  Tv.initDb : '{IO, Exception} ()
         ↓
    48.  Tv.initDb : '{IO, Exception} ()
    
    49.  Tv.Move.moveShow : Config
         -> Boolean
         -> Text
         -> FilePath
         ->{IO, Exception} ()
         ↓
    50.  Tv.Move.moveShow : Config
         -> Boolean
         -> Text
         -> FilePath
         ->{IO, Exception} ()
    
    51.  Tv.Move.run : Config
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
         ↓
    52.  Tv.Move.run : Config
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
    
    53.  Tv.Move.withCatalog : Config
         -> '{IO, Exception, TvMoveCatalog} a
         ->{IO, Exception} a
         ↓
    54.  Tv.Move.withCatalog : Config
         -> '{IO, Exception, TvMoveCatalog} a
         ->{IO, Exception} a
    
    55.  Tv.Rename.applyTv : Config
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    56.  Tv.Rename.applyTv : Config
         -> Boolean
         -> '{IO, Exception} ()
    
    57.  Tv.Resolve.identify : Config ->{IO, Exception} ()
         ↓
    58.  Tv.Resolve.identify : Config ->{IO, Exception} ()
    
    59.  Tv.Resolve.run : Config ->{IO, Exception} ()
         ↓
    60.  Tv.Resolve.run : Config ->{IO, Exception} ()
    
    61.  Tv.Resolve.runWith : Boolean
         -> Config
         ->{IO, Exception} ()
         ↓
    62.  Tv.Resolve.runWith : Boolean
         -> Config
         ->{IO, Exception} ()
    
    63.  Tv.Stage.runProbeAtTv : Config
         -> Text
         -> Text
         ->{IO, Exception} ()
         ↓
    64.  Tv.Stage.runProbeAtTv : Config
         -> Text
         -> Text
         ->{IO, Exception} ()
    
    65.  Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
         ↓
    66.  Tv.Stage.runProbeTv : Config ->{IO, Exception} ()
    
    67.  uniDork.batchedMain : Config
         -> Boolean
         -> Text
         ->{IO, Exception} ()
         ↓
    68.  uniDork.batchedMain : Config
         -> Boolean
         -> Text
         ->{IO, Exception} ()
    
    69.  uniDork.batchedRun : Config ->{IO, Exception} ()
         ↓
    70.  uniDork.batchedRun : Config ->{IO, Exception} ()
    
    71.  uniDork.processBatch : Config
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
         ↓
    72.  uniDork.processBatch : Config
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
    
    73.  uniDork.renameNewCombined : Config
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    74.  uniDork.renameNewCombined : Config
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
    
    75.  uniDork.runBatchSafe : Config
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
    76.  uniDork.runBatchSafe : Config
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
    
    77.  Versions.clearAll : Config ->{IO, Exception} ()
         ↓
    78.  Versions.clearAll : Config ->{IO, Exception} ()
    
    79.  Versions.fetchMultiTmdbs : Config
         ->{IO, Exception} [Text]
         ↓
    80.  Versions.fetchMultiTmdbs : Config
         ->{IO, Exception} [Text]
    
    81.  Versions.loadDesired : Config
         ->{IO, Exception} [(Text, (Text, Boolean))]
         ↓
    82.  Versions.loadDesired : Config
         ->{IO, Exception} [(Text, (Text, Boolean))]
    
    83.  Versions.run : Config ->{IO, Exception} ()
         ↓
    84.  Versions.run : Config ->{IO, Exception} ()
    
    85.  Versions.runGroupChunk : Config
         -> [Text]
         ->{IO, Exception} ()
         ↓
    86.  Versions.runGroupChunk : Config
         -> [Text]
         ->{IO, Exception} ()
    
    87.  Versions.sessionGroups : Nat
         ↓
    88.  Versions.sessionGroups : Nat
    
    89.  Versions.stampNfos : Config
         -> Boolean
         ->{IO, Exception} ()
         ↓
    90.  Versions.stampNfos : Config
         -> Boolean
         ->{IO, Exception} ()
    
    91.  Versions.writeGroup : PreparedQuery
           r1 a1 ((((Text, Text), Int), Text), Text)
         -> PreparedQuery r a Int
         -> PreparedQuery rE aE Int
         -> PreparedCommand rV aV
         -> Text
         ->{IO, Exception, Postgres} ()
         ↓
    92.  Versions.writeGroup : PreparedCommand r2 a2
         -> PreparedQuery
           r1 a1 ((((Text, Text), Int), Text), Text)
         -> PreparedQuery r a Int
         -> PreparedQuery rE aE Int
         -> PreparedCommand rV aV
         -> Text
         ->{IO, Exception, Postgres} ()
    
    93.  versionsRun : '{IO, Exception} ()
         ↓
    94.  versionsRun : '{IO, Exception} ()

  Added definitions:

    95.  myPg.awaitReader                  : mutable.Ref
                                             g Boolean
                                           -> Nat
                                           ->{g, IO, Exception} ()
    96.  Versions.deleteEditionsForTmdbSql : Command
                                             a (Text -> a)
    97.  Versions.runGroupChunkSafe        : Config
                                           -> [Text]
                                           ->{IO, Exception} Boolean
    98.  Versions.sessionSettleMicros      : Nat

  Name changes:

    Original                                                                                                               Changes
    99.  lib.alvaroc1_jwt_0_0_1.lib.base.math.Natural.internal.bitWidth                                                 ┐  100. Versions.sessionGroups (removed)
    101. lib.base.math.Natural.Deprecated.internal.bitWidth                                                             │  
    102. lib.html_2_2_0.lib.base_2_9_1.math.Natural.internal.bitWidth                                                   │  
    103. lib.unison_base_7_12_1.math.Natural.Deprecated.internal.bitWidth                                               │  
    104. lib.unison_blog_engine_2_1_2.lib.shareSdk_2_7_0.lib.svg_1_0_0.lib.file.lib.base.math.Natural.internal.bitWidth │  
    105. lib.unison_blog_engine_2_1_2.lib.unison_base_3_21_0.math.Natural.internal.bitWidth                             │  
    106. Versions.sessionGroups                                                                                         ┘  
    
    107. myPg.runIO                                                                                                     ┐  108. myPg.runIO (removed)
    109. runarorama_postgres_2_5_1.postgres.net.messaging.PostgresMessaging.runIO                                       ┘  
```
```
