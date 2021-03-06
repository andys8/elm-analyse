module Analyser.Checks.DebugCrashTests exposing (..)

import Analyser.Checks.CheckTestUtil as CTU
import Analyser.Checks.DebugCrash as DebugCrash
import Analyser.Messages.Data as Data exposing (MessageData)
import Test exposing (Test)


debugCrash : ( String, String, List MessageData )
debugCrash =
    ( "debugCrash"
    , """module Bar exposing (..)

foo = Debug.crash "NOOO"

"""
    , [ Data.init "foo"
            |> Data.addRange "range"
                { start = { row = 2, column = 6 }, end = { row = 2, column = 17 } }
      ]
    )


noDebug : ( String, String, List MessageData )
noDebug =
    ( "noDebug"
    , """module Bar exposing (..)

foo x = x
"""
    , []
    )


all : Test
all =
    CTU.build "Analyser.Checks.DebugCrash"
        DebugCrash.checker
        [ debugCrash
        , noDebug
        ]
