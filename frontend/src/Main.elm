port module Main exposing (main)

import Browser
import Api
import StorageApi
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
      , flowName = ""
      , savedFlows = LoadingFlows
      , flowFilter = AllFlows
      , storageStatus = NoStorageStatus
      }
    , StorageApi.listFlows AllFlows
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

        -- armazenamento de fluxos
        UpdateFlowName name ->
            ( { model | flowName = name }, Cmd.none )

        ChangeFlowFilter filter ->
            ( { model | flowFilter = filter, savedFlows = LoadingFlows }
            , StorageApi.listFlows filter
            )

        SaveFlow ->
            ( { model | storageStatus = StorageBusy }
            , StorageApi.saveFlow (String.trim model.flowName)
                { diagram = model.workflowText, trigger = model.triggerInput }
            )

        OpenFlow name ->
            ( { model | storageStatus = StorageBusy }, StorageApi.openFlow name )

        DeleteFlow name ->
            ( { model | storageStatus = StorageBusy }, StorageApi.deleteFlow name )

        GotFlowList (Ok names) ->
            ( { model | savedFlows = LoadedFlows names }, Cmd.none )

        GotFlowList (Err httpErr) ->
            ( { model | savedFlows = FlowsFailed (httpErrorToString httpErr) }, Cmd.none )

        GotSaveResult name (Ok ()) ->
            ( { model | storageStatus = StorageDone FlowSaved name }
            , StorageApi.listFlows model.flowFilter
            )

        GotOpenResult name (Ok saved) ->
            ( { model
                | workflowText = saved.diagram
                , triggerInput = saved.trigger
                , flowName = name
                , mermaidError = Nothing
                , storageStatus = StorageDone FlowOpened name
              }
            , Cmd.none
            )

        GotDeleteResult name (Ok ()) ->
            ( { model | storageStatus = StorageDone FlowDeleted name }
            , StorageApi.listFlows model.flowFilter
            )

        GotSaveResult _ (Err httpErr) ->
            ( { model | storageStatus = StorageFailed (httpErrorToString httpErr) }, Cmd.none )

        GotOpenResult _ (Err httpErr) ->
            ( { model | storageStatus = StorageFailed (httpErrorToString httpErr) }, Cmd.none )

        GotDeleteResult _ (Err httpErr) ->
            ( { model | storageStatus = StorageFailed (httpErrorToString httpErr) }, Cmd.none )

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