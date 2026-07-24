<!-- unison-causal: #oimbcad67v -->
<!-- unison-prev:   #rrf0bcsn7l -->
<!-- restore: pull @harryprayiv/uniDork/main ; reset #oimbcad67v -->
<!-- generated: 2026-07-24T17:03:49Z -->

# uniDork snapshot `#oimbcad67v`

Restore by causal hash, not the text below (diff is a lossy summary).

```
``` ucm
uniDork/main> diff.namespace #rrf0bcsn7l #oimbcad67v

  Updates:

    1.  Art.loadShowsMeta : Config
        ->{IO, Exception} [(Text, Text)]
        ↓
    2.  Art.loadShowsMeta : Config
        ->{IO, Exception} [((Text, Text), Text)]
    
    3.  Art.movies : Config -> Boolean ->{IO, Exception} ()
        ↓
    4.  Art.movies : Config -> Boolean ->{IO, Exception} ()
    
    5.  Art.showsMetaSql : postgres.Query r r (Text, Text)
        ↓
    6.  Art.showsMetaSql : postgres.Query
          r r ((Text, Text), Text)
    
    7.  Art.tvBanners : Config -> Boolean ->{IO, Exception} ()
        ↓
    8.  Art.tvBanners : Config -> Boolean ->{IO, Exception} ()
    
    9.  cli : '{IO, Exception} ()
        ↓
    10. cli : '{IO, Exception} ()

  Added definitions:

    11. Art.artworkLogDdl     : Text
    12. Art.destFor           : Text -> Text -> Text
    13. Art.ensureSchema      : Config ->{IO, Exception} ()
    14. Art.fanartThrottle    : '{IO, Exception} ()
    15. Art.fetchBannerUrl    : Text
                              -> Text
                              ->{IO, Exception} Optional Text
    16. Art.fetchLogoUrl      : Optional Text
                              -> Text
                              -> Text
                              ->{IO, Exception} Optional Text
    17. Art.insertArtSql      : Command
                                b
                                (Text
                                -> Text
                                -> Text
                                -> Text
                                -> b)
    18. Art.isPngPath         : Text -> Boolean
    19. Art.logArt            : Config
                              -> [(Text, Text, Text, Text)]
                              ->{IO, Exception} ()
    20. Art.logoEntryFromJson : '{unison_json_1_3_5.Decoder} ( Text,
                                Text)
    21. Art.logosFromJson     : '{unison_json_1_3_5.Decoder} [( Text,
                                Text)]
    22. Art.lookupMeta        : Text
                              -> [((Text, Text), Text)]
                              -> Optional (Text, Text)
    23. Art.movieKindStep     : Boolean
                              -> Optional Text
                              -> Text
                              -> Text
                              -> Text
                              -> (Optional Text, Optional Text)
                              -> ( (Nat, Nat, Nat),
                                [(Text, Text, Text, Text)])
                              -> Text
                              ->{IO, Exception} ( ( Nat,
                                Nat,
                                Nat),
                                [(Text, Text, Text, Text)])
    24. Art.movieKindsEnv     : '{IO, Exception} [Text]
    25. Art.movieRow          : Boolean
                              -> Optional Text
                              -> [Text]
                              -> ( (Nat, Nat, Nat),
                                [(Text, Text, Text, Text)])
                              -> (((Text, Text), Text), Text)
                              ->{IO, Exception} ( ( Nat,
                                Nat,
                                Nat),
                                [(Text, Text, Text, Text)])
    26. Art.nonEmptyPath      : Optional Text -> Optional Text
    27. Art.pairFor           : Optional Text
                              -> Text
                              -> Text
                              ->{IO, Exception} ( Optional Text,
                                Optional Text)
    28. Art.pairFromJson      : '{unison_json_1_3_5.Decoder} ( Optional
                                Text,
                                Optional Text)
    29. Art.pairOf            : Text
                              -> (Optional Text, Optional Text)
    30. Art.parseKinds        : Text -> [Text]
    31. Art.pickLogo          : [(Text, Text)] -> Optional Text
    32. Art.resolveTvdb       : Optional Text
                              -> Text
                              -> Text
                              ->{IO, Exception} Optional Text
    33. Art.splitKinds        : [Text]
                              -> [Text]
                              -> ([Text], [Text])
    34. Art.pairOf.test       : [test.Result]
    35. Art.parseKinds.test   : [test.Result]
    36. Art.pickLogo.test     : [test.Result]
    37. Art.tmdbImgUrl        : Text -> Text
    38. Art.tmdbThrottle      : '{IO, Exception} ()
    39. Art.tvKindStep        : Boolean
                              -> Optional Text
                              -> Optional Text
                              -> Text
                              -> Text
                              -> Text
                              -> (Optional Text, Optional Text)
                              -> ( ( (Nat, Nat, Nat),
                                [(Text, Text)]),
                                [(Text, Text, Text, Text)])
                              -> Text
                              ->{IO, Exception} ( ( ( Nat,
                                Nat,
                                Nat),
                                [(Text, Text)]),
                                [(Text, Text, Text, Text)])
    40. Art.tvKindsEnv        : '{IO, Exception} [Text]
    41. Art.tvRow             : Boolean
                              -> [Text]
                              -> Optional Text
                              -> Optional Text
                              -> [((Text, Text), Text)]
                              -> ( ( (Nat, Nat, Nat),
                                [(Text, Text)]),
                                [(Text, Text, Text, Text)])
                              -> (Text, Nat)
                              ->{IO, Exception} ( ( ( Nat,
                                Nat,
                                Nat),
                                [(Text, Text)]),
                                [(Text, Text, Text, Text)])
    42. Art.validMovieKinds   : [Text]
    43. Art.validTvKinds      : [Text]
```
```
