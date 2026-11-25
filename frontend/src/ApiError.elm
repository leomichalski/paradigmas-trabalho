module ApiError exposing
    ( ApiError(..)
    , decodeBody
    , expectJson
    , expectWhatever
    , fromResponse
    , toString
    )

{-| Erros de chamadas ao backend.

O `Http.Error` do Elm joga fora o corpo da resposta em `BadStatus`, e é nele
que o FastAPI explica o que deu errado: `{ "detail": "..." }`. Este módulo
guarda esse texto para a tela poder mostrá-lo.

-}

import Http
import Json.Decode as Decode exposing (Decoder)


type ApiError
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Int (Maybe String)
    | BadBody String


{-| Como `Http.expectJson`, mas o erro é um `ApiError`.
-}
expectJson : (Result ApiError a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg (fromResponse (decodeBody decoder))


{-| Como `Http.expectWhatever`: qualquer resposta 2xx vale, o corpo é ignorado.
-}
expectWhatever : (Result ApiError () -> msg) -> Http.Expect msg
expectWhatever toMsg =
    Http.expectStringResponse toMsg (fromResponse (\_ -> Ok ()))


{-| Transforma a resposta HTTP num `Result`. Só o caso `GoodStatus_` usa o
conversor do corpo; em `BadStatus_` o corpo é lido atrás do campo `detail`.
-}
fromResponse : (String -> Result ApiError a) -> Http.Response String -> Result ApiError a
fromResponse bodyToResult response =
    case response of
        Http.BadUrl_ url ->
            Err (BadUrl url)

        Http.Timeout_ ->
            Err Timeout

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body ->
            Err (BadStatus metadata.statusCode (detailFromBody body))

        Http.GoodStatus_ _ body ->
            bodyToResult body


decodeBody : Decoder a -> String -> Result ApiError a
decodeBody decoder body =
    Decode.decodeString decoder body
        |> Result.mapError (Decode.errorToString >> BadBody)


{-| Lê o `detail` do corpo de um erro do FastAPI. Dois formatos:

    { "detail": "Fluxo não encontrado: x" }                 -- HTTPException
    { "detail": [ { "msg": "Field required", ... } ] }      -- erro 422

Qualquer outro corpo (HTML de um proxy, texto vazio...) dá `Nothing`.

-}
detailFromBody : String -> Maybe String
detailFromBody body =
    Decode.decodeString (Decode.field "detail" detailDecoder) body
        |> Result.toMaybe
        |> Maybe.andThen nonBlank


detailDecoder : Decoder String
detailDecoder =
    Decode.oneOf
        [ Decode.string
        , Decode.list (Decode.field "msg" Decode.string)
            |> Decode.map (String.join "; ")
        ]


nonBlank : String -> Maybe String
nonBlank text =
    if String.isEmpty (String.trim text) then
        Nothing

    else
        Just text


toString : ApiError -> String
toString error =
    case error of
        BadUrl url ->
            "Bad URL: " ++ url

        Timeout ->
            "Network Timeout"

        NetworkError ->
            "Network Error"

        BadStatus _ (Just detail) ->
            detail

        BadStatus 401 Nothing ->
            "Unauthorized: Please check your API Key."

        BadStatus status Nothing ->
            "Bad Status: " ++ String.fromInt status

        BadBody message ->
            "Bad Body: " ++ message
