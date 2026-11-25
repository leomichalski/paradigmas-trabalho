module Types exposing (..)

import Http
import Translations exposing (Language)


type alias ExecutionResponse =
    { status : String
    , message : String
    , logs : String
    }


type ExecutionState
    = Idle
    | Running
    | Completed { message : String, logs : String }
    | Failed { error : String, logs : String }


type alias Model =
    { language : Language
    , workflowText : String
    , triggerInput : String
    , apiKey : String
    , executionState : ExecutionState
    , mermaidError : Maybe String
    }


type Msg
    = UpdateWorkflowText String
    | UpdateTriggerInput String
    | UpdateApiKey String
    | RunAgent
    | GotExecutionResult (Result Http.Error ExecutionResponse)
    | GotMermaidError String
    | GotMermaidSuccess
    | ToggleLanguage
