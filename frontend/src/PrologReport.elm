module PrologReport exposing
    ( AnalysisState(..)
    , Finding
    , FindingCode(..)
    , Report
    , Suggestion
    , decoder
    )

import Json.Decode as Decode exposing (Decoder)
type AnalysisState
    = AnalysisIdle
    | Analyzing
    | AnalysisDone Report
    | AnalysisFailed String


type alias Report =
    { findings : List Finding
    , suggestions : List Suggestion
    }


type alias Finding =
    { code : FindingCode
    , message : String
    , nodes : List String
    }


type FindingCode
    = Cycle
    | UnreachableNode
    | InvalidLink
    | Other String


type alias Suggestion =
    { title : String
    , message : String
    , diagram : Maybe String
    }


{-| Decodes the POST /analyze response (graph.pl). /analyze does not send
suggestions yet, so they default to an empty list.
-}
decoder : Decoder Report
decoder =
    Decode.map3 toReport
        (Decode.field "cycle" (Decode.list Decode.string))
        (Decode.field "unreachable_nodes" (Decode.list Decode.string))
        (Decode.oneOf
            [ Decode.field "sugestoes" (Decode.list suggestionDecoder)
            , Decode.succeed []
            ]
        )


toReport : List String -> List String -> List Suggestion -> Report
toReport cycle unreachable suggestions =
    Report (cycleFindings cycle ++ unreachableFindings unreachable) suggestions


cycleFindings : List String -> List Finding
cycleFindings cycle =
    if List.isEmpty cycle then
        []

    else
        [ Finding Cycle "o fluxo volta para um nó já visitado" cycle ]


unreachableFindings : List String -> List Finding
unreachableFindings nodes =
    if List.isEmpty nodes then
        []

    else
        [ Finding UnreachableNode "nunca são alcançados a partir do início" nodes ]


suggestionDecoder : Decoder Suggestion
suggestionDecoder =
    Decode.map3 Suggestion
        (Decode.field "titulo" Decode.string)
        (Decode.field "mensagem" Decode.string)
        (Decode.maybe (Decode.field "diagrama" Decode.string))
