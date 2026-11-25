port module Main exposing (main)

import Browser
import Api
import Http
import Types exposing (..)
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

        RunAgent ->
            ( { model | executionState = Running }
            , Api.runAgent
                { diagram = model.workflowText
                , triggerInput = model.triggerInput
                , apiKey = model.apiKey
                }
            )

        GotExecutionResult (Ok response) ->
            if response.status == "success" then
                ( { model | executionState = Completed { message = response.message, logs = response.logs } }
                , Cmd.none
                )

            else
                ( { model | executionState = Failed { error = response.message, logs = response.logs } }
                , Cmd.none
                )

        GotExecutionResult (Err httpErr) ->
            ( { model | executionState = Failed { error = httpErrorToString httpErr, logs = "" } }
            , Cmd.none
            )

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

httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Network Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus 401 ->
            "Unauthorized: Please check your API Key."

        Http.BadStatus status ->
            "Bad Status: " ++ String.fromInt status

        Http.BadBody bodyErr ->
            "Bad Body: " ++ bodyErr


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none