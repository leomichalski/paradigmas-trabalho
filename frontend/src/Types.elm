module Types exposing (..)

import Http
import Translations exposing (Language)

type ActionType
    = Fetch
    | Prompt
    | Post

type alias PipelineNode =
    { id : String
    , actionType : ActionType
    , payload : String
    }

type alias LogEntry =
    { stepId : String
    , actionName : String
    , output : String
    }

type ExecutionState
    = Idle
    | Running { stepIndex : Int, latestOutput : String, logs : List LogEntry }
    | Completed { logs : List LogEntry }
    | Failed { error : String, logs : List LogEntry }

type alias Model =
    { language : Language
    , workflowText : String
    , triggerInput : String
    , apiKey : String
    , parsedPipeline : Result String (List PipelineNode)
    , executionState : ExecutionState
    , mermaidError : Maybe String
    }

type Msg
    = UpdateWorkflowText String
    | UpdateTriggerInput String
    | UpdateApiKey String
    | SaveAgent
    | RunAgent
    | GotNodeResult NodeResult
    | GotMermaidError String
    | GotMermaidSuccess
    | ToggleLanguage

type alias NodeResult = Result Http.Error String