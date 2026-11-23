module AppParser exposing (parsePipeline)

import Parser exposing (Parser, (|.), (|=), succeed, symbol, spaces, getChompedString, chompUntil, chompWhile, oneOf, map)
import Types exposing (ActionType(..), PipelineNode)

actionTypeParser : Parser ActionType
actionTypeParser =
    oneOf
        [ map (\_ -> Fetch) (symbol "FETCH:")
        , map (\_ -> Prompt) (symbol "PROMPT:")
        , map (\_ -> Post) (symbol "POST:")
        ]

idParser : Parser String
idParser =
    getChompedString <| chompWhile (\c -> Char.isAlphaNum c || c == '_')

nodeContentParser : Parser ( ActionType, String )
nodeContentParser =
    succeed (\a p -> ( a, p ))
        |. symbol "\""
        |= actionTypeParser
        |. spaces
        |= (getChompedString (chompUntil "\"") |> map String.trim)
        |. symbol "\""

nodeParser : Parser PipelineNode
nodeParser =
    succeed (\id (aType, payload) -> PipelineNode id aType payload)
        |= idParser
        |. symbol "["
        |= nodeContentParser
        |. symbol "]"

connectorParser : Parser ()
connectorParser =
    succeed ()
        |. spaces
        |. oneOf [ symbol "-->", succeed () ]
        |. spaces

pipelineParser : Parser (List PipelineNode)
pipelineParser =
    Parser.loop [] pipelineStep

pipelineStep : List PipelineNode -> Parser (Parser.Step (List PipelineNode) (List PipelineNode))
pipelineStep revNodes =
    oneOf
        [ succeed (\node -> Parser.Loop (node :: revNodes))
            |. connectorParser
            |= nodeParser
        , succeed ()
            |. spaces
            |. Parser.end
            |> map (\_ -> Parser.Done (List.reverse revNodes))
        ]

parsePipeline : String -> Result String (List PipelineNode)
parsePipeline input =
    case Parser.run pipelineParser (String.trim input) of
        Ok nodes ->
            if List.isEmpty nodes then
                Err "Pipeline is empty or invalid format."
            else
                Ok nodes

        Err _ ->
            Err "Syntax error. Expected NodeID[PREFIX: Payload] or NodeID[\"PREFIX: Payload\"]."
