:- use_module(library(pcre)).
:- use_module(library(readutil)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(http/http_json)).
:- ensure_loaded(graph).

% Parser
parse_node(Line, Id, Action) :-
    re_matchsub('^\\s*(?<id>[a-zA-Z0-9_]+)\\["(?<action>[^"]+)"\\]', Line, Sub, []),
    Id = Sub.id, Action = Sub.action.

parse_transition(Line, Src, Event, Dst) :-
    re_matchsub('^\\s*(?<src>[a-zA-Z0-9_]+)\\s*-->\\|(?<evt>[^|]+)\\|\\s*(?<dst>[a-zA-Z0-9_]+)', Line, Sub, []),
    Src = Sub.src, Event = Sub.evt, Dst = Sub.dst.

parse_lines([], [], []).
parse_lines([Line|Rest], Nodes, Transitions) :-
    parse_lines(Rest, RestNodes, RestTransitions),
    (   parse_node(Line, Id, Action)
    ->  Nodes = [node(Id, Action) | RestNodes],
        Transitions = RestTransitions
    ;   parse_transition(Line, Src, Event, Dst)
    ->  Transitions = [transition(Src, Event, Dst) | RestTransitions],
        Nodes = RestNodes
    ;   Nodes = RestNodes,
        Transitions = RestTransitions
    ).

parse_mermaid_text(Text, Nodes, Transitions) :-
    split_string(Text, "\n", "\r", Lines),
    parse_lines(Lines, Nodes, Transitions).

% LLM providers for PROMPT nodes: llm_provider(Id, Label, Url, Model).
% All of them expose the OpenAI-compatible chat completions API.
llm_provider(openai, "OpenAI", 'https://api.openai.com/v1/chat/completions', "gpt-4o-mini").
llm_provider(nvidia, "NVIDIA NIM", 'https://integrate.api.nvidia.com/v1/chat/completions', "nvidia/nemotron-3.5-bolt-e4b").
llm_provider(nvidia_ultra, "NVIDIA NIM", 'https://integrate.api.nvidia.com/v1/chat/completions', "nvidia/nemotron-3-ultra-550b-a55b").

% Executor
execute_workflow_from_text(Text, TriggerInput, ApiKey, LogOut) :-
    execute_workflow_from_text(Text, TriggerInput, ApiKey, openai, LogOut).

execute_workflow_from_text(Text, TriggerInput, ApiKey, Provider, LogOut) :-
    parse_mermaid_text(Text, Nodes, Transitions),
    % Find start state
    Nodes = [node(Start, _) | _],
    % Fails if the graph has a cycle (graph.pl)
    niveis_paralelismo(Nodes, Transitions, Levels),
    format(string(Log1), "Starting workflow at state: ~w\n", [Start]),
    StartEntry = Start-_{api_key: ApiKey, provider: Provider, input: TriggerInput},
    run_levels(Levels, Nodes, Transitions, [StartEntry], [Log1], LogsReversed),
    reverse(LogsReversed, LogsForward),
    atomics_to_string(LogsForward, "", LogOut).

% Walks the levels in order. Only activated nodes run: the start node or the
% target of an edge whose event was fired. Activated nodes of the same level
% run in parallel; if a node has several parents, the first context wins.
run_levels([], _, _, _, Logs, Logs).
run_levels([Level | Rest], Nodes, Transitions, Active, LogsIn, LogsOut) :-
    findall(Node-Ctx, (member(Node, Level), memberchk(Node-Ctx, Active)), ToRun),
    concurrent_maplist(run_node(Nodes, Transitions), ToRun, Results),
    foldl(accumulate, Results, Active-LogsIn, NewActive-LogsMid),
    run_levels(Rest, Nodes, Transitions, NewActive, LogsMid, LogsOut).

run_node(Nodes, Transitions, Node-Ctx, result(Logs, Next)) :-
    run_state(Node, Nodes, Ctx, Event, NextCtx, [], NodeLogs),
    findall(Dst-NextCtx, next_transition(Transitions, Node, Event, Dst), Next),
    findall(LT,
            ( member(Dst-_, Next),
              format(string(LT), "~w --[~w]--> ~w\n\n", [Node, Event, Dst]) ),
            LTs),
    reverse(LTs, LTsRev),
    append(LTsRev, NodeLogs, Logs).

next_transition(Transitions, Node, Event, Dst) :-
    member(transition(Node, E, Dst), Transitions),
    atom_string(E, Event).

% Logs are kept newest first, like in the rest of the executor
accumulate(result(Logs, Next), Active0-LogsIn, Active-LogsOut) :-
    append(Active0, Next, Active),
    append(Logs, LogsIn, LogsOut).

% Runs a single node and returns the fired event and the new context
run_state(State, Nodes, Context, Event, NextContext, LogsIn, LogsMid) :-
    member(node(State, Action), Nodes),
    (   re_matchsub('^FETCH:\\s*(?<url>.*)', Action, SubF, [])
    ->  Url = SubF.url,
        format(string(L1), "Executing FETCH: ~w\n", [Url]),
        catch(
            (   setup_call_cleanup(
                    http_open(Url, In, []),
                    read_string(In, _, Response),
                    close(In)
                ),
                NextContext = Context.put(input, Response),
                Event = "fetch_succeeded",
                string_length(Response, ResLen),
                ( ResLen > 100 -> sub_string(Response, 0, 100, _, RespPreviewT) ; RespPreviewT = Response ),
                format(string(L2), "FETCH succeeded.\nResponse preview: ~w...\n", [RespPreviewT]),
                append([L2, L1], LogsIn, LogsMid)
            ),
            Error,
            (   format(string(L2), "FETCH failed: ~w\n", [Error]),
                Event = "fetch_failed",
                NextContext = Context,
                append([L2, L1], LogsIn, LogsMid)
            )
        )
    ;   re_matchsub('^PROMPT:\\s*(?<prompt>.*)', Action, SubP, [])
    ->  PromptTpl = SubP.prompt,
        (   get_dict(input, Context, InputStr) -> Input = InputStr ; Input = "" ),

        (   sub_string(PromptTpl, BeforeLen, _, AfterLen, "{{input}}")
        ->  sub_string(PromptTpl, 0, BeforeLen, _, Before),
            sub_string(PromptTpl, _, AfterLen, 0, After),
            string_concat(Before, Input, TempStr),
            string_concat(TempStr, After, FinalPrompt)
        ;   FinalPrompt = PromptTpl
        ),
        
        string_length(FinalPrompt, PromptLen),
        ( PromptLen > 150 -> sub_string(FinalPrompt, 0, 150, _, PromptPreview) ; PromptPreview = FinalPrompt ),
        llm_provider(Context.provider, ProviderLabel, ProviderUrl, ModelName),
        format(string(L1), "Executing PROMPT with ~w (~w)...\nPrompt payload preview: ~w...\n",
               [ProviderLabel, ModelName, PromptPreview]),
        ApiKey = Context.api_key,

        Payload = _{
            model: ModelName,
            messages: [
                _{role: "user", content: FinalPrompt}
            ]
        },

        catch(
            (   string_concat("Bearer ", ApiKey, AuthHeader),
                setup_call_cleanup(
                    http_open(ProviderUrl, In, [
                        post(json(Payload)),
                        request_header('Authorization'=AuthHeader)
                    ]),
                    json_read_dict(In, ResponseDict),
                    close(In)
                ),
                % Extract the text response
                [Choice|_] = ResponseDict.choices,
                Answer = Choice.message.content,

                NextContext = Context.put(answer, Answer),
                Event = "summary_generated",
                format(string(L2), "PROMPT succeeded.\nResponse:\n~w\n", [Answer]),
                append([L2, L1], LogsIn, LogsMid)
            ),
            Error,
            (   format(string(L2), "PROMPT failed: ~w\n", [Error]),
                Event = "generation_failed",
                NextContext = Context,
                append([L2, L1], LogsIn, LogsMid)
            )
        )
    ;   re_matchsub('^POST:\\s*(?<url>.*)', Action, SubPo, [])
    ->  Url = SubPo.url,
        format(string(L1), "Executing POST: ~w\n", [Url]),
        (   get_dict(answer, Context, AnswerStr) -> Answer = AnswerStr ; Answer = "" ),
        catch(
            (   http_post(Url, json(_{answer: Answer}), _Result, []),
                Event = "request_succeeded",
                format(string(L2), "POST succeeded with payload:\n~w\n", [Answer]),
                append([L2, L1], LogsIn, LogsMid)
            ),
            Error,
            (   format(string(L2), "POST failed: ~w\n", [Error]),
                Event = "request_failed",
                NextContext = Context,
                append([L2, L1], LogsIn, LogsMid)
            )
        ),
        NextContext = Context
    ;   Action == "ABORT"
    ->  format(string(L1), "Workflow finished at state: ~w with action: ABORT\n", [State]),
        Event = "none", NextContext = Context, LogsMid = [L1 | LogsIn]
    ;   Action == "DONE"
    ->  format(string(L1), "Workflow finished at state: ~w with action: DONE\n", [State]),
        Event = "none", NextContext = Context, LogsMid = [L1 | LogsIn]
    ;   format(string(L1), "Unknown action: ~w\n", [Action]),
        Event = "none", NextContext = Context, LogsMid = [L1 | LogsIn]
    ).
