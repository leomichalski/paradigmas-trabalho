port module Main exposing (main)

import Browser
import Engine
import Types exposing (..)
import AppParser exposing (parsePipeline)
import View exposing (view)
import Translations exposing (Language(..), TextId(..))
port saveApiKey : String -> Cmd msg

main : Program String Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
init : String -> ( Model, Cmd Msg )
init savedApiKey =
    ( { language = Pt
      , workflowText = ""
      , triggerInput = ""
      , apiKey = savedApiKey
      , parsedPipeline = Err "No workflow defined."
      , executionState = Idle
      , mermaidError = Nothing
      }
    , Cmd.none
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateWorkflowText txt ->
            ( { model | workflowText = txt, mermaidError = Nothing }, Cmd.none )

        UpdateTriggerInput txt ->
            ( { model | triggerInput = txt }, Cmd.none )

        UpdateApiKey txt ->
            ( { model | apiKey = txt }, saveApiKey txt )

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

        GotMermaidError err ->
            ( { model | mermaidError = Just err }, Cmd.none )

        GotMermaidSuccess ->
            ( { model | mermaidError = Nothing }, Cmd.none )
            
        ToggleLanguage ->
            let
                newLang =
                    if model.language == Pt then
                        En
                    else
                        Pt
            in
            ( { model | language = newLang }, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none