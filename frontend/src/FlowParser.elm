module FlowParser exposing (FlowError(..), ParseError, toFlow)

import Domain
    exposing
        ( DomainError
        , Edge
        , Flow
        , Node
        , NodeKind(..)
        )
import Parser exposing ((|.), (|=), Parser)


type alias ParseError =
    { line : Int
    , source : String
    , message : String
    }


type FlowError
    = Syntax (List ParseError)
    | Invalid (List DomainError)


toFlow : String -> Result FlowError Flow
toFlow text =
    parseItems text
        |> Result.mapError Syntax
        |> Result.andThen
            (\items ->
                Domain.flowFromParts
                    (List.filterMap nodeOf items)
                    (List.filterMap edgeOf items)
                    |> Result.mapError Invalid
            )
type Item
    = ItemNode Node
    | ItemEdge Edge


nodeOf : Item -> Maybe Node
nodeOf item =
    case item of
        ItemNode node ->
            Just node

        ItemEdge _ ->
            Nothing


edgeOf : Item -> Maybe Edge
edgeOf item =
    case item of
        ItemEdge edge ->
            Just edge

        ItemNode _ ->
            Nothing


parseItems : String -> Result (List ParseError) (List Item)
parseItems text =
    let
        results : List (Result ParseError (Maybe Item))
        results =
            text
                |> String.lines
                |> List.indexedMap (\index raw -> readLine (index + 1) raw)

        errors : List ParseError
        errors =
            List.filterMap errorOf results

        items : List Item
        items =
            List.filterMap itemOf results
    in
    if List.isEmpty errors then
        Ok items

    else
        Err errors


errorOf : Result ParseError (Maybe Item) -> Maybe ParseError
errorOf result =
    case result of
        Err error ->
            Just error

        Ok _ ->
            Nothing


itemOf : Result ParseError (Maybe Item) -> Maybe Item
itemOf result =
    case result of
        Ok maybeItem ->
            maybeItem

        Err _ ->
            Nothing


readLine : Int -> String -> Result ParseError (Maybe Item)
readLine number raw =
    parseLine raw
        |> Result.mapError
            (\message ->
                { line = number
                , source = String.trim raw
                , message = message
                }
            )


parseLine : String -> Result String (Maybe Item)
parseLine raw =
    let
        text =
            String.trim raw
    in
    if String.isEmpty text || String.startsWith "%%" text || String.startsWith "graph " text then
        Ok Nothing

    else
        case Parser.run declaration text of
            Ok (NodeDecl rawId rawAction) ->
                Result.map2 Node (Domain.idFromString rawId) (kindFromAction rawAction)
                    |> Result.map (ItemNode >> Just)

            Ok (EdgeDecl rawFrom rawEvent rawTo) ->
                Result.map3 Edge
                    (Domain.idFromString rawFrom)
                    (Domain.eventFromString rawEvent)
                    (Domain.idFromString rawTo)
                    |> Result.map (ItemEdge >> Just)

            Err _ ->
                Err "linha inválida: use  id[\"AÇÃO\"]  ou  origem -->|evento| destino"
kindFromAction : String -> Result String NodeKind
kindFromAction action =
    let
        text =
            String.trim action
    in
    if text == "ABORT" then
        Ok Abort

    else if text == "DONE" then
        Ok Done

    else
        case splitAction text of
            Just ( "FETCH", argument ) ->
                Result.map Fetch (Domain.urlFromString argument)

            Just ( "POST", argument ) ->
                Result.map Post (Domain.urlFromString argument)

            Just ( "PROMPT", argument ) ->
                if String.isEmpty argument then
                    Err "PROMPT precisa de um texto depois dos dois pontos"

                else
                    Ok (Prompt argument)

            _ ->
                Err ("ação desconhecida: " ++ text ++ " (use FETCH:, PROMPT:, POST:, ABORT ou DONE)")


splitAction : String -> Maybe ( String, String )
splitAction text =
    case String.indices ":" text of
        first :: _ ->
            Just
                ( String.trim (String.left first text)
                , String.trim (String.dropLeft (first + 1) text)
                )

        [] ->
            Nothing
type Declaration
    = NodeDecl String String
    | EdgeDecl String String String


declaration : Parser Declaration
declaration =
    Parser.oneOf
        [ Parser.backtrackable nodeDeclaration
        , edgeDeclaration
        ]


nodeDeclaration : Parser Declaration
nodeDeclaration =
    Parser.succeed NodeDecl
        |= identifier
        |. Parser.spaces
        |. Parser.symbol "[\""
        |= Parser.getChompedString (Parser.chompWhile (\c -> c /= '"'))
        |. Parser.symbol "\"]"
        |. Parser.spaces
        |. Parser.end


edgeDeclaration : Parser Declaration
edgeDeclaration =
    Parser.succeed EdgeDecl
        |= identifier
        |. Parser.spaces
        |. Parser.symbol "-->|"
        |= Parser.getChompedString (Parser.chompWhile (\c -> c /= '|'))
        |. Parser.symbol "|"
        |. Parser.spaces
        |= identifier
        |. Parser.spaces
        |. Parser.end


identifier : Parser String
identifier =
    Parser.getChompedString
        (Parser.succeed ()
            |. Parser.chompIf Domain.isIdChar
            |. Parser.chompWhile Domain.isIdChar
        )
