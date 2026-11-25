module ReportView exposing (Config, view)

import Domain exposing (DomainError(..))
import FlowParser exposing (FlowError(..), ParseError)
import Html exposing (Html, button, div, h2, li, p, pre, section, strong, text, ul)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)
import PrologReport exposing (AnalysisState(..), Finding, FindingCode(..), Report, Suggestion)


type alias Config msg =
    { flow : Result FlowError Domain.Flow
    , analysis : AnalysisState
    , onAnalyze : msg
    , onUseDiagram : String -> msg
    }


view : Config msg -> Html msg
view config =
    section [ class "log" ]
        [ h2 [] [ text "Análise do fluxo" ]
        , viewLocalCheck config.flow
        , viewPrologCheck config
        ]
viewLocalCheck : Result FlowError Domain.Flow -> Html msg
viewLocalCheck flow =
    case flow of
        Ok validFlow ->
            p [ class "status status--completed" ]
                [ text
                    ("Fluxo válido: "
                        ++ String.fromInt (List.length (Domain.nodes validFlow))
                        ++ " nós, "
                        ++ String.fromInt (List.length (Domain.edges validFlow))
                        ++ " ligações, sem ciclos."
                    )
                ]

        Err (Syntax errors) ->
            viewProblems "Erros de sintaxe" (List.map describeParseError errors)

        Err (Invalid errors) ->
            viewProblems "Problemas no fluxo" (List.map describeDomainError errors)


viewProblems : String -> List String -> Html msg
viewProblems title problems =
    div [ class "alert", attribute "role" "alert" ]
        [ strong [] [ text title ]
        , ul [] (List.map (\problem -> li [] [ text problem ]) problems)
        ]


describeParseError : ParseError -> String
describeParseError error =
    "Linha " ++ String.fromInt error.line ++ ": " ++ error.message ++ "  →  " ++ error.source


describeDomainError : DomainError -> String
describeDomainError error =
    case error of
        EmptyFlow ->
            "O fluxo está vazio."

        DuplicateNode id ->
            "O nó \"" ++ Domain.idToString id ++ "\" foi declarado mais de uma vez."

        EdgeToUnknownNode { edge, missing } ->
            "A ligação "
                ++ Domain.idToString edge.from
                ++ " --> "
                ++ Domain.idToString edge.to
                ++ " usa o nó \""
                ++ Domain.idToString missing
                ++ "\", que não foi declarado."

        CycleDetected members ->
            "Há um ciclo envolvendo: " ++ String.join ", " (List.map Domain.idToString members) ++ "."
viewPrologCheck : Config msg -> Html msg
viewPrologCheck config =
    div []
        [ button
            [ type_ "button"
            , class "btn"
            , onClick config.onAnalyze
            , disabled (not (canAskProlog config.flow) || config.analysis == Analyzing)
            ]
            [ text "Consultar Prolog" ]
        , case config.analysis of
            AnalysisIdle ->
                text ""

            Analyzing ->
                p [] [ text "Consultando o Prolog..." ]

            AnalysisFailed message ->
                div [ class "alert", attribute "role" "alert" ]
                    [ text ("Não foi possível consultar o Prolog: " ++ message) ]

            AnalysisDone report ->
                viewReport config.onUseDiagram report
        ]


canAskProlog : Result FlowError Domain.Flow -> Bool
canAskProlog flow =
    case flow of
        Err (Syntax _) ->
            False

        _ ->
            True


viewReport : (String -> msg) -> Report -> Html msg
viewReport onUseDiagram report =
    div []
        [ if List.isEmpty report.findings then
            p [ class "status status--completed" ] [ text "O Prolog não encontrou problemas." ]

          else
            viewProblems "Problemas encontrados pelo Prolog" (List.map describeFinding report.findings)
        , viewSuggestions onUseDiagram report.suggestions
        ]


describeFinding : Finding -> String
describeFinding finding =
    let
        affected =
            if List.isEmpty finding.nodes then
                ""

            else
                " (" ++ String.join ", " finding.nodes ++ ")"
    in
    codeLabel finding.code ++ ": " ++ finding.message ++ affected


codeLabel : FindingCode -> String
codeLabel code =
    case code of
        Cycle ->
            "Ciclo"

        UnreachableNode ->
            "Nó inalcançável"

        InvalidLink ->
            "Ligação inválida"

        Other raw ->
            raw


viewSuggestions : (String -> msg) -> List Suggestion -> Html msg
viewSuggestions onUseDiagram suggestions =
    if List.isEmpty suggestions then
        text ""

    else
        div []
            [ strong [] [ text "Sugestões" ]
            , ul [] (List.map (viewSuggestion onUseDiagram) suggestions)
            ]


viewSuggestion : (String -> msg) -> Suggestion -> Html msg
viewSuggestion onUseDiagram suggestion =
    li []
        ([ strong [] [ text suggestion.title ]
         , p [] [ text suggestion.message ]
         ]
            ++ (case suggestion.diagram of
                    Just diagram ->
                        [ pre [ class "entry__output" ] [ text diagram ]
                        , button
                            [ type_ "button"
                            , class "btn btn--quiet"
                            , onClick (onUseDiagram diagram)
                            ]
                            [ text "Usar este fluxo" ]
                        ]

                    Nothing ->
                        []
               )
        )
