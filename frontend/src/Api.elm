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
runAgent : { diagram : String, triggerInput : String, apiKey : String } -> Cmd Msg
runAgent { diagram, triggerInput, apiKey } =
    Http.post
        { url = endpoint
        , body = Http.jsonBody (requestEncoder diagram triggerInput apiKey)
        , expect = Http.expectJson GotExecutionResult responseDecoder
        }


requestEncoder : String -> String -> String -> Encode.Value
requestEncoder diagram triggerInput apiKey =
    let
        baseFields =
            [ ( "api_key", Encode.string apiKey )
            , ( "diagram_text", Encode.string diagram )
            ]

        fields =
            if String.isEmpty triggerInput then
                baseFields
            else
                baseFields ++ [ ( "trigger_input", Encode.string triggerInput ) ]
    in
    Encode.object fields


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
