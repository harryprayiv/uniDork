<!-- unison-causal: #enle2rjbsf -->
<!-- unison-prev:   #tf4aa343s1 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #enle2rjbsf -->
<!-- generated: 2026-07-18T20:54:21Z -->

# uniDork snapshot `#enle2rjbsf`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #tf4aa343s1 #enle2rjbsf

  Updates:

    1.   type Config
         ↓
    2.   type Config
    
    3.   type Config.Tuning
         ↓
    4.   type Config.Tuning
    
    5.   cli : '{IO, Exception} ()
         ↓
    6.   cli : '{IO, Exception} ()
    
    7.   Config.cache : Config#s66spfflrb -> Cache
         ↓
    8.   Config.cache : Config#l4gnrq478k -> Cache
    
    9.   Config.cache.modify : (Cache ->{g} Cache)
         -> Config#s66spfflrb
         ->{g} Config#s66spfflrb
         ↓
    10.  Config.cache.modify : (Cache ->{g} Cache)
         -> Config#l4gnrq478k
         ->{g} Config#l4gnrq478k
    
    11.  Config.cache.set : Cache
         -> Config#s66spfflrb
         -> Config#s66spfflrb
         ↓
    12.  Config.cache.set : Cache
         -> Config#l4gnrq478k
         -> Config#l4gnrq478k
    
    13.  Config.Config : Db
         -> Cache
         -> Paths
         -> Tuning#lmnvff437a
         -> Config#s66spfflrb
         ↓
    14.  Config.Config : Db
         -> Cache
         -> Paths
         -> Tuning#f8jnclprud
         -> Config#l4gnrq478k
    
    15.  Config.db : Config#s66spfflrb -> Db
         ↓
    16.  Config.db : Config#l4gnrq478k -> Db
    
    17.  Config.db.modify : (Db ->{g} Db)
         -> Config#s66spfflrb
         ->{g} Config#s66spfflrb
         ↓
    18.  Config.db.modify : (Db ->{g} Db)
         -> Config#l4gnrq478k
         ->{g} Config#l4gnrq478k
    
    19.  Config.db.set : Db
         -> Config#s66spfflrb
         -> Config#s66spfflrb
         ↓
    20.  Config.db.set : Db
         -> Config#l4gnrq478k
         -> Config#l4gnrq478k
    
    21.  Config.fromEnv : '{IO} Config#s66spfflrb
         ↓
    22.  Config.fromEnv : '{IO} Config#l4gnrq478k
    
    23.  Config.paths : Config#s66spfflrb -> Paths
         ↓
    24.  Config.paths : Config#l4gnrq478k -> Paths
    
    25.  Config.paths.modify : (Paths ->{g} Paths)
         -> Config#s66spfflrb
         ->{g} Config#s66spfflrb
         ↓
    26.  Config.paths.modify : (Paths ->{g} Paths)
         -> Config#l4gnrq478k
         ->{g} Config#l4gnrq478k
    
    27.  Config.paths.set : Paths
         -> Config#s66spfflrb
         -> Config#s66spfflrb
         ↓
    28.  Config.paths.set : Paths
         -> Config#l4gnrq478k
         -> Config#l4gnrq478k
    
    29.  Config.readSubToken : Config#s66spfflrb
         ->{IO, Exception} Text
         ↓
    30.  Config.readSubToken : Config#l4gnrq478k
         ->{IO, Exception} Text
    
    31.  Config.readTmdbToken : Config#s66spfflrb
         ->{IO, Exception} Text
         ↓
    32.  Config.readTmdbToken : Config#l4gnrq478k
         ->{IO, Exception} Text
    
    33.  Config.toClientConfig : Config#s66spfflrb
         -> PostgresClientConfig
         ↓
    34.  Config.toClientConfig : Config#l4gnrq478k
         -> PostgresClientConfig
    
    35.  Config.tuning : Config#s66spfflrb -> Tuning#lmnvff437a
         ↓
    36.  Config.tuning : Config#l4gnrq478k -> Tuning#f8jnclprud
    
    37.  Config.tuning.modify : (Tuning#lmnvff437a
         ->{g} Tuning#lmnvff437a)
         -> Config#s66spfflrb
         ->{g} Config#s66spfflrb
         ↓
    38.  Config.tuning.modify : (Tuning#f8jnclprud
         ->{g} Tuning#f8jnclprud)
         -> Config#l4gnrq478k
         ->{g} Config#l4gnrq478k
    
    39.  Config.Tuning.probeJobs : Tuning#lmnvff437a -> Nat
         ↓
    40.  Config.Tuning.probeJobs : Tuning#f8jnclprud -> Nat
    
    41.  Config.Tuning.probeJobs.modify : (Nat ->{g} Nat)
         -> Tuning#lmnvff437a
         ->{g} Tuning#lmnvff437a
         ↓
    42.  Config.Tuning.probeJobs.modify : (Nat ->{g} Nat)
         -> Tuning#f8jnclprud
         ->{g} Tuning#f8jnclprud
    
    43.  Config.Tuning.probeJobs.set : Nat
         -> Tuning#lmnvff437a
         -> Tuning#lmnvff437a
         ↓
    44.  Config.Tuning.probeJobs.set : Nat
         -> Tuning#f8jnclprud
         -> Tuning#f8jnclprud
    
    45.  Config.tuning.set : Tuning#lmnvff437a
         -> Config#s66spfflrb
         -> Config#s66spfflrb
         ↓
    46.  Config.tuning.set : Tuning#f8jnclprud
         -> Config#l4gnrq478k
         -> Config#l4gnrq478k
    
    47.  Config.Tuning.subDelayMs : Tuning#lmnvff437a -> Nat
         ↓
    48.  Config.Tuning.subDelayMs : Tuning#f8jnclprud -> Nat
    
    49.  Config.Tuning.subDelayMs.modify : (Nat ->{g} Nat)
         -> Tuning#lmnvff437a
         ->{g} Tuning#lmnvff437a
         ↓
    50.  Config.Tuning.subDelayMs.modify : (Nat ->{g} Nat)
         -> Tuning#f8jnclprud
         ->{g} Tuning#f8jnclprud
    
    51.  Config.Tuning.subDelayMs.set : Nat
         -> Tuning#lmnvff437a
         -> Tuning#lmnvff437a
         ↓
    52.  Config.Tuning.subDelayMs.set : Nat
         -> Tuning#f8jnclprud
         -> Tuning#f8jnclprud
    
    53.  Config.Tuning.subLangs : Tuning#lmnvff437a -> [Text]
         ↓
    54.  Config.Tuning.subLangs : Tuning#f8jnclprud -> [Text]
    
    55.  Config.Tuning.subLangs.modify : ([Text] ->{g} [Text])
         -> Tuning#lmnvff437a
         ->{g} Tuning#lmnvff437a
         ↓
    56.  Config.Tuning.subLangs.modify : ([Text] ->{g} [Text])
         -> Tuning#f8jnclprud
         ->{g} Tuning#f8jnclprud
    
    57.  Config.Tuning.subLangs.set : [Text]
         -> Tuning#lmnvff437a
         -> Tuning#lmnvff437a
         ↓
    58.  Config.Tuning.subLangs.set : [Text]
         -> Tuning#f8jnclprud
         -> Tuning#f8jnclprud
    
    59.  Config.Tuning.Tuning : Nat
         -> [Text]
         -> Nat
         -> Tuning#lmnvff437a
         ↓
    60.  Config.Tuning.Tuning : Nat
         -> [Text]
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> Tuning#f8jnclprud
    
    61.  Db.createSchema : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    62.  Db.createSchema : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    63.  Db.migrate : Config#s66spfflrb ->{IO, Exception} ()
         ↓
    64.  Db.migrate : Config#l4gnrq478k ->{IO, Exception} ()
    
    65.  Db.resetSchema : Config#s66spfflrb ->{IO, Exception} ()
         ↓
    66.  Db.resetSchema : Config#l4gnrq478k ->{IO, Exception} ()
    
    67.  initDb : '{IO, Exception} ()
         ↓
    68.  initDb : '{IO, Exception} ()
    
    69.  kernel.mem.rssMb : '{IO} Nat
         ↓
    70.  kernel.mem.rssMb : '{IO} Nat
    
    71.  mig : '{IO, Exception} ()
         ↓
    72.  mig : '{IO, Exception} ()
    
    73.  Move.printProgress : Nat
         -> Nat
         -> Nat
         -> mutable.Ref g (Nat, Nat)
         ->{g, IO, Exception} ()
         ↓
    74.  Move.printProgress : Nat
         -> Nat
         -> Nat
         -> mutable.Ref g (Nat, Nat)
         ->{g, IO, Exception} ()
    
    75.  Move.run : Config#s66spfflrb
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
         ↓
    76.  Move.run : Config#l4gnrq478k
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
    
    77.  Progress.report : Text
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref g (Nat, Nat)
         ->{g, IO, Exception} ()
         ↓
    78.  Progress.report : Text
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref g (Nat, Nat)
         ->{g, IO, Exception} ()
    
    79.  Rename.runNew : Config#s66spfflrb
         -> Text
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    80.  Rename.runNew : Config#l4gnrq478k
         -> Text
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
    
    81.  Rename.sweepMissing : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    82.  Rename.sweepMissing : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    83.  Rename.sweepStaleStaging : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    84.  Rename.sweepStaleStaging : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    85.  Rename.sweepStaleStagingChunkSql : postgres.Query
           r (Int ->{g, g1} r) (Int, Text)
         ↓
    86.  Rename.sweepStaleStagingChunkSql : postgres.Query
           r (Int ->{g2, g3} Int ->{g, g1} r) (Int, Text)
    
    87.  resetDb : '{IO, Exception} ()
         ↓
    88.  resetDb : '{IO, Exception} ()
    
    89.  Resolve.runWith : Boolean
         -> Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    90.  Resolve.runWith : Boolean
         -> Config#l4gnrq478k
         ->{IO, Exception} ()
    
    91.  Stage.partitionWorkDb : Config#s66spfflrb
         -> [(a, Text)]
         ->{IO, Exception} [(Nat, (a, Text))]
         ↓
    92.  Stage.partitionWorkDb : Config#l4gnrq478k
         -> [(a, Text)]
         ->{IO, Exception} [(Nat, (a, Text))]
    
    93.  Stage.runProbeAt : Config#s66spfflrb
         -> Text
         -> Text
         ->{IO, Exception} ()
         ↓
    94.  Stage.runProbeAt : Config#l4gnrq478k
         -> Text
         -> Text
         ->{IO, Exception} ()
    
    95.  Stage.runProbeStage : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    96.  Stage.runProbeStage : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    97.  subDemo : '{IO, Exception} ()
         ↓
    98.  subDemo : '{IO, Exception} ()
    
    99.  Subs.Fix.run : Config#s66spfflrb
         -> Boolean
         ->{IO, Exception} ()
         ↓
    100. Subs.Fix.run : Config#l4gnrq478k
         -> Boolean
         ->{IO, Exception} ()
    
    101. Subs.Fix.selectBufferMoviesChunkSql : postgres.Query
           r
           (Int ->{g, g1} r)
           ( ((((Int, Text), Text), Optional Text), Int),
             Optional Int)
         ↓
    102. Subs.Fix.selectBufferMoviesChunkSql : postgres.Query
           r
           (Int ->{g2, g3} Int ->{g, g1} r)
           ( ((((Int, Text), Text), Optional Text), Int),
             Optional Int)
    
    103. sweepMissing : '{IO, Exception} ()
         ↓
    104. sweepMissing : '{IO, Exception} ()
    
    105. sweepStaleStaging : '{IO, Exception} ()
         ↓
    106. sweepStaleStaging : '{IO, Exception} ()
    
    107. Tv.Db.createSchema : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    108. Tv.Db.createSchema : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    109. Tv.Db.resetTvSchema : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    110. Tv.Db.resetTvSchema : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    111. Tv.initDb : '{IO, Exception} ()
         ↓
    112. Tv.initDb : '{IO, Exception} ()
    
    113. Tv.Move.run : Config#s66spfflrb
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
         ↓
    114. Tv.Move.run : Config#l4gnrq478k
         -> Optional Text
         -> Boolean
         ->{IO, Exception} ()
    
    115. Tv.Rename.applyTv : Config#s66spfflrb
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    116. Tv.Rename.applyTv : Config#l4gnrq478k
         -> Boolean
         -> '{IO, Exception} ()
    
    117. Tv.Resolve.identify : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    118. Tv.Resolve.identify : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    119. Tv.Resolve.run : Config#s66spfflrb ->{IO, Exception} ()
         ↓
    120. Tv.Resolve.run : Config#l4gnrq478k ->{IO, Exception} ()
    
    121. Tv.Resolve.runWith : Boolean
         -> Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    122. Tv.Resolve.runWith : Boolean
         -> Config#l4gnrq478k
         ->{IO, Exception} ()
    
    123. Tv.Stage.runProbeAtTv : Config#s66spfflrb
         -> Text
         -> Text
         ->{IO, Exception} ()
         ↓
    124. Tv.Stage.runProbeAtTv : Config#l4gnrq478k
         -> Text
         -> Text
         ->{IO, Exception} ()
    
    125. Tv.Stage.runProbeTv : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    126. Tv.Stage.runProbeTv : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    127. uniDork.batchedMain : Config#s66spfflrb
         -> Boolean
         -> Text
         ->{IO, Exception} ()
         ↓
    128. uniDork.batchedMain : Config#l4gnrq478k
         -> Boolean
         -> Text
         ->{IO, Exception} ()
    
    129. uniDork.batchedRun : Config#s66spfflrb
         ->{IO, Exception} ()
         ↓
    130. uniDork.batchedRun : Config#l4gnrq478k
         ->{IO, Exception} ()
    
    131. uniDork.processBatch : Config#s66spfflrb
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
         ↓
    132. uniDork.processBatch : Config#l4gnrq478k
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
    
    133. uniDork.processOne : Config#s66spfflrb
         -> Boolean
         -> PreparedQuery rI aI Text
         -> PreparedCommand rF aF
         -> PreparedCommand r20 a20
         -> PreparedCommand r19 a19
         -> PreparedCommand r18 a18
         -> PreparedCommand r17 a17
         -> PreparedCommand r16 a16
         -> PreparedCommand r15 a15
         -> PreparedCommand r14 a14
         -> PreparedCommand r13 a13
         -> PreparedCommand r12 a12
         -> PreparedCommand r11 a11
         -> PreparedCommand r10 a10
         -> PreparedCommand r9 a9
         -> PreparedCommand r8 a8
         -> PreparedCommand r7 a7
         -> PreparedCommand r6 a6
         -> PreparedCommand r5 a5
         -> PreparedCommand r4 a4
         -> PreparedCommand r3 a3
         -> PreparedCommand r2 a2
         -> PreparedCommand r1 a1
         -> PreparedCommand r a
         -> FilePath
         ->{IO, Exception, Postgres} ()
         ↓
    134. uniDork.processOne : Config#l4gnrq478k
         -> Boolean
         -> PreparedQuery rI aI Text
         -> PreparedCommand rF aF
         -> PreparedCommand r20 a20
         -> PreparedCommand r19 a19
         -> PreparedCommand r18 a18
         -> PreparedCommand r17 a17
         -> PreparedCommand r16 a16
         -> PreparedCommand r15 a15
         -> PreparedCommand r14 a14
         -> PreparedCommand r13 a13
         -> PreparedCommand r12 a12
         -> PreparedCommand r11 a11
         -> PreparedCommand r10 a10
         -> PreparedCommand r9 a9
         -> PreparedCommand r8 a8
         -> PreparedCommand r7 a7
         -> PreparedCommand r6 a6
         -> PreparedCommand r5 a5
         -> PreparedCommand r4 a4
         -> PreparedCommand r3 a3
         -> PreparedCommand r2 a2
         -> PreparedCommand r1 a1
         -> PreparedCommand r a
         -> FilePath
         ->{IO, Exception, Postgres} ()
    
    135. uniDork.renameNewCombined : Config#s66spfflrb
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
         ↓
    136. uniDork.renameNewCombined : Config#l4gnrq478k
         -> Text
         -> Boolean
         -> '{IO, Exception} ()
    
    137. uniDork.runBatchSafe : Config#s66spfflrb
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
    138. uniDork.runBatchSafe : Config#l4gnrq478k
         -> Boolean
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> Nat
         -> mutable.Ref {IO} (Nat, Nat)
         -> [(FilePath, Nat)]
         ->{IO, Exception} ()
    
    139. Versions.run : Config#s66spfflrb ->{IO, Exception} ()
         ↓
    140. Versions.run : Config#l4gnrq478k ->{IO, Exception} ()
    
    141. versionsRun : '{IO, Exception} ()
         ↓
    142. versionsRun : '{IO, Exception} ()

  Added definitions:

    143. Config.Tuning.connChunks              : Tuning#f8jnclprud
                                               -> Nat
    144. Config.getPosOr                       : Text
                                               -> Nat
                                               ->{IO} Nat
    145. Config.Tuning.connChunks.modify       : (Nat ->{g} Nat)
                                               -> Tuning#f8jnclprud
                                               ->{g} Tuning#f8jnclprud
    146. Config.Tuning.partitionSession.modify : (Nat ->{g} Nat)
                                               -> Tuning#f8jnclprud
                                               ->{g} Tuning#f8jnclprud
    147. Config.Tuning.subsChunk.modify        : (Nat ->{g} Nat)
                                               -> Tuning#f8jnclprud
                                               ->{g} Tuning#f8jnclprud
    148. Config.Tuning.sweepChunk.modify       : (Nat ->{g} Nat)
                                               -> Tuning#f8jnclprud
                                               ->{g} Tuning#f8jnclprud
    149. Config.Tuning.partitionSession        : Tuning#f8jnclprud
                                               -> Nat
    150. Config.Tuning.connChunks.set          : Nat
                                               -> Tuning#f8jnclprud
                                               -> Tuning#f8jnclprud
    151. Config.Tuning.partitionSession.set    : Nat
                                               -> Tuning#f8jnclprud
                                               -> Tuning#f8jnclprud
    152. Config.Tuning.subsChunk.set           : Nat
                                               -> Tuning#f8jnclprud
                                               -> Tuning#f8jnclprud
    153. Config.Tuning.sweepChunk.set          : Nat
                                               -> Tuning#f8jnclprud
                                               -> Tuning#f8jnclprud
    154. Config.Tuning.subsChunk               : Tuning#f8jnclprud
                                               -> Nat
    155. Config.Tuning.sweepChunk              : Tuning#f8jnclprud
                                               -> Nat
```
```
