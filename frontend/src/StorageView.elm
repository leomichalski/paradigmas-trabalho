module StorageView exposing (viewStorage)

{-| Tela de fluxos salvos (parte #2): salvar o fluxo do editor,
listar, filtrar por tipo de nó, abrir e apagar.
-}

import Html exposing (Html, button, div, h2, input, label, li, option, p, section, select, span, text, ul)
import Html.Attributes exposing (class, disabled, for, id, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import StorageApi exposing (nodeTypeToString)
import Translations exposing (Language, TextId(..), translate)
import Types exposing (..)


viewStorage : Model -> Html Msg
viewStorage model =
    section [ class "log storage" ]
        [ h2 [] [ text (translate model.language SavedFlowsTitle) ]
        , viewSaveForm model
        , viewStatus model.language model.storageStatus
        , viewFilter model.language model.flowFilter
        , viewList model
        ]



-- SALVAR


viewSaveForm : Model -> Html Msg
viewSaveForm model =
    let
        name =
            String.trim model.flowName

        alreadySaved =
            case model.savedFlows of
                LoadedFlows names ->
                    List.member name names

                _ ->
                    False

        saveDisabled =
            String.isEmpty name
                || String.isEmpty (String.trim model.workflowText)
                || model.storageStatus == StorageBusy

        buttonText =
            if alreadySaved then
                UpdateFlowBtn

            else
                SaveFlowBtn
    in
    div [ class "inputs" ]
        [ div [ class "field" ]
            [ label [ for "flow-name" ] [ text (translate model.language FlowNameLabel) ]
            , input
                [ id "flow-name"
                , type_ "text"
                , placeholder (translate model.language FlowNamePlaceholder)
                , value model.flowName
                , onInput UpdateFlowName
                ]
                []
            ]
        , div [ class "actions" ]
            [ button
                [ type_ "button"
                , class "btn"
                , onClick SaveFlow
                , disabled saveDisabled
                ]
                [ text (translate model.language buttonText) ]
            ]
        ]


viewStatus : Language -> StorageStatus -> Html Msg
viewStatus lang status =
    case status of
        NoStorageStatus ->
            text ""

        StorageBusy ->
            p [ class "actions__note" ] [ text (translate lang StorageBusyText) ]

        StorageDone action name ->
            p [ class "actions__note" ] [ text (translate lang (actionText action) ++ name) ]

        StorageFailed err ->
            div [ class "alert" ] [ text (translate lang StorageErrorPrefix ++ err) ]


actionText : StorageAction -> TextId
actionText action =
    case action of
        FlowSaved ->
            FlowSavedMsg

        FlowOpened ->
            FlowOpenedMsg

        FlowDeleted ->
            FlowDeletedMsg



-- FILTRO (consulta fluxos_com_tipo/2 no Prolog)


allNodeTypes : List NodeType
allNodeTypes =
    [ FetchNode, PromptNode, PostNode, AbortNode, DoneNode ]


{-| O <select> devolve uma String; aqui ela volta a ser um FlowFilter.
Qualquer valor que não seja um tipo conhecido vira "todos".
-}
filterFromString : String -> FlowFilter
filterFromString raw =
    allNodeTypes
        |> List.filter (\t -> nodeTypeToString t == raw)
        |> List.head
        |> Maybe.map UsingNode
        |> Maybe.withDefault AllFlows


viewFilter : Language -> FlowFilter -> Html Msg
viewFilter lang current =
    let
        nodeOption nodeType =
            option
                [ value (nodeTypeToString nodeType)
                , selected (current == UsingNode nodeType)
                ]
                [ text (translate lang FilterUsing ++ String.toUpper (nodeTypeToString nodeType)) ]
    in
    div [ class "field" ]
        [ label [ for "flow-filter" ] [ text (translate lang FilterLabel) ]
        , select [ id "flow-filter", onInput (filterFromString >> ChangeFlowFilter) ]
            (option [ value "", selected (current == AllFlows) ] [ text (translate lang FilterAll) ]
                :: List.map nodeOption allNodeTypes
            )
        ]



-- LISTA


viewList : Model -> Html Msg
viewList model =
    case model.savedFlows of
        LoadingFlows ->
            p [] [ text (translate model.language LoadingFlowsText) ]

        FlowsFailed err ->
            div [ class "alert" ] [ text (translate model.language FlowsLoadError ++ err) ]

        LoadedFlows [] ->
            p [] [ text (translate model.language NoSavedFlows) ]

        LoadedFlows names ->
            ul [ class "storage__list" ] (List.map (viewItem model) names)


viewItem : Model -> String -> Html Msg
viewItem model name =
    let
        busy =
            model.storageStatus == StorageBusy
    in
    li [ class "entry__head" ]
        [ span [ class "storage__name" ] [ text name ]
        , button
            [ type_ "button", class "btn btn--quiet", onClick (OpenFlow name), disabled busy ]
            [ text (translate model.language OpenFlowBtn) ]
        , button
            [ type_ "button", class "btn btn--quiet", onClick (DeleteFlow name), disabled busy ]
            [ text (translate model.language DeleteFlowBtn) ]
        ]
