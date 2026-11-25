# ProspectFlow

ProspectFlow é um MVP em Elm de um motor de fluxos (workflows) de LLM baseado em texto. A aplicação permite definir um pipeline sequencial de enriquecimento de dados e prompts de LLM usando uma sintaxe limitada do Mermaid.js. O frontend em Elm (The Elm Architecture) envia o fluxo para um backend FastAPI, onde um motor em Prolog o executa.

![Demonstração do App](assets/demo.gif)

## Funcionalidades

- **Execução no Backend:** Os fluxos são executados por uma máquina de estados em Prolog, exposta por um endpoint FastAPI (`POST /execute`).
- **Parser de Mermaid Próprio:** Usa `elm/parser` (sem nenhuma regex) para interpretar definições lineares de fluxo, mapeando-as de forma limpa para tipos de domínio.
- **Máquina de Estados do Fluxo:** Um motor de execução sequencial que passa a saída de uma etapa para o token `{{input}}` da etapa seguinte.
- **Ações HTTP:** Suporta três ações principais:
  - `FETCH`: Busca texto de uma URL especificada via HTTP GET.
  - `PROMPT`: Envia o conteúdo para a API `gpt-4o-mini` da OpenAI.
  - `POST`: Envia a saída da etapa anterior, encapsulada em um JSON, para uma URL de webhook especificada via HTTP POST.
- **Log de Execução:** Mostra em tempo real o estado da execução do pipeline (Ocioso, Executando, Concluído ou Falhou) e a saída de cada etapa.

## Primeiros Passos

### Pré-requisitos

- [Node.js](https://nodejs.org/) (v20+ recomendado)
- [pnpm](https://pnpm.io/)
- [Elm](https://guide.elm-lang.org/install/elm.html) (0.19.1+)
- [Docker](https://www.docker.com/) (ou [uv](https://docs.astral.sh/uv/) + [SWI-Prolog](https://www.swi-prolog.org/) para rodar o backend sem Docker)

### Instalação

1. Suba o backend (`http://localhost:8000`) a partir da raiz do repositório:
   ```bash
   docker compose up --build
   ```
   Sem Docker: `cd backend && uv sync && ENVIRONMENT=dev uv run fastapi dev app/main.py` (`ENVIRONMENT=dev` habilita o CORS para o frontend).

2. Em outro terminal, instale as dependências do frontend (o app em Elm fica em `frontend/`, não em `frontend/prospectflow/`):
   ```bash
   cd frontend
   pnpm install
   ```

3. Inicie o servidor de desenvolvimento:
   ```bash
   pnpm exec vite
   ```

4. Abra o navegador na URL local informada pelo Vite (ex.: `http://localhost:5173`).

## Uso

1. **Informe a API Key:** Forneça sua chave da API da OpenAI (começando com `sk-...`).
2. **Defina o Fluxo:** Escreva um pipeline linear usando a sintaxe limitada do Mermaid. Exemplo:
   ```mermaid
   graph TD
      start["FETCH: https://jsonplaceholder.typicode.com/posts/1"]
      summarize["PROMPT: Summarize the following JSON: {{input}}"]
      send["POST: https://httpbin.org/post"]
      abort["ABORT"]
      done["DONE"]

      start -->|fetch_succeeded| summarize
      start -->|fetch_failed| abort
      summarize -->|summary_generated| send
      summarize -->|generation_failed| abort
      send -->|request_succeeded| done
      send -->|request_failed| abort
   ```
3. **Entrada de Disparo:** Forneça qualquer dado inicial para disparar o fluxo. Ele substituirá o token `{{input}}` no primeiro nó.
4. **Salvar e Executar:** Clique em "Save Agent" para interpretar o fluxo e depois em "Run Agent" para iniciar a execução. Acompanhe os logs em Execution Status conforme o fluxo avança etapa por etapa!

## Arquitetura

- **`src/Types.elm`**: A fonte única da verdade para os modelos de domínio e o `Msg` do Elm.
- **`src/Main.elm`**: O ponto de entrada, que conecta Model, Update e View.
- **`src/AppParser.elm`**: Uma implementação estrita com `elm/parser` para ler e validar a estrutura do pipeline.
- **`src/Engine.elm`**: A máquina de estados que gerencia a geração de comandos HTTP, o tratamento das respostas e a interpolação do token `{{input}}`.
- **`src/Api.elm`**: Decoders e encoders feitos especificamente para a comunicação estruturada com a OpenAI.
- **`src/View.elm`**: A interface puramente funcional construída com `elm/html`.

## Licença

Este projeto é open-source e está disponível sob a licença MIT.
