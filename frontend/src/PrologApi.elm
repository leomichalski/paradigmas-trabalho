module PrologApi exposing (analyze)

import Http
import Json.Encode as Encode
import PrologReport exposing (Report)


endpoint : String
endpoint =
    "http://localhost:8000/analisar"


analyze : (Result Http.Error Report -> msg) -> String -> Cmd msg
analyze toMsg diagram =
    Http.post
        { url = endpoint
        , body = Http.jsonBody (Encode.object [ ( "diagram_text", Encode.string diagram ) ])
        , expect = Http.expectJson toMsg PrologReport.decoder
        }
