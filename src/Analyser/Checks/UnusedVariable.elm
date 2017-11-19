module Analyser.Checks.UnusedVariable exposing (checker)

import ASTUtil.Variables exposing (VariableType(Defined))
import Analyser.Checks.Base exposing (Checker, keyBasedChecker)
import Analyser.Checks.Variables as Variables
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Range as Range exposing (Range, RangeContext)
import Analyser.Messages.Types exposing (Message, MessageData(UnusedVariable), newMessage)
import Dict exposing (Dict)
import Elm.Interface as Interface
import Elm.Syntax.Module exposing (..)
import Elm.Syntax.Range as Syntax
import Tuple3


checker : Checker
checker =
    { check = scan
    , shouldCheck = keyBasedChecker [ "UnusedVariable" ]
    , key = "UnusedVariable"
    , name = "Unused Variable"
    , description = "Variables that are not used could be removed or marked as _ to avoid unnecessary noise."
    }


type alias Scope =
    Dict String ( Int, VariableType, Syntax.Range )


type alias ActiveScope =
    ( List String, Scope )


type alias UsedVariableContext =
    { poppedScopes : List Scope
    , activeScopes : List ActiveScope
    }


scan : RangeContext -> FileContext -> Configuration -> List Message
scan rangeContext fileContext _ =
    let
        x : UsedVariableContext
        x =
            Variables.collect fileContext

        onlyUnused : List ( String, ( Int, VariableType, Syntax.Range ) ) -> List ( String, ( Int, VariableType, Syntax.Range ) )
        onlyUnused =
            List.filter (Tuple.second >> Tuple3.first >> (==) 0)

        unusedVariables =
            x.poppedScopes
                |> List.concatMap Dict.toList
                |> onlyUnused
                |> List.filterMap (\( x, ( _, t, y ) ) -> forVariableType fileContext.path t x (Range.build rangeContext y))
                |> List.map (newMessage [ ( fileContext.sha1, fileContext.path ) ])

        unusedTopLevels =
            x.activeScopes
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault Dict.empty
                |> Dict.toList
                |> onlyUnused
                |> List.filter (filterByModuleType fileContext)
                |> List.filter (Tuple.first >> flip Interface.exposesFunction fileContext.interface >> not)
                |> List.filterMap (\( x, ( _, t, y ) ) -> forVariableType fileContext.path t x (Range.build rangeContext y))
                |> List.map (newMessage [ ( fileContext.sha1, fileContext.path ) ])
    in
    unusedVariables ++ unusedTopLevels


forVariableType : String -> VariableType -> String -> Range -> Maybe MessageData
forVariableType path variableType variableName range =
    case variableType of
        Defined ->
            Just (UnusedVariable path variableName range)

        _ ->
            Nothing


filterByModuleType : FileContext -> ( String, ( Int, VariableType, Syntax.Range ) ) -> Bool
filterByModuleType fileContext =
    case fileContext.ast.moduleDefinition of
        EffectModule _ ->
            filterForEffectModule

        _ ->
            always True


filterForEffectModule : ( String, ( Int, VariableType, Syntax.Range ) ) -> Bool
filterForEffectModule ( k, _ ) =
    not <| List.member k [ "init", "onEffects", "onSelfMsg", "subMap", "cmdMap" ]
