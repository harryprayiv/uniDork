<!-- unison-causal: #j4ggoodht8 -->
<!-- unison-prev:   #222bvrknv9 -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #j4ggoodht8 -->
<!-- generated: 2026-07-04T04:43:06Z -->

# uniDork snapshot `#j4ggoodht8`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #222bvrknv9 #j4ggoodht8

  Updates:

    1.  cli : '{IO, Exception} ()
        ↓
    2.  cli : '{IO, Exception} ()
    
    3.  Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    4.  Rename.runNew : Config
        -> Text
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
    
    5.  uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()
        ↓
    6.  uniDork.renameNewCombined : Config
        -> Text
        -> Boolean
        -> '{IO, Exception} ()

  Added definitions:

    7.  Rename.rowToRenameRowK         : ( ( ( ( ( ( ( ( Int,
                                         Text),
                                         Text),
                                         Text),
                                         Int),
                                         Optional Text),
                                         Text),
                                         Optional Int),
                                         Text)
                                       -> (Int, RenameRow)
    8.  Rename.selectRenamableChunkSql : postgres.Query
                                         r
                                         (Int ->{g, g1} r)
                                         ( ( ( ( ( ( ( ( Int,
                                           Text),
                                           Text),
                                           Text),
                                           Int),
                                           Optional Text),
                                           Text),
                                           Optional Int),
                                           Text)

  Name changes:

    Original                  Changes
    9.  Move.moveChunkSize    10. Rename.renameChunkSize (added)
```
```
