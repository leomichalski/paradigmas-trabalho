module View exposing (view)

import Html exposing (Html, div, text, textarea, input, button, h1, h2, h3, pre, p, span)
import Html.Attributes exposing (placeholder, value, style, class, type_)
import Html.Events exposing (onInput, onClick)
import Types exposing (..)

isError : Result e a -> Bool
isError res =
    case res of
        Err _ -> True
        Ok _ -> False

view : Model -> Html Msg
view model =
    div [ style "max-width" "800px", style "margin" "0 auto" ]
        [ h1 [] [ text "ProspectFlow MVP" ]
        , viewInputs model
        , viewButtons model
        , viewExecutionLog model
        ]

viewInputs : Model -> Html Msg
viewInputs model =
    div [ style "display" "flex", style "flex-direction" "column", style "gap" "10px" ]
        [ div []
            [ h3 [] [ text "API Key (OpenAI)" ]
            , input
                [ type_ "password"
                , placeholder "sk-..."
                , value model.apiKey
                , onInput UpdateApiKey
                , style "width" "100%"
                ] []
            ]
        , div []
            [ h3 [] [ text "Mermaid Workflow Definition" ]
            , textarea
                [ placeholder "Node1[FETCH: https://...] --> Node2[PROMPT: Summarize {{input}}]"
                , value model.workflowText
                , onInput UpdateWorkflowText
                , style "width" "100%"
                , style "height" "100px"
                ] []
            ]
        , div []
            [ h3 [] [ text "Trigger Input" ]
            , textarea
                [ placeholder "Initial data or trigger text..."
                , value model.triggerInput
                , onInput UpdateTriggerInput
                , style "width" "100%"
                , style "height" "60px"
                ] []
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
                        hasPrompt = List.any (\n -> n.actionType == Prompt) nodes
                    in
                    hasPrompt && String.isEmpty (String.trim model.apiKey)
    in
    div [ style "margin-top" "20px", style "display" "flex", style "gap" "10px", style "align-items" "center" ]
        [ button [ onClick SaveAgent ] [ text "Save Agent" ]
        , button
            [ onClick RunAgent
            , Html.Attributes.disabled runDisabled
            ] [ text "Run Agent" ]
        , if runDisabled && not (isError model.parsedPipeline) then
            span [ style "color" "red", style "font-size" "0.9em" ] [ text "API Key required for PROMPT nodes." ]
          else
            text ""
        ]

viewExecutionLog : Model -> Html Msg
viewExecutionLog model =
    let
        stateText =
            case model.executionState of
                Idle -> "Idle"
                Running state -> "Running... Step " ++ String.fromInt (state.stepIndex + 1)
                Completed _ -> "Completed!"
                Failed state -> "Failed: " ++ state.error
        
        logs =
            case model.executionState of
                Idle -> []
                Running state -> state.logs
                Completed state -> state.logs
                Failed state -> state.logs
    in
    div [ style "margin-top" "30px", style "border-top" "1px solid #ccc", style "padding-top" "20px" ]
        [ h2 [] [ text "Execution Status: ", text stateText ]
        , div [] (List.map viewLogEntry logs)
        ]

viewLogEntry : LogEntry -> Html Msg
viewLogEntry entry =
    div
        [ style "border" "1px solid #eee"
        , style "padding" "10px"
        , style "margin-bottom" "10px"
        , style "background" "#fff"
        ]
        [ p [ style "font-weight" "bold", style "margin" "0 0 10px 0" ]
            [ text ("[" ++ entry.stepId ++ " | " ++ entry.actionName ++ "]") ]
        , pre
            [ style "white-space" "pre-wrap"
            , style "background" "#f8f9fa"
            , style "padding" "10px"
            , style "margin" "0"
            ]
            [ text entry.output ]
        ]
