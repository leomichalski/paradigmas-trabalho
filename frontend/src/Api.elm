module Api exposing (runAgent)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Types exposing (ExecutionResponse, Msg(..))


endpoint : String
endpoint =
    "http://localhost:8000/execute"


{-| Envia o diagrama Mermaid (em texto) para o backend.

    POST /execute
    { "api_key": "...", "diagram_text": "graph TD ..." }

-}
runAgent : { diagram : String, apiKey : String } -> Cmd Msg
runAgent { diagram, apiKey } =
    Http.post
        { url = endpoint
        , body = Http.jsonBody (requestEncoder diagram apiKey)
        , expect = Http.expectJson GotExecutionResult responseDecoder
        }


requestEncoder : String -> String -> Encode.Value
requestEncoder diagram apiKey =
    Encode.object
        [ ( "api_key", Encode.string apiKey )
        , ( "diagram_text", Encode.string diagram )
        ]


{-| Resposta:

    { "status": "success", "message": "...", "logs": "texto com os logs" }

-}
responseDecoder : Decoder ExecutionResponse
responseDecoder =
    Decode.map3 ExecutionResponse
        (Decode.field "status" Decode.string)
        (optionalString "message")
        (optionalString "logs")


optionalString : String -> Decoder String
optionalString name =
    Decode.oneOf
        [ Decode.field name Decode.string
        , Decode.succeed ""
        ]
