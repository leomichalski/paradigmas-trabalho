module Types exposing (..)

import Http
import File exposing (File)
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


{-| Fluxos salvos no Prolog (armazenamento.pl).

A lista só existe depois que a resposta chega: não dá para mostrar
uma lista "carregando" e "com erro" ao mesmo tempo.

-}
type SavedFlows
    = LoadingFlows
    | LoadedFlows (List String)
    | FlowsFailed String


{-| Mostrar todos os fluxos ou só os que usam um tipo de nó.
O filtro por tipo vira a consulta fluxos\_com\_tipo/2 no Prolog.
-}
type FlowFilter
    = AllFlows
    | UsingNode NodeType


type NodeType
    = FetchNode
    | PromptNode
    | PostNode
    | AbortNode
    | DoneNode


{-| O que aconteceu com a última ação de salvar, abrir ou apagar. -}
type StorageStatus
    = NoStorageStatus
    | StorageBusy
    | StorageDone StorageAction String
    | StorageFailed String


type StorageAction
    = FlowSaved
    | FlowOpened
    | FlowDeleted


type alias Model =
    { language : Language
    , workflowText : String
    , triggerInput : String
    , videoFile : Maybe File
    , apiKey : String
    , executionState : ExecutionState
    , mermaidError : Maybe String
    , flowName : String
    , savedFlows : SavedFlows
    , flowFilter : FlowFilter
    , storageStatus : StorageStatus
    }


type Msg
    = UpdateWorkflowText String
    | UpdateTriggerInput String
    | SelectVideo
    | VideoSelected File
    | UpdateApiKey String
    | RunAgent
    | GotExecutionResult (Result Http.Error ExecutionResponse)
    | GotMermaidError String
    | GotMermaidSuccess
    | ToggleLanguage
      -- armazenamento de fluxos
    | UpdateFlowName String
    | ChangeFlowFilter FlowFilter
    | SaveFlow
    | OpenFlow String
    | DeleteFlow String
    | GotFlowList (Result Http.Error (List String))
    | GotSaveResult String (Result Http.Error ())
    | GotOpenResult String (Result Http.Error String)
    | GotDeleteResult String (Result Http.Error ())
