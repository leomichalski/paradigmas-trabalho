module View exposing (view)

import Html exposing (Html, button, div, h1, h2, input, label, li, main_, ol, p, pre, section, span, text, textarea)
import Html.Attributes exposing (attribute, class, disabled, for, id, placeholder, type_, value)
import Html.Events exposing (on, onClick, onInput)
import Html.Keyed
import Json.Decode as Decode
import Types exposing (..)


isError : Result e a -> Bool
isError res =
    case res of
        Err _ ->
            True

        Ok _ ->
            False


view : Model -> Html Msg
view model =
    main_ [ class "app" ]
        [ h1 [ class "app__title" ] [ text "ProspectFlow MVP" ]
        , viewInputs model
        , viewButtons model
        , viewExecutionLog model
        ]


viewMermaidError : Model -> Html Msg
viewMermaidError model =
    case model.mermaidError of
        Just err ->
            div [ class "alert", attribute "role" "alert" ]
                [ text ("Mermaid Error: " ++ err) ]

        Nothing ->
            text ""


viewMermaid : String -> Html Msg
viewMermaid workflowText =
    let
        mermaidText =
            "graph TD\n" ++ workflowText

        errorDecoder =
            Decode.at [ "detail", "error", "message" ] Decode.string
                |> Decode.map GotMermaidError

        renderDecoder =
            Decode.succeed GotMermaidSuccess
    in
    Html.Keyed.node "div"
        [ class "preview" ]
        [ ( mermaidText
          , Html.node "mermaid-element"
                [ on "error" errorDecoder
                , on "render" renderDecoder
                ]
                [ pre [] [ Html.node "code" [] [ text mermaidText ] ] ]
          )
        ]


viewInputs : Model -> Html Msg
viewInputs model =
    div [ class "inputs" ]
        [ div [ class "field" ]
            [ label [ for "api-key" ] [ text "API Key (OpenAI)" ]
            , input
                [ id "api-key"
                , type_ "password"
                , placeholder "sk-..."
                , value model.apiKey
                , onInput UpdateApiKey
                ]
                []
            ]
        , div [ class "field" ]
            [ label [ for "workflow-text" ] [ text "Mermaid Workflow Definition" ]
            , textarea
                [ id "workflow-text"
                , placeholder "Node1[\"FETCH: https://...\"] --> Node2[\"PROMPT: Summarize {{input}}\"]"
                , value model.workflowText
                , onInput UpdateWorkflowText
                ]
                []
            , viewMermaidError model
            , if String.isEmpty (String.trim model.workflowText) then
                text ""

              else
                viewMermaid model.workflowText
            ]
        , div [ class "field" ]
            [ label [ for "trigger-input" ] [ text "Trigger Input" ]
            , textarea
                [ id "trigger-input"
                , placeholder "Initial data or trigger text..."
                , value model.triggerInput
                , onInput UpdateTriggerInput
                ]
                []
            ]
        ]


viewButtons : Model -> Html Msg
viewButtons model =
    let
        runDisabled =
            case model.parsedPipeline of
                Err _ ->
                    True

                Ok nodes ->
                    let
                        hasPrompt =
                            List.any (\n -> n.actionType == Prompt) nodes
                    in
                    hasPrompt && String.isEmpty (String.trim model.apiKey)
    in
    div [ class "actions" ]
        [ button [ type_ "button", class "btn btn--quiet", onClick SaveAgent ]
            [ text "Save Agent" ]
        , button
            [ type_ "button"
            , class "btn"
            , onClick RunAgent
            , disabled runDisabled
            ]
            [ text "Run Agent" ]
        , if runDisabled && not (isError model.parsedPipeline) then
            span [ class "actions__note" ] [ text "API Key required for PROMPT nodes." ]

          else
            text ""
        ]


viewExecutionLog : Model -> Html Msg
viewExecutionLog model =
    let
        ( stateText, stateClass ) =
            case model.executionState of
                Idle ->
                    ( "Idle", "idle" )

                Running state ->
                    ( "Running... Step " ++ String.fromInt (state.stepIndex + 1), "running" )

                Completed _ ->
                    ( "Completed!", "completed" )

                Failed state ->
                    ( "Failed: " ++ state.error, "failed" )

        logs =
            case model.executionState of
                Idle ->
                    []

                Running state ->
                    state.logs

                Completed state ->
                    state.logs

                Failed state ->
                    state.logs
    in
    section [ class "log" ]
        [ h2 []
            [ text "Execution Status: "
            , span [ class ("status status--" ++ stateClass) ] [ text stateText ]
            ]
        , ol [ class "log__entries" ] (List.map viewLogEntry logs)
        ]


viewLogEntry : LogEntry -> Html Msg
viewLogEntry entry =
    li [ class "entry" ]
        [ p [ class "entry__head" ]
            [ span [ class ("tag tag--" ++ String.toLower entry.actionName) ]
                [ text entry.actionName ]
            , span [ class "entry__step" ] [ text entry.stepId ]
            ]
        , pre [ class "entry__output" ] [ text entry.output ]
        ]