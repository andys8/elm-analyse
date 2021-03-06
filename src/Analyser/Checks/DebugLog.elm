module Analyser.Checks.DebugLog exposing (checker)

import AST.Ranges as Range
import ASTUtil.Inspector as Inspector exposing (Order(Post), defaultConfig)
import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema
import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.Ranged exposing (Ranged)


checker : Checker
checker =
    { check = scan
    , info =
        { key = "DebugLog"
        , name = "Debug Log"
        , description = "This is nice for development, but you do not want to ship this to package users or your end users."
        , schema =
            Schema.schema
                |> Schema.rangeProp "range"
        }
    }


type alias Context =
    List MessageData


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    Inspector.inspect
        { defaultConfig | onExpression = Post onExpression }
        fileContext.ast
        []


onExpression : Ranged Expression -> Context -> Context
onExpression ( range, expression ) context =
    case expression of
        QualifiedExpr moduleName f ->
            if entryForQualifiedExpr moduleName f then
                (Data.init
                    (String.concat
                        [ "Use of Debug.log at "
                        , Range.rangeToString range
                        ]
                    )
                    |> Data.addRange "range" range
                )
                    :: context
            else
                context

        _ ->
            context


entryForQualifiedExpr : List String -> String -> Bool
entryForQualifiedExpr moduleName f =
    if moduleName == [ "Debug" ] then
        if f == "log" then
            True
        else
            False
    else
        False
