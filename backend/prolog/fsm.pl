:- use_module(library(pcre)).
:- use_module(library(readutil)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(http/http_json)).

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

% Executor
execute_workflow_from_text(Text, TriggerInput, ApiKey, FramesJson, LogOut) :-
    parse_mermaid_text(Text, Nodes, Transitions),
    atom_string(FramesAtom, FramesJson),
    atom_json_dict(FramesAtom, Frames, []),
    % Find start state
    Nodes = [node(Start, _) | _],
    format(string(Log1), "Starting workflow at state: ~w\n", [Start]),
    run_state(Start, Nodes, Transitions, _{api_key: ApiKey, input: TriggerInput, video_frames: Frames}, [Log1], LogsReversed),
    reverse(LogsReversed, LogsForward),
    atomics_to_string(LogsForward, "", LogOut).

run_state(State, Nodes, Transitions, Context, LogsIn, LogsOut) :-
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
        (   sub_string(FinalPrompt, VideoBefore, _, VideoAfter, "{{inputVideo}}")
        ->  ( Context.video_frames = [] -> VideoLabel = "[video ausente]" ; VideoLabel = "[quadros do vídeo anexados]" ),
            sub_string(FinalPrompt, 0, VideoBefore, _, VideoPrefix),
            sub_string(FinalPrompt, _, VideoAfter, 0, VideoSuffix),
            string_concat(VideoPrefix, VideoLabel, VideoTemp),
            string_concat(VideoTemp, VideoSuffix, FinalVideoPrompt)
        ;   FinalVideoPrompt = FinalPrompt
        ),
        
        string_length(FinalVideoPrompt, PromptLen),
        ( PromptLen > 150 -> sub_string(FinalVideoPrompt, 0, 150, _, PromptPreview) ; PromptPreview = FinalVideoPrompt ),
        format(string(L1), "Executing PROMPT with OpenAI GPT-4o-mini...\nPrompt payload preview: ~w...\n", [PromptPreview]),
        ApiKey = Context.api_key,

        catch(
            (   ( sub_string(PromptTpl, _, _, _, "{{inputVideo}}"), Context.video_frames = []
                -> throw(error(missing_video_file, prompt))
                ; true
                ),
                ( Context.video_frames = []
                -> UserContent = FinalVideoPrompt
                ; maplist(frame_content, Context.video_frames, ImageParts),
                  UserContent = [_{type: text, text: FinalVideoPrompt}|ImageParts]
                ),
                Payload = _{model: "gpt-4o-mini", messages: [_{role: "user", content: UserContent}]},
                string_concat("Bearer ", ApiKey, AuthHeader),
                setup_call_cleanup(
                    http_open('https://api.openai.com/v1/chat/completions', In, [
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
    ),
    (   Event \= "none"
    ->  (   member(transition(State, EventAtom, NextState), Transitions),
            atom_string(EventAtom, Event)
        ->  true
        ;   member(transition(State, Event, NextState), Transitions)
        ),
        format(string(LTrans), "~w --[~w]--> ~w\n\n", [State, Event, NextState]),
        run_state(NextState, Nodes, Transitions, NextContext, [LTrans | LogsMid], LogsOut)
    ;   LogsOut = LogsMid
    ).

frame_content(FrameUrl, _{type: image_url, image_url: _{url: FrameUrl, detail: low}}).
