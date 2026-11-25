module ApiTest exposing (suite)

import Api
import Expect exposing (Expectation)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)
import Types exposing (ExecutionOutcome(..))


expectErr : Result e a -> Expectation
expectErr result =
    case result of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "esperava Err, mas veio Ok"


suite : Test
suite =
    describe "Api"
        [ responseTests
        , requestTests
        ]


responseTests : Test
responseTests =
    describe "responseDecoder"
        [ test "status success vira Succeeded" <|
            \_ ->
                Decode.decodeString Api.responseDecoder
                    """{"status":"success","message":"ok","logs":"passo 1"}"""
                    |> Expect.equal
                        (Ok { outcome = Succeeded, message = "ok", logs = "passo 1" })
        , test "message e logs ausentes viram texto vazio" <|
            \_ ->
                Decode.decodeString Api.responseDecoder """{"status":"success"}"""
                    |> Expect.equal
                        (Ok { outcome = Succeeded, message = "", logs = "" })
        , test "qualquer outro status vira NotSucceeded, com o texto original" <|
            \_ ->
                Decode.decodeString Api.responseDecoder
                    """{"status":"error","message":"falhou","logs":""}"""
                    |> Expect.equal
                        (Ok { outcome = NotSucceeded "error", message = "falhou", logs = "" })
        , test "sem o campo status é erro de decodificação" <|
            \_ ->
                expectErr (Decode.decodeString Api.responseDecoder """{"message":"ok"}""")
        , test "status que não é texto é erro de decodificação" <|
            \_ ->
                expectErr (Decode.decodeString Api.responseDecoder """{"status":true}""")
        ]


requestTests : Test
requestTests =
    let
        field name value =
            Encode.encode 0 value
                |> Decode.decodeString (Decode.maybe (Decode.field name Decode.string))
    in
    describe "requestEncoder"
        [ test "envia api_key e diagram_text" <|
            \_ ->
                let
                    body =
                        Api.requestEncoder "graph TD" "dado" "sk-123"
                in
                ( field "api_key" body, field "diagram_text" body )
                    |> Expect.equal ( Ok (Just "sk-123"), Ok (Just "graph TD") )
        , test "envia trigger_input quando preenchido" <|
            \_ ->
                field "trigger_input" (Api.requestEncoder "d" "dado" "k")
                    |> Expect.equal (Ok (Just "dado"))
        , test "omite trigger_input quando vazio" <|
            \_ ->
                field "trigger_input" (Api.requestEncoder "d" "" "k")
                    |> Expect.equal (Ok Nothing)
        ]
