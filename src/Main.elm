module Main exposing (main)

import Browser
import Types exposing (..)
import AppParser exposing (parsePipeline)
import Engine exposing (startExecution, handleNodeResult)
import View exposing (view)

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

init : () -> ( Model, Cmd Msg )
init _ =
    ( { workflowText = ""
      , triggerInput = ""
      , apiKey = ""
      , parsedPipeline = Err "No workflow defined."
      , executionState = Idle
      }
    , Cmd.none
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateWorkflowText txt ->
            ( { model | workflowText = txt }, Cmd.none )

        UpdateTriggerInput txt ->
            ( { model | triggerInput = txt }, Cmd.none )

        UpdateApiKey txt ->
            ( { model | apiKey = txt }, Cmd.none )

        SaveAgent ->
            let
                parsed =
                    parsePipeline model.workflowText
            in
            ( { model | parsedPipeline = parsed }, Cmd.none )

        RunAgent ->
            Engine.startExecution model

        GotNodeResult res ->
            Engine.handleNodeResult model res

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
