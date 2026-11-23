module Engine exposing (startExecution, handleNodeResult, executeNode)

import Http
import Types exposing (..)
import Api
import Json.Encode as Encode

startExecution : Model -> ( Model, Cmd Msg )
startExecution model =
    case model.parsedPipeline of
        Ok nodes ->
            case List.head nodes of
                Just firstNode ->
                    let
                        cmd =
                            executeNode model.apiKey model.triggerInput firstNode
                    in
                    ( { model | executionState = Running { stepIndex = 0, latestOutput = model.triggerInput, logs = [] } }
                    , cmd
                    )

                Nothing ->
                    ( { model | executionState = Failed { error = "Pipeline is empty.", logs = [] } }, Cmd.none )

        Err err ->
            ( { model | executionState = Failed { error = err, logs = [] } }, Cmd.none )

executeNode : String -> String -> PipelineNode -> Cmd Msg
executeNode apiKey input node =
    let
        interpolatedPayload =
            String.replace "{{input}}" input node.payload
    in
    case node.actionType of
        Fetch ->
            Http.get
                { url = interpolatedPayload
                , expect = Http.expectString GotNodeResult
                }

        Prompt ->
            Http.request
                { method = "POST"
                , headers = [ Http.header "Authorization" ("Bearer " ++ apiKey) ]
                , url = "https://api.openai.com/v1/chat/completions"
                , body = Http.jsonBody (Api.openAiRequestEncoder interpolatedPayload)
                , expect = Http.expectJson GotNodeResult Api.openAiResponseDecoder
                , timeout = Nothing
                , tracker = Nothing
                }

        Post ->
            Http.post
                { url = interpolatedPayload
                , body = Http.jsonBody (Encode.object [ ( "data", Encode.string input ) ])
                , expect = Http.expectString GotNodeResult
                }

handleNodeResult : Model -> Result Http.Error String -> ( Model, Cmd Msg )
handleNodeResult model result =
    case model.executionState of
        Running state ->
            case result of
                Ok output ->
                    case model.parsedPipeline of
                        Ok nodes ->
                            let
                                currentNode =
                                    List.drop state.stepIndex nodes |> List.head

                                actionName =
                                    case currentNode of
                                        Just n ->
                                            case n.actionType of
                                                Fetch -> "FETCH"
                                                Prompt -> "PROMPT"
                                                Post -> "POST"
                                        Nothing ->
                                            "UNKNOWN"
                                
                                stepId =
                                    case currentNode of
                                        Just n -> n.id
                                        Nothing -> "unknown"

                                newLogs =
                                    state.logs ++ [ { stepId = stepId, actionName = actionName, output = output } ]
                                
                                nextIndex =
                                    state.stepIndex + 1
                                
                                nextNode =
                                    List.drop nextIndex nodes |> List.head
                            in
                            case nextNode of
                                Just n ->
                                    ( { model | executionState = Running { stepIndex = nextIndex, latestOutput = output, logs = newLogs } }
                                    , executeNode model.apiKey output n
                                    )

                                Nothing ->
                                    ( { model | executionState = Completed { logs = newLogs } }
                                    , Cmd.none
                                    )

                        Err _ ->
                            ( { model | executionState = Failed { error = "Pipeline parsed state invalid.", logs = state.logs } }, Cmd.none )

                Err httpErr ->
                    let
                        errorMsg =
                            case httpErr of
                                Http.BadUrl url -> "Bad URL: " ++ url
                                Http.Timeout -> "Network Timeout"
                                Http.NetworkError -> "Network Error"
                                Http.BadStatus 401 -> "Unauthorized: Please check your OpenAI API Key."
                                Http.BadStatus status -> "Bad Status: " ++ String.fromInt status
                                Http.BadBody bodyErr -> "Bad Body: " ++ bodyErr
                    in
                    ( { model | executionState = Failed { error = errorMsg, logs = state.logs } }, Cmd.none )

        _ ->
            ( model, Cmd.none )
