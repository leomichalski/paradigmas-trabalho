module Types exposing (..)

import ApiError exposing (ApiError)
import Translations exposing (Language)


type alias ExecutionResponse =
    { outcome : ExecutionOutcome
    , message : String
    , logs : String
    }


{-| O campo `status` da resposta de `/execute`, já convertido.

Qualquer valor diferente de `"success"` vira `NotSucceeded` e guarda o texto
original, para a tela poder mostrá-lo.

-}
type ExecutionOutcome
    = Succeeded
    | NotSucceeded String


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


{-| Um fluxo salvo: o diagrama e o dado inicial (gatilho), que pode ser "". -}
type alias SavedFlow =
    { diagram : String
    , trigger : String
    }


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
    | UpdateApiKey String
    | RunAgent
    | GotExecutionResult (Result ApiError ExecutionResponse)
    | GotMermaidError String
    | GotMermaidSuccess
    | ToggleLanguage
      -- armazenamento de fluxos
    | UpdateFlowName String
    | ChangeFlowFilter FlowFilter
    | SaveFlow
    | OpenFlow String
    | DeleteFlow String
    | GotFlowList (Result ApiError (List String))
    | GotSaveResult String (Result ApiError ())
    | GotOpenResult String (Result ApiError SavedFlow)
    | GotDeleteResult String (Result ApiError ())
