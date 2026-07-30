<!-- unison-causal: #ktt1cnt29j -->
<!-- unison-prev:   #hv0abt7cia -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #ktt1cnt29j -->
<!-- generated: 2026-07-30T21:02:06Z -->

# uniDork snapshot `#ktt1cnt29j`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #hv0abt7cia #ktt1cnt29j

  Updates:

    1.  ability db.MovieCatalog
        ↓
    2.  ability db.MovieCatalog
    
    3.  cli : '{IO, Exception} ()
        ↓
    4.  cli : '{IO, Exception} ()
    
    5.  db.MovieCatalog.saveLibraryMovie : Optional Text
        -> Optional Nat
        -> Optional Nat
        -> Movie
        ->{MovieCatalog#bulcmevs05} ()
        ↓
    6.  db.MovieCatalog.saveLibraryMovie : Optional Text
        -> Optional Nat
        -> Optional Nat
        -> Movie
        ->{MovieCatalog#2ncd9ns677} ()
    
    7.  uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
        ↓
    8.  uniDork.batchedMain : Config
        -> Boolean
        -> Text
        ->{IO, Exception} ()
    
    9.  uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
        ↓
    10. uniDork.processBatch : Config
        -> Boolean
        -> Nat
        -> Nat
        -> Nat
        -> mutable.Ref {IO} (Nat, Nat)
        -> [(FilePath, Nat)]
        ->{IO, Exception} ()
    
    11. uniDork.processOne : Config
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
    12. uniDork.processOne : Boolean
        -> FilePath
        ->{IO, MovieCatalog#2ncd9ns677, Exception} ()
    
    13. uniDork.runBatchSafe : Config
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
    14. uniDork.runBatchSafe : Config
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

    15. db.MovieCatalog.cacheProbe        : Text
                                          -> Int
                                          -> ProbeResult
                                          ->{MovieCatalog#2ncd9ns677} ()
    16. db.MovieCatalog.isImported        : Text
                                          ->{MovieCatalog#2ncd9ns677} Boolean
    17. db.MovieCatalog.recordLibraryFile : Text
                                          -> Text
                                          -> ProbeResult
                                          ->{MovieCatalog#2ncd9ns677} ()
    18. uniDork.claimOf                   : FilePath
                                          -> (FilePath, Text)
    19. uniDork.importLibraryRun          : Config
                                          -> [Text]
                                          ->{IO, Exception} ()
    20. uniDork.importMovie               : Text
                                          -> Movie
                                          ->{IO,
                                          MovieCatalog#2ncd9ns677,
                                          Exception} ()
    21. uniDork.importProbed              : Text
                                          -> Text
                                          -> ProbeResult
                                          -> Movie
                                          ->{IO,
                                          MovieCatalog#2ncd9ns677,
                                          Exception} ()
    22. uniDork.moveTarget                : [Text]
                                          -> Optional Text
    23. uniDork.partitionImported         : Config
                                          -> Boolean
                                          -> [(FilePath, Text)]
                                          ->{IO, Exception} ( [FilePath],
                                            Nat)
    24. uniDork.runVerb                   : Config
                                          -> Text
                                          -> [Text]
                                          ->{IO, Exception} ()
    25. uniDork.sizeOfWork                : (FilePath, Text)
                                          ->{IO, Exception} ( Nat,
                                            (FilePath, Text))
    26. uniDork.splitByVideo              : [FilePath]
                                          ->{IO, Exception} ( [( FilePath,
                                            Text)],
                                            [FilePath])
    27. uniDork.usage                     : Text
    28. uniDork.videoOf                   : FilePath
                                          ->{IO, Exception} Optional
                                            (FilePath, Text)
    29. uniDork.withMovieCatalog          : Config
                                          -> '{IO,
                                          MovieCatalog#2ncd9ns677,
                                          Exception} a
                                          ->{IO, Exception} a

  Removed definitions:

    30. db.MovieCatalog.identityFor       : Text
                                          ->{MovieCatalog#bulcmevs05} Optional
                                            FileIdentity
    31. db.MovieCatalog.recordAssociation : Int
                                          -> Nat
                                          -> Int
                                          -> Text
                                          ->{MovieCatalog#bulcmevs05} ()
    32. db.MovieCatalog.recordBufferFile  : Text
                                          -> Text
                                          -> ProbeResult
                                          ->{MovieCatalog#bulcmevs05} ()
    33. db.MovieCatalog.updateLibraryPath : Text
                                          -> Text
                                          -> Text
                                          -> Int
                                          ->{MovieCatalog#bulcmevs05} ()
    34. uniDork.batchedRun                : Config
                                          ->{IO, Exception} ()
```
```
