module ApiErrorTest exposing (suite)

import ApiError exposing (ApiError(..))
import Dict
import Expect
import Http
import Json.Decode as Decode
import Test exposing (Test, describe, test)


metadata : Int -> Http.Metadata
metadata status =
    { url = "http://localhost:8000/fluxos"
    , statusCode = status
    , statusText = ""
    , headers = Dict.empty
    }


{-| Resposta de erro do backend, lida como string.
-}
failure : Int -> String -> Result ApiError String
failure status body =
    ApiError.fromResponse
        (ApiError.decodeBody Decode.string)
        (Http.BadStatus_ (metadata status) body)


suite : Test
suite =
    describe "ApiError"
        [ detailTests
        , successTests
        , otherFailureTests
        , toStringTests
        ]


detailTests : Test
detailTests =
    describe "BadStatus guarda o detail do backend"
        [ test "HTTPException: detail é um texto" <|
            \_ ->
                failure 404 "{\"detail\":\"Fluxo não encontrado: x\"}"
                    |> Expect.equal (Err (BadStatus 404 (Just "Fluxo não encontrado: x")))
        , test "erro 422: detail é uma lista, junta os msg" <|
            \_ ->
                failure 422
                    """{"detail":[
                        {"loc":["body","nome"],"msg":"Field required","type":"missing"},
                        {"loc":["body","diagram_text"],"msg":"Field required","type":"missing"}
                    ]}"""
                    |> Expect.equal (Err (BadStatus 422 (Just "Field required; Field required")))
        , test "corpo que não é JSON (HTML de um proxy)" <|
            \_ ->
                failure 502 "<html>Bad Gateway</html>"
                    |> Expect.equal (Err (BadStatus 502 Nothing))
        , test "corpo vazio" <|
            \_ ->
                failure 500 ""
                    |> Expect.equal (Err (BadStatus 500 Nothing))
        , test "JSON sem o campo detail" <|
            \_ ->
                failure 400 "{}"
                    |> Expect.equal (Err (BadStatus 400 Nothing))
        , test "detail em branco vale como ausente" <|
            \_ ->
                failure 400 "{\"detail\":\"   \"}"
                    |> Expect.equal (Err (BadStatus 400 Nothing))
        , test "detail é lista vazia" <|
            \_ ->
                failure 422 "{\"detail\":[]}"
                    |> Expect.equal (Err (BadStatus 422 Nothing))
        ]


successTests : Test
successTests =
    describe "resposta 2xx"
        [ test "decodifica o corpo" <|
            \_ ->
                ApiError.fromResponse
                    (ApiError.decodeBody Decode.int)
                    (Http.GoodStatus_ (metadata 200) "42")
                    |> Expect.equal (Ok 42)
        , test "corpo fora do formato esperado vira BadBody" <|
            \_ ->
                case
                    ApiError.fromResponse
                        (ApiError.decodeBody Decode.int)
                        (Http.GoodStatus_ (metadata 200) "\"texto\"")
                of
                    Err (BadBody _) ->
                        Expect.pass

                    _ ->
                        Expect.fail "esperava BadBody"
        , test "conversor que ignora o corpo (como expectWhatever)" <|
            \_ ->
                ApiError.fromResponse (\_ -> Ok ())
                    (Http.GoodStatus_ (metadata 200) "isso nem é JSON")
                    |> Expect.equal (Ok ())
        ]


otherFailureTests : Test
otherFailureTests =
    describe "falhas sem resposta do servidor"
        [ test "tempo esgotado" <|
            \_ ->
                ApiError.fromResponse (\_ -> Ok ()) Http.Timeout_
                    |> Expect.equal (Err Timeout)
        , test "rede fora do ar" <|
            \_ ->
                ApiError.fromResponse (\_ -> Ok ()) Http.NetworkError_
                    |> Expect.equal (Err NetworkError)
        , test "URL inválida" <|
            \_ ->
                ApiError.fromResponse (\_ -> Ok ()) (Http.BadUrl_ "xx")
                    |> Expect.equal (Err (BadUrl "xx"))
        ]


toStringTests : Test
toStringTests =
    describe "toString"
        [ test "mostra o detail do backend" <|
            \_ ->
                ApiError.toString (BadStatus 404 (Just "Fluxo não encontrado: x"))
                    |> Expect.equal "Fluxo não encontrado: x"
        , test "o detail vem antes da mensagem pronta do 401" <|
            \_ ->
                ApiError.toString (BadStatus 401 (Just "token expirado"))
                    |> Expect.equal "token expirado"
        , test "401 sem detail" <|
            \_ ->
                ApiError.toString (BadStatus 401 Nothing)
                    |> Expect.equal "Unauthorized: Please check your API Key."
        , test "outro status sem detail" <|
            \_ ->
                ApiError.toString (BadStatus 500 Nothing)
                    |> Expect.equal "Bad Status: 500"
        , test "rede e tempo esgotado" <|
            \_ ->
                List.map ApiError.toString [ NetworkError, Timeout ]
                    |> Expect.equal [ "Network Error", "Network Timeout" ]
        ]
