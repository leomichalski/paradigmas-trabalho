module Translations exposing (Language(..), TextId(..), translate)

type Language
    = Pt
    | En

type TextId
    = AppTitle
    | ApiKeyLabel
    | WorkflowLabel
    | TriggerLabel
    | TriggerPlaceholder
    | SaveAgentBtn
    | RunAgentBtn
    | ApiKeyRequiredNote
    | StatusIdle
    | StatusRunning
    | StatusCompleted
    | StatusFailed
    | ExecutionStatus
    | LanguageToggle
    | MermaidErrorPrefix

translate : Language -> TextId -> String
translate lang textId =
    case ( lang, textId ) of
        ( Pt, AppTitle ) -> "Editor de Fluxos"  
        ( En, AppTitle ) -> "ProspectFlow MVP"

        ( Pt, ApiKeyLabel ) -> "Chave de API (OpenAI/Gemini)"
        ( En, ApiKeyLabel ) -> "API Key (OpenAI)"

        ( Pt, WorkflowLabel ) -> "Definição do Fluxo (Mermaid)"
        ( En, WorkflowLabel ) -> "Mermaid Workflow Definition"

        ( Pt, TriggerLabel ) -> "Dado Inicial (Gatilho)"
        ( En, TriggerLabel ) -> "Trigger Input"

        ( Pt, TriggerPlaceholder ) -> "Dado inicial ou texto de gatilho..."
        ( En, TriggerPlaceholder ) -> "Initial data or trigger text..."

        ( Pt, SaveAgentBtn ) -> "Salvar Agente"
        ( En, SaveAgentBtn ) -> "Save Agent"

        ( Pt, RunAgentBtn ) -> "Executar Agente"
        ( En, RunAgentBtn ) -> "Run Agent"

        ( Pt, ApiKeyRequiredNote ) -> "Chave de API necessária para nós do tipo PROMPT."
        ( En, ApiKeyRequiredNote ) -> "API Key required for PROMPT nodes."

        ( Pt, StatusIdle ) -> "Ocioso"
        ( En, StatusIdle ) -> "Idle"

        ( Pt, StatusRunning ) -> "Executando... Passo "
        ( En, StatusRunning ) -> "Running... Step "

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