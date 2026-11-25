module DomainTest exposing (suite)

import Domain exposing (DomainError(..), Edge, Node, NodeId, NodeKind(..))
import Expect exposing (Expectation)
import Test exposing (Test, describe, test)



-- AJUDANTES
--
-- NodeId, Event e Url são tipos opacos: só se criam por idFromString,
-- eventFromString e urlFromString. Nos testes usamos valores que sabemos
-- serem válidos; se algum deixar de ser, o teste quebra com uma mensagem clara.


id : String -> NodeId
id raw =
    case Domain.idFromString raw of
        Ok nodeId ->
            nodeId

        Err message ->
            Debug.todo ("id de teste inválido: " ++ message)


node : String -> NodeKind -> Node
node raw kind =
    { id = id raw, kind = kind }


edge : String -> String -> String -> Edge
edge from event to =
    case Domain.eventFromString event of
        Ok validEvent ->
            { from = id from, event = validEvent, to = id to }

        Err message ->
            Debug.todo ("evento de teste inválido: " ++ message)


expectErr : Result e a -> Expectation
expectErr result =
    case result of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "esperava Err, mas veio Ok"


counts : Result e Domain.Flow -> Result e ( Int, Int )
counts =
    Result.map (\flow -> ( List.length (Domain.nodes flow), List.length (Domain.edges flow) ))



-- TESTES


suite : Test
suite =
    describe "Domain"
        [ idTests
        , eventTests
        , urlTests
        , flowTests
        , cycleTests
        ]


idTests : Test
idTests =
    describe "idFromString"
        [ test "aceita letras, números e _" <|
            \_ ->
                Domain.idFromString "passo_1"
                    |> Result.map Domain.idToString
                    |> Expect.equal (Ok "passo_1")
        , describe "recusa"
            ([ "", "a-b", "a b", "a.b" ]
                |> List.map
                    (\raw ->
                        test ("\"" ++ raw ++ "\"") <|
                            \_ -> expectErr (Domain.idFromString raw)
                    )
            )
        ]


eventTests : Test
eventTests =
    describe "eventFromString"
        [ test "tira os espaços das pontas" <|
            \_ ->
                Domain.eventFromString "  fetch_succeeded  "
                    |> Result.map Domain.eventToString
                    |> Expect.equal (Ok "fetch_succeeded")
        , test "recusa texto vazio" <|
            \_ -> expectErr (Domain.eventFromString "")
        , test "recusa só espaços" <|
            \_ -> expectErr (Domain.eventFromString "   ")
        ]


urlTests : Test
urlTests =
    describe "urlFromString"
        [ test "aceita https e tira os espaços das pontas" <|
            \_ ->
                Domain.urlFromString "  https://example.com/a  "
                    |> Result.map Domain.urlToString
                    |> Expect.equal (Ok "https://example.com/a")
        , test "aceita http" <|
            \_ ->
                Domain.urlFromString "http://localhost:8000"
                    |> Result.map Domain.urlToString
                    |> Expect.equal (Ok "http://localhost:8000")
        , describe "recusa"
            ([ "", "example.com", "ftp://example.com", "http://", "https://" ]
                |> List.map
                    (\raw ->
                        test ("\"" ++ raw ++ "\"") <|
                            \_ -> expectErr (Domain.urlFromString raw)
                    )
            )
        ]


flowTests : Test
flowTests =
    describe "flowFromParts"
        [ test "fluxo sem nós é recusado" <|
            \_ ->
                Domain.flowFromParts [] []
                    |> Expect.equal (Err [ EmptyFlow ])
        , test "fluxo válido guarda os nós e as ligações" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done, node "b" Abort ]
                    [ edge "a" "ok" "b" ]
                    |> counts
                    |> Expect.equal (Ok ( 2, 1 ))
        , test "nó declarado duas vezes" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done, node "a" Abort ]
                    []
                    |> Expect.equal (Err [ DuplicateNode (id "a") ])
        , test "ligação para nó que não existe" <|
            \_ ->
                let
                    broken =
                        edge "a" "ok" "fantasma"
                in
                Domain.flowFromParts [ node "a" Done ] [ broken ]
                    |> Expect.equal
                        (Err [ EdgeToUnknownNode { edge = broken, missing = id "fantasma" } ])
        , test "os dois lados desconhecidos geram dois erros, origem primeiro" <|
            \_ ->
                let
                    broken =
                        edge "x" "ok" "y"
                in
                Domain.flowFromParts [ node "a" Done ] [ broken ]
                    |> Expect.equal
                        (Err
                            [ EdgeToUnknownNode { edge = broken, missing = id "x" }
                            , EdgeToUnknownNode { edge = broken, missing = id "y" }
                            ]
                        )
        ]


cycleTests : Test
cycleTests =
    describe "ciclos"
        [ test "a -> b -> a" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done, node "b" Done ]
                    [ edge "a" "ok" "b", edge "b" "ok" "a" ]
                    |> Expect.equal (Err [ CycleDetected [ id "a", id "b" ] ])
        , test "nó que aponta para si mesmo" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done ]
                    [ edge "a" "ok" "a" ]
                    |> Expect.equal (Err [ CycleDetected [ id "a" ] ])
        , test "nó de entrada que alimenta o ciclo não é listado" <|
            \_ ->
                Domain.flowFromParts
                    [ node "s" Done, node "a" Done, node "b" Done ]
                    [ edge "s" "ok" "a", edge "a" "ok" "b", edge "b" "ok" "a" ]
                    |> Expect.equal (Err [ CycleDetected [ id "a", id "b" ] ])
        , test "losango (dois caminhos até o mesmo nó) não é ciclo" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done, node "b" Done, node "c" Done, node "d" Done ]
                    [ edge "a" "x" "b", edge "a" "y" "c", edge "b" "ok" "d", edge "c" "ok" "d" ]
                    |> counts
                    |> Expect.equal (Ok ( 4, 4 ))
        , test "duas ligações entre os mesmos nós não são ciclo" <|
            \_ ->
                Domain.flowFromParts
                    [ node "a" Done, node "b" Done ]
                    [ edge "a" "x" "b", edge "a" "y" "b" ]
                    |> counts
                    |> Expect.equal (Ok ( 2, 2 ))
        ]
