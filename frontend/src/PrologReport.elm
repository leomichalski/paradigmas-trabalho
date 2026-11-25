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


decoder : Decoder Report
decoder =
    Decode.map2 Report
        (Decode.field "erros" (Decode.list findingDecoder))
        (Decode.field "sugestoes" (Decode.list suggestionDecoder))


findingDecoder : Decoder Finding
findingDecoder =
    Decode.map3 Finding
        (Decode.field "codigo" Decode.string |> Decode.map codeFromString)
        (Decode.field "mensagem" Decode.string)
        (Decode.oneOf
            [ Decode.field "nos" (Decode.list Decode.string)
            , Decode.succeed []
            ]
        )


suggestionDecoder : Decoder Suggestion
suggestionDecoder =
    Decode.map3 Suggestion
        (Decode.field "titulo" Decode.string)
        (Decode.field "mensagem" Decode.string)
        (Decode.maybe (Decode.field "diagrama" Decode.string))


codeFromString : String -> FindingCode
codeFromString raw =
    case raw of
        "ciclo" ->
            Cycle

        "no_inalcancavel" ->
            UnreachableNode

        "ligacao_invalida" ->
            InvalidLink

        other ->
            Other other
