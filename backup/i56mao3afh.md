<!-- unison-causal: #i56mao3afh -->
<!-- unison-prev:   #enle2rjbsf -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #i56mao3afh -->
<!-- generated: 2026-07-18T20:57:25Z -->

# uniDork snapshot `#i56mao3afh`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #enle2rjbsf #i56mao3afh

  Removed definitions:

    1. ┌ Subs.Fix.subsChunkSize : Nat
    2. └ Rename.sweepChunkSize  

  Name changes:

    Original                                                     Changes
    3. lib.unison_auth_2_0_1.lib.uuid_1_0_1.UUID.Version.size ┐  4. Stage.probeConnChunks (removed)
    5. Stage.probeConnChunks                                  │  
    6. Tv.Stage.maxDepth                                      ┘  
    
    7. Resolve.resolveChunkSize                               ┐  8. Stage.partitionSessionSize (removed)
    9. Stage.partitionSessionSize                             ┘  
```
```
