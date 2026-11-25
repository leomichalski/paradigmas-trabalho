module FlowParserTest exposing (suite)

import Domain exposing (DomainError(..), NodeKind(..))
import Expect
import FlowParser exposing (FlowError(..))
import Test exposing (Test, describe, test)



-- EXEMPLO DO README


readmeExample : String
readmeExample =
    """graph TD
   start["FETCH: https://jsonplaceholder.typicode.com/posts/1"]
   summarize["PROMPT: Summarize the following JSON: {{input}}"]
   send["POST: https://httpbin.org/post"]
   abort["ABORT"]
   done["DONE"]

   start -->|fetch_succeeded| summarize
   start -->|fetch_failed| abort
   summarize -->|summary_generated| send
   summarize -->|generation_failed| abort
   send -->|request_succeeded| done
   send -->|request_failed| abort
"""



-- AJUDANTES


{-| Os números das linhas com erro de sintaxe, ou Nothing se o resultado
foi outra coisa.
-}
syntaxLines : String -> Maybe (List Int)
syntaxLines text =
    case FlowParser.toFlow text of
        Err (Syntax errors) ->
            Just (List.map .line errors)

        _ ->
            Nothing


domainErrors : String -> Maybe (List DomainError)
domainErrors text =
    case FlowParser.toFlow text of
        Err (Invalid errors) ->
            Just errors

        _ ->
            Nothing


nodeKinds : String -> Result FlowError (List NodeKind)
nodeKinds text =
    FlowParser.toFlow text
        |> Result.map (Domain.nodes >> List.map .kind)


counts : String -> Result FlowError ( Int, Int )
counts text =
    FlowParser.toFlow text
        |> Result.map (\flow -> ( List.length (Domain.nodes flow), List.length (Domain.edges flow) ))



-- TESTES


suite : Test
suite =
    describe "FlowParser.toFlow"
        [ validTests
        , syntaxTests
        , domainTests
        ]


validTests : Test
validTests =
    describe "textos válidos"
        [ test "exemplo do README: 5 nós e 6 ligações" <|
            \_ ->
                counts readmeExample
                    |> Expect.equal (Ok ( 5, 6 ))
        , test "os nós saem na ordem em que foram declarados" <|
            \_ ->
                FlowParser.toFlow readmeExample
                    |> Result.map (Domain.nodes >> List.map (.id >> Domain.idToString))
                    |> Expect.equal (Ok [ "start", "summarize", "send", "abort", "done" ])
        , test "ignora linhas vazias, `graph TD` e comentários %%" <|
            \_ ->
                counts "graph TD\n%% um comentário\n\na[\"DONE\"]\n"
                    |> Expect.equal (Ok ( 1, 0 ))
        , test "aceita fim de linha do Windows (\\r\\n)" <|
            \_ ->
                counts "a[\"DONE\"]\u{000D}\nb[\"ABORT\"]\u{000D}\na -->|ok| b"
                    |> Expect.equal (Ok ( 2, 1 ))
        , test "PROMPT pode ter dois-pontos no texto" <|
            \_ ->
                nodeKinds "p[\"PROMPT: Resuma: {{input}}\"]"
                    |> Expect.equal (Ok [ Prompt "Resuma: {{input}}" ])
        , test "ABORT e DONE não levam argumento" <|
            \_ ->
                nodeKinds "a[\"ABORT\"]\nb[\"DONE\"]"
                    |> Expect.equal (Ok [ Abort, Done ])
        , test "FETCH guarda a URL" <|
            \_ ->
                case ( FlowParser.toFlow "f[\"FETCH: https://x.com\"]", Domain.urlFromString "https://x.com" ) of
                    ( Ok flow, Ok url ) ->
                        Domain.nodes flow
                            |> List.map .kind
                            |> Expect.equal [ Fetch url ]

                    _ ->
                        Expect.fail "o fluxo ou a URL deveriam ser válidos"
        , test "tira os espaços em volta do evento" <|
            \_ ->
                FlowParser.toFlow "a[\"DONE\"]\nb[\"DONE\"]\na -->| fetch_ok | b"
                    |> Result.map (Domain.edges >> List.map (.event >> Domain.eventToString))
                    |> Expect.equal (Ok [ "fetch_ok" ])
        ]


syntaxTests : Test
syntaxTests =
    describe "erros de sintaxe (linha a linha)"
        [ test "informa o número da linha com problema" <|
            \_ ->
                syntaxLines "a[\"DONE\"]\nlixo\nb[\"DONE\"]"
                    |> Expect.equal (Just [ 2 ])
        , test "junta os erros de todas as linhas ruins" <|
            \_ ->
                syntaxLines "lixo\na[\"DONE\"]\nmais lixo"
                    |> Expect.equal (Just [ 1, 3 ])
        , test "o erro traz o texto da linha, sem espaços nas pontas" <|
            \_ ->
                case FlowParser.toFlow "a[\"DONE\"]\n   lixo   " of
                    Err (Syntax [ error ]) ->
                        Expect.equal ( 2, "lixo" ) ( error.line, error.source )

                    _ ->
                        Expect.fail "esperava um único erro de sintaxe"
        , test "id com hífen" <|
            \_ ->
                syntaxLines "a-b[\"DONE\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "ação desconhecida" <|
            \_ ->
                syntaxLines "x[\"FOO: bar\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "ABORT em minúsculas não é aceito" <|
            \_ ->
                syntaxLines "x[\"abort\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "FETCH sem http:// ou https://" <|
            \_ ->
                syntaxLines "f[\"FETCH: x.com\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "POST sem URL" <|
            \_ ->
                syntaxLines "p[\"POST:\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "PROMPT sem texto" <|
            \_ ->
                syntaxLines "p[\"PROMPT:\"]"
                    |> Expect.equal (Just [ 1 ])
        , test "ligação com evento vazio" <|
            \_ ->
                syntaxLines "a[\"DONE\"]\nb[\"DONE\"]\na -->|| b"
                    |> Expect.equal (Just [ 3 ])
        , test "erro de sintaxe vem antes de qualquer erro de domínio" <|
            \_ ->
                -- a está duplicado, mas a linha 3 é ilegível: só a sintaxe é reportada
                syntaxLines "a[\"DONE\"]\na[\"ABORT\"]\nlixo"
                    |> Expect.equal (Just [ 3 ])
        ]


domainTests : Test
domainTests =
    describe "erros de domínio (texto bem escrito, fluxo inválido)"
        [ test "texto vazio" <|
            \_ ->
                domainErrors ""
                    |> Expect.equal (Just [ EmptyFlow ])
        , test "só espaços e quebras de linha" <|
            \_ ->
                domainErrors "   \n  \n"
                    |> Expect.equal (Just [ EmptyFlow ])
        , test "nó declarado duas vezes" <|
            \_ ->
                case FlowParser.toFlow "a[\"DONE\"]\na[\"ABORT\"]" of
                    Err (Invalid [ DuplicateNode nodeId ]) ->
                        Expect.equal "a" (Domain.idToString nodeId)

                    _ ->
                        Expect.fail "esperava DuplicateNode a"
        , test "ligação para nó não declarado" <|
            \_ ->
                case FlowParser.toFlow "a[\"DONE\"]\na -->|ok| fantasma" of
                    Err (Invalid [ EdgeToUnknownNode { missing } ]) ->
                        Expect.equal "fantasma" (Domain.idToString missing)

                    _ ->
                        Expect.fail "esperava EdgeToUnknownNode fantasma"
        , test "ciclo entre dois nós" <|
            \_ ->
                case FlowParser.toFlow "a[\"FETCH: https://x.com\"]\nb[\"PROMPT: oi\"]\na -->|ok| b\nb -->|ok| a" of
                    Err (Invalid [ CycleDetected members ]) ->
                        List.map Domain.idToString members
                            |> Expect.equal [ "a", "b" ]

                    _ ->
                        Expect.fail "esperava CycleDetected [a, b]"
        ]
