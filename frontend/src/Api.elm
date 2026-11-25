module Api exposing (runAgent)

import Http
import Json.Decode as Decode exposing (Decoder)
import File exposing (File)
import Types exposing (ExecutionResponse, Msg(..))


endpoint : String
endpoint =
    "http://localhost:8000/execute"


{-| Envia o diagrama Mermaid (em texto) para o backend.

    POST /execute
    { "api_key": "...", "diagram_text": "graph TD ..." }

-}
runAgent : { diagram : String, triggerInput : String, apiKey : String, video : Maybe File } -> Cmd Msg
runAgent { diagram, triggerInput, apiKey, video } =
    Http.post
        { url = endpoint
        , body = Http.multipartBody (requestParts diagram triggerInput apiKey video)
        , expect = Http.expectJson GotExecutionResult responseDecoder
        }


requestParts : String -> String -> String -> Maybe File -> List Http.Part
requestParts diagram triggerInput apiKey video =
    let
        baseFields =
            [ Http.stringPart "api_key" apiKey
            , Http.stringPart "diagram_text" diagram
            ]

        fields =
            if String.isEmpty triggerInput then
                baseFields
            else
                baseFields ++ [ Http.stringPart "trigger_input" triggerInput ]
    in
    case video of
        Just file -> fields ++ [ Http.filePart "video" file ]
        Nothing -> fields


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
