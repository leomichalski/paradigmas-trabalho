module Translations exposing (Language(..), TextId(..), translate)

type Language
    = Pt
    | En

type TextId
    = AppTitle
    | ProviderLabel
    | ApiKeyLabel
    | WorkflowLabel
    | TriggerLabel
    | TriggerPlaceholder
    | RunAgentBtn
    | ApiKeyRequiredNote
    | StatusIdle
    | StatusRunning
    | StatusCompleted
    | StatusFailed
    | ExecutionStatus
    | LanguageToggle
    | MermaidErrorPrefix
      -- armazenamento de fluxos
    | SavedFlowsTitle
    | FlowNameLabel
    | FlowNamePlaceholder
    | SaveFlowBtn
    | UpdateFlowBtn
    | OpenFlowBtn
    | DeleteFlowBtn
    | FilterLabel
    | FilterAll
    | FilterUsing
    | LoadingFlowsText
    | NoSavedFlows
    | FlowsLoadError
    | StorageBusyText
    | FlowSavedMsg
    | FlowOpenedMsg
    | FlowDeletedMsg
    | StorageErrorPrefix

translate : Language -> TextId -> String
translate lang textId =
    case ( lang, textId ) of
        ( Pt, AppTitle ) -> "Editor de Fluxos"  
        ( En, AppTitle ) -> "ProspectFlow MVP"

        ( Pt, ProviderLabel ) -> "Provedor de LLM"
        ( En, ProviderLabel ) -> "LLM Provider"

        ( Pt, ApiKeyLabel ) -> "Chave de API"
        ( En, ApiKeyLabel ) -> "API Key"

        ( Pt, WorkflowLabel ) -> "Definição do Fluxo (Mermaid)"
        ( En, WorkflowLabel ) -> "Mermaid Workflow Definition"

        ( Pt, TriggerLabel ) -> "Dado Inicial (Gatilho)"
        ( En, TriggerLabel ) -> "Trigger Input"

        ( Pt, TriggerPlaceholder ) -> "Dado inicial ou texto de gatilho..."
        ( En, TriggerPlaceholder ) -> "Initial data or trigger text..."

        ( Pt, RunAgentBtn ) -> "Executar Agente"
        ( En, RunAgentBtn ) -> "Run Agent"

        ( Pt, ApiKeyRequiredNote ) -> "Chave de API necessária para nós do tipo PROMPT."
        ( En, ApiKeyRequiredNote ) -> "API Key required for PROMPT nodes."

        ( Pt, StatusIdle ) -> "Ocioso"
        ( En, StatusIdle ) -> "Idle"

        ( Pt, StatusRunning ) -> "Executando..."
        ( En, StatusRunning ) -> "Running..."

        ( Pt, StatusCompleted ) -> "Concluído!"
        ( En, StatusCompleted ) -> "Completed!"

        ( Pt, StatusFailed ) -> "Falhou: "
        ( En, StatusFailed ) -> "Failed: "

        ( Pt, ExecutionStatus ) -> "Status de Execução: "
        ( En, ExecutionStatus ) -> "Execution Status: "

        ( Pt, LanguageToggle ) -> "Change to English"
        ( En, LanguageToggle ) -> "Mudar para Português"

        ( Pt, MermaidErrorPrefix ) -> "Erro no Mermaid: "
        ( En, MermaidErrorPrefix ) -> "Mermaid Error: "

        -- armazenamento de fluxos
        ( Pt, SavedFlowsTitle ) -> "Fluxos salvos"
        ( En, SavedFlowsTitle ) -> "Saved flows"

        ( Pt, FlowNameLabel ) -> "Nome do fluxo"
        ( En, FlowNameLabel ) -> "Flow name"

        ( Pt, FlowNamePlaceholder ) -> "ex.: resumo de notícias"
        ( En, FlowNamePlaceholder ) -> "e.g. news summary"

        ( Pt, SaveFlowBtn ) -> "Salvar fluxo"
        ( En, SaveFlowBtn ) -> "Save flow"

        ( Pt, UpdateFlowBtn ) -> "Atualizar fluxo salvo"
        ( En, UpdateFlowBtn ) -> "Update saved flow"

        ( Pt, OpenFlowBtn ) -> "Abrir"
        ( En, OpenFlowBtn ) -> "Open"

        ( Pt, DeleteFlowBtn ) -> "Apagar"
        ( En, DeleteFlowBtn ) -> "Delete"

        ( Pt, FilterLabel ) -> "Mostrar"
        ( En, FilterLabel ) -> "Show"

        ( Pt, FilterAll ) -> "Todos os fluxos"
        ( En, FilterAll ) -> "All flows"

        ( Pt, FilterUsing ) -> "Fluxos que usam "
        ( En, FilterUsing ) -> "Flows using "

        ( Pt, LoadingFlowsText ) -> "Carregando fluxos..."
        ( En, LoadingFlowsText ) -> "Loading flows..."

        ( Pt, NoSavedFlows ) -> "Nenhum fluxo encontrado."
        ( En, NoSavedFlows ) -> "No flows found."

        ( Pt, FlowsLoadError ) -> "Não foi possível carregar os fluxos: "
        ( En, FlowsLoadError ) -> "Could not load flows: "

        ( Pt, StorageBusyText ) -> "Aguarde..."
        ( En, StorageBusyText ) -> "Please wait..."

        ( Pt, FlowSavedMsg ) -> "Fluxo salvo: "
        ( En, FlowSavedMsg ) -> "Flow saved: "

        ( Pt, FlowOpenedMsg ) -> "Fluxo aberto no editor: "
        ( En, FlowOpenedMsg ) -> "Flow opened in the editor: "

        ( Pt, FlowDeletedMsg ) -> "Fluxo apagado: "
        ( En, FlowDeletedMsg ) -> "Flow deleted: "

        ( Pt, StorageErrorPrefix ) -> "Erro no armazenamento: "
        ( En, StorageErrorPrefix ) -> "Storage error: "
