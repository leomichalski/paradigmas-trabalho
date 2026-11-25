module StorageApi exposing
    ( deleteFlow
    , listFlows
    , nodeTypeToString
    , openFlow
    , saveFlow
    )

{-| Chamadas ao backend para o armazenamento de fluxos (parte #2).

O backend repassa cada chamada para o backend/prolog/armazenamento.pl:

    GET    /fluxos              -> fluxos_salvos/1
    GET    /fluxos?tipo=post    -> fluxos_com_tipo/2
    POST   /fluxos              -> salvar_fluxo/3
    GET    /fluxos/{nome}       -> carregar_fluxo/3
    DELETE /fluxos/{nome}       -> remover_fluxo/1

-}

import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Types exposing (FlowFilter(..), Msg(..), NodeType(..), SavedFlow)
import Url


baseUrl : String
baseUrl =
    "http://localhost:8000/fluxos"


{-| O nome vai dentro da URL, então espaços e acentos precisam ser codificados.
-}
flowUrl : String -> String
flowUrl name =
    baseUrl ++ "/" ++ Url.percentEncode name


{-| Resposta: `{ "fluxos": ["noticias", "resumo"] }`
-}
listFlows : FlowFilter -> Cmd Msg
listFlows filter =
    let
        url =
            case filter of
                AllFlows ->
                    baseUrl

                UsingNode nodeType ->
                    baseUrl ++ "?tipo=" ++ nodeTypeToString nodeType
    in
    Http.get
        { url = url
        , expect =
            Http.expectJson GotFlowList
                (Decode.field "fluxos" (Decode.list Decode.string))
        }


{-| Envia: `{ "nome": "...", "diagram_text": "graph TD ...", "trigger_input": "..." }`
-}
saveFlow : String -> SavedFlow -> Cmd Msg
saveFlow name flow =
    Http.post
        { url = baseUrl
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "nome", Encode.string name )
                    , ( "diagram_text", Encode.string flow.diagram )
                    , ( "trigger_input", Encode.string flow.trigger )
                    ]
                )
        , expect = Http.expectWhatever (GotSaveResult name)
        }


{-| Resposta: `{ "nome": "...", "diagram_text": "graph TD ...", "trigger_input": "..." }`
-}
openFlow : String -> Cmd Msg
openFlow name =
    Http.get
        { url = flowUrl name
        , expect =
            Http.expectJson (GotOpenResult name) savedFlowDecoder
        }


{-| Se o backend não mandar o gatilho, ele vira "" e o campo é limpo.
-}
savedFlowDecoder : Decode.Decoder SavedFlow
savedFlowDecoder =
    Decode.map2 SavedFlow
        (Decode.field "diagram_text" Decode.string)
        (Decode.oneOf
            [ Decode.field "trigger_input" Decode.string
            , Decode.succeed ""
            ]
        )


deleteFlow : String -> Cmd Msg
deleteFlow name =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = flowUrl name
        , body = Http.emptyBody
        , expect = Http.expectWhatever (GotDeleteResult name)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| O mesmo nome que o Prolog usa (tipo_da_acao/2).
-}
nodeTypeToString : NodeType -> String
nodeTypeToString nodeType =
    case nodeType of
        FetchNode ->
            "fetch"

        PromptNode ->
            "prompt"

        PostNode ->
            "post"

        AbortNode ->
            "abort"

        DoneNode ->
            "done"
