module Analyser.Checks.UnusedImportedVariable exposing (checker)

import ASTUtil.Variables exposing (VariableType(Imported))
import Analyser.Checks.Base exposing (Checker, keyBasedChecker)
import Analyser.Checks.Variables as Variables
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Range as Range exposing (Range, RangeContext)
import Analyser.Messages.Types exposing (Message, MessageData(UnusedImportedVariable), newMessage)
import Dict
import Elm.Interface as Interface
import Elm.Syntax.Module exposing (..)
import Elm.Syntax.Range as Syntax
import Tuple3


checker : Checker
checker =
    { check = scan
    , shouldCheck = keyBasedChecker [ "UnusedImportedVariable" ]
    , key = "UnusedImportedVariable"
    , name = "Unused Imported Variable"
    , description = "When a function is imported from a module but is unused, it is better to remove it."
    }


scan : RangeContext -> FileContext -> Configuration -> List Message
scan rangeContext fileContext _ =
    let
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
        Imported ->
            Just (UnusedImportedVariable path variableName range)

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
