module View exposing (view)

import Html exposing (Html, button, div, h1, h2, input, label, li, main_, ol, p, pre, section, span, text, textarea)
import Html.Attributes exposing (attribute, class, disabled, for, id, placeholder, type_, value)
import Html.Events exposing (on, onClick, onInput)
import Html.Keyed
import Json.Decode as Decode
import StorageView exposing (viewStorage)
import Types exposing (..)
import Translations exposing (Language(..), TextId(..), translate)


-- isError : Result e a -> Bool
-- isError res =
--     case res of
--         Err _ ->
--             True

--         Ok _ ->
--             False


view : Model -> Html Msg
view model =
    main_ [ class "app" ]
        [ 
          div [ class "actions", attribute "style" "margin-bottom: 2rem; justify-content: flex-end;" ]
            [ button [ class "btn btn--quiet", onClick ToggleLanguage ]
                [ text (translate model.language LanguageToggle) ]
            ]
        , h1 [ class "app__title" ] [ text (translate model.language AppTitle) ]
        , viewInputs model
        , viewButtons model
        , viewExecutionLog model
        , viewStorage model
        ]


viewMermaidError : Model -> Html Msg
viewMermaidError model =
    case model.mermaidError of
        Just err ->
            div [ class "alert", attribute "role" "alert" ]
                [ text (translate model.language MermaidErrorPrefix ++ err) ]

        Nothing ->
            text ""


viewMermaid : String -> Html Msg
viewMermaid workflowText =
    let
        mermaidText =
            workflowText

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
            [ label [ for "api-key" ] [ text (translate model.language ApiKeyLabel) ]
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
            [ label [ for "workflow-text" ] [ text (translate model.language WorkflowLabel) ]
            , textarea
                [ id "workflow-text"
                , placeholder (translate model.language TriggerPlaceholder)
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
            [ label [ for "trigger-input" ] [ text (translate model.language TriggerLabel) ]
            , textarea
                [ id "trigger-input"
                , placeholder (translate model.language TriggerPlaceholder)
                , value model.triggerInput
                , onInput UpdateTriggerInput
                ]
                []
            ]
        ]


viewButtons : Model -> Html Msg
viewButtons model =
    let
        isRunning =
            model.executionState == Running

        needsApiKey =
            String.contains "PROMPT:" model.workflowText
                && String.isEmpty (String.trim model.apiKey)

        runDisabled =
            isRunning
                || String.isEmpty (String.trim model.workflowText)
                || needsApiKey
    in
    div [ class "actions" ]
        [ button
            [ type_ "button"
            , class "btn"
            , onClick RunAgent
            , disabled runDisabled
            ]
            [ text (translate model.language RunAgentBtn) ]
        ]


viewExecutionLog : Model -> Html Msg
viewExecutionLog model =
    let
        ( stateText, stateClass ) =
            case model.executionState of
                Idle ->
                    ( translate model.language StatusIdle, "idle" )

                Running ->
                    ( translate model.language StatusRunning, "running" )

                Completed _ ->
                    ( translate model.language StatusCompleted, "completed" )

                Failed state ->
                    ( translate model.language StatusFailed ++ state.error, "failed" )

        logs =
            case model.executionState of
                Idle ->
                    ""

                Running ->
                    ""

                Completed state ->
                    state.logs

                Failed state ->
                    state.logs
    in
    section [ class "log" ]
        [ h2 []
            [ text (translate model.language ExecutionStatus)
            , span [ class ("status status--" ++ stateClass) ] [ text stateText ]
            ]
        , if String.isEmpty (String.trim logs) then
            text ""

          else
            pre [ class "entry__output" ] [ text logs ]
        ]
