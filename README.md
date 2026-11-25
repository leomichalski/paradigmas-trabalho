# ProspectFlow

ProspectFlow is an Elm-based MVP for a text-based LLM Workflow Engine. The application allows users to define a sequential pipeline of data enrichment and LLM prompts using a limited Mermaid.js syntax. It executes the pipeline entirely in the browser using The Elm Architecture (TEA) with no backend, relying on `elm/http` for API chaining.

![App Demo](assets/demo.gif)

## Features

- **Browser-Native Execution:** Runs entirely in the client with no backend dependencies, using Elm's robust state management.
- **Custom Mermaid Parser:** Uses `elm/parser` (strictly no regex) to parse linear workflow definitions, cleanly mapping them to domain types.
- **Workflow State Machine:** A sequential execution engine that passes the output of one step into the `{{input}}` token of the next step.
- **HTTP Actions:** Supports three primary actions:
  - `FETCH`: Retrieve text from a specified URL via HTTP GET.
  - `PROMPT`: Send the payload to OpenAI's `gpt-4o-mini` API.
  - `POST`: Send the previous step's output wrapped in a JSON payload to a specified webhook URL via HTTP POST.
- **Execution Log:** Provides real-time visual feedback on the state of the execution pipeline (Idle, Running, Completed, or Failed) and the output at each step.

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v20+ recommended)
- [pnpm](https://pnpm.io/)
- [Elm](https://guide.elm-lang.org/install/elm.html) (0.19.1+)

### Installation

1. Clone the repository and navigate to the project directory:
   ```bash
   cd prospectflow
   ```

2. Install the dependencies:
   ```bash
   pnpm install
   ```

3. Start the development server:
   ```bash
   pnpm exec vite
   ```

4. Open your browser and navigate to the local URL provided by Vite (e.g., `http://localhost:5173`).

## Usage

1. **Enter API Key:** Provide your OpenAI API Key (starting with `sk-...`).
2. **Define Workflow:** Enter a linear pipeline using the limited Mermaid syntax. Example:
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
3. **Trigger Input:** Provide any initial data to trigger the workflow. This will replace the `{{input}}` token in the first node.
4. **Save & Run:** Click "Save Agent" to parse the workflow, and then "Run Agent" to kick off the execution. Watch the Execution Status logs as it progresses step by step!

## Architecture

- **`src/Types.elm`**: The Single Source of Truth for domain models and Elm's `Msg`.
- **`src/Main.elm`**: The entry point, connecting the Model, Update, and View.
- **`src/AppParser.elm`**: A strict `elm/parser` implementation to read and validate the pipeline structure.
- **`src/Engine.elm`**: The state machine managing HTTP command generation, response handling, and `{{input}}` token interpolation.
- **`src/Api.elm`**: Decoders and encoders designed explicitly for structured communication with OpenAI.
- **`src/View.elm`**: The purely functional UI shell built with `elm/html`.

## License

This project is open-source and available under the standard MIT License.
