module Analyser.Checks.UnusedVariable exposing (checker)

import AST.Ranges as Range
import ASTUtil.Variables exposing (VariableType(Defined))
import Analyser.Checks.Base exposing (Checker)
import Analyser.Checks.Variables as Variables exposing (UsedVariableContext)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema
import Elm.Interface as Interface
import Elm.Syntax.Module exposing (Module(..))
import Elm.Syntax.Range as Syntax exposing (Range)
import Tuple3


checker : Checker
checker =
    { check = scan
    , info =
        { key = "UnusedVariable"
        , name = "Unused Variable"
        , description = "Variables that are not used could be removed or marked as _ to avoid unnecessary noise."
        , schema =
            Schema.schema
                |> Schema.varProp "varName"
                |> Schema.rangeProp "range"
        }
    }


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    let
        x : UsedVariableContext
        x =
            Variables.collect fileContext

        unusedVariables =
            Variables.unusedVariables x
                |> List.filterMap (\( x, t, y ) -> forVariableType t x y)

        unusedTopLevels =
            Variables.unusedTopLevels x
                |> List.filter (filterByModuleType fileContext)
                |> List.filter (Tuple3.first >> flip Interface.exposesFunction fileContext.interface >> not)
                |> List.filterMap (\( x, t, y ) -> forVariableType t x y)
    in
    unusedVariables ++ unusedTopLevels


forVariableType : VariableType -> String -> Range -> Maybe MessageData
forVariableType variableType variableName range =
    case variableType of
        Defined ->
            Just (buildMessageData variableName range)

        _ ->
            Nothing


buildMessageData : String -> Range -> MessageData
buildMessageData varName range =
    Data.init
        (String.concat
            [ "Unused variable `"
            , varName
            , "` at "
            , Range.rangeToString range
            ]
        )
        |> Data.addVarName "varName" varName
        |> Data.addRange "range" range


filterByModuleType : FileContext -> ( String, VariableType, Syntax.Range ) -> Bool
filterByModuleType fileContext =
    case fileContext.ast.moduleDefinition of
        EffectModule _ ->
            filterForEffectModule

        _ ->
            always True


filterForEffectModule : ( String, VariableType, Syntax.Range ) -> Bool
filterForEffectModule ( k, _, _ ) =
    not <| List.member k [ "init", "onEffects", "onSelfMsg", "subMap", "cmdMap" ]
