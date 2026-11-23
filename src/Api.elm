module Api exposing (openAiRequestEncoder, openAiResponseDecoder)

import Json.Encode as Encode
import Json.Decode as Decode exposing (Decoder)

openAiRequestEncoder : String -> Encode.Value
openAiRequestEncoder prompt =
    Encode.object
        [ ( "model", Encode.string "gpt-4o-mini" )
        , ( "messages"
          , Encode.list Encode.object
                [ [ ( "role", Encode.string "system" )
                  , ( "content", Encode.string "You are a helpful assistant." )
                  ]
                , [ ( "role", Encode.string "user" )
                  , ( "content", Encode.string prompt )
                  ]
                ]
          )
        ]

openAiResponseDecoder : Decoder String
openAiResponseDecoder =
    Decode.field "choices"
        (Decode.index 0
            (Decode.field "message"
                (Decode.field "content" Decode.string)
            )
        )
