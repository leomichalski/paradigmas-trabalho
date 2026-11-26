module Domain exposing
    ( DomainError(..)
    , Edge
    , Event
    , Flow
    , Node
    , NodeId
    , NodeKind(..)
    , Url
    , edges
    , eventFromString
    , eventToString
    , flowFromParts
    , idFromString
    , idToString
    , isIdChar
    , nodes
    , urlFromString
    , urlToString
    )

import Dict exposing (Dict)
import Set exposing (Set)


type NodeId
    = NodeId String


type Event
    = Event String


type Url
    = Url String


idFromString : String -> Result String NodeId
idFromString raw =
    if String.isEmpty raw then
        Err "o identificador do nó não pode ser vazio"

    else if String.all isIdChar raw then
        Ok (NodeId raw)

    else
        Err ("identificador inválido: " ++ raw ++ " (use letras, números e _)")


idToString : NodeId -> String
idToString (NodeId raw) =
    raw


isIdChar : Char -> Bool
isIdChar c =
    Char.isAlphaNum c || c == '_'


eventFromString : String -> Result String Event
eventFromString raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Err "o evento da ligação não pode ser vazio"

    else
        Ok (Event trimmed)


eventToString : Event -> String
eventToString (Event raw) =
    raw


urlFromString : String -> Result String Url
urlFromString raw =
    let
        trimmed =
            String.trim raw
    in
    if hasHostAfter "http://" trimmed || hasHostAfter "https://" trimmed then
        Ok (Url trimmed)

    else
        Err ("a URL deve começar com http:// ou https:// e ter um endereço: " ++ trimmed)


hasHostAfter : String -> String -> Bool
hasHostAfter scheme text =
    String.startsWith scheme text && String.length text > String.length scheme


urlToString : Url -> String
urlToString (Url raw) =
    raw


type NodeKind
    = Fetch Url
    | Prompt String
    | Post Url
    | Abort
    | Done


type alias Node =
    { id : NodeId
    , kind : NodeKind
    }


type alias Edge =
    { from : NodeId
    , event : Event
    , to : NodeId
    }


type Flow
    = Flow { nodes : List Node, edges : List Edge }


nodes : Flow -> List Node
nodes (Flow data) =
    data.nodes


edges : Flow -> List Edge
edges (Flow data) =
    data.edges


type DomainError
    = EmptyFlow
    | DuplicateNode NodeId
    | EdgeToUnknownNode { edge : Edge, missing : NodeId }
    | CycleDetected (List NodeId)


flowFromParts : List Node -> List Edge -> Result (List DomainError) Flow
flowFromParts nodeList edgeList =
    if List.isEmpty nodeList then
        Err [ EmptyFlow ]

    else
        let
            structural =
                duplicateErrors nodeList ++ unknownNodeErrors nodeList edgeList
        in
        if not (List.isEmpty structural) then
            Err structural

        else
            case cycleMembers nodeList edgeList of
                [] ->
                    Ok (Flow { nodes = nodeList, edges = edgeList })

                members ->
                    Err [ CycleDetected members ]


duplicateErrors : List Node -> List DomainError
duplicateErrors nodeList =
    nodeList
        |> List.foldl
            (\node ( seen, duplicates ) ->
                if Set.member (idToString node.id) seen then
                    ( seen, node.id :: duplicates )

                else
                    ( Set.insert (idToString node.id) seen, duplicates )
            )
            ( Set.empty, [] )
        |> Tuple.second
        |> List.reverse
        |> List.map DuplicateNode


unknownNodeErrors : List Node -> List Edge -> List DomainError
unknownNodeErrors nodeList edgeList =
    let
        known : Set String
        known =
            nodeList
                |> List.map (.id >> idToString)
                |> Set.fromList

        isUnknown : NodeId -> Bool
        isUnknown id =
            not (Set.member (idToString id) known)
    in
    edgeList
        |> List.concatMap
            (\edge ->
                [ edge.from, edge.to ]
                    |> List.filter isUnknown
                    |> List.map (\missing -> EdgeToUnknownNode { edge = edge, missing = missing })
            )


cycleMembers : List Node -> List Edge -> List NodeId
cycleMembers nodeList edgeList =
    let
        ids : List String
        ids =
            List.map (.id >> idToString) nodeList

        successors : Dict String (List String)
        successors =
            List.foldl
                (\edge ->
                    Dict.update (idToString edge.from)
                        (\existing -> Just (idToString edge.to :: Maybe.withDefault [] existing))
                )
                Dict.empty
                edgeList

        indegrees : Dict String Int
        indegrees =
            List.foldl
                (\edge -> Dict.update (idToString edge.to) (Maybe.map ((+) 1)))
                (Dict.fromList (List.map (\id -> ( id, 0 )) ids))
                edgeList

        roots : List String
        roots =
            List.filter (\id -> Dict.get id indegrees == Just 0) ids

        removed : Set String
        removed =
            peel successors indegrees roots Set.empty
    in
    nodeList
        |> List.map .id
        |> List.filter (\id -> not (Set.member (idToString id) removed))


peel : Dict String (List String) -> Dict String Int -> List String -> Set String -> Set String
peel successors indegrees queue removed =
    case queue of
        [] ->
            removed

        current :: rest ->
            let
                targets =
                    Dict.get current successors |> Maybe.withDefault []

                ( nextIndegrees, newlyFree ) =
                    List.foldl lowerIndegree ( indegrees, [] ) targets
            in
            peel successors nextIndegrees (rest ++ newlyFree) (Set.insert current removed)


lowerIndegree : String -> ( Dict String Int, List String ) -> ( Dict String Int, List String )
lowerIndegree target ( indegrees, free ) =
    let
        remaining =
            (Dict.get target indegrees |> Maybe.withDefault 0) - 1
    in
    ( Dict.insert target remaining indegrees
    , if remaining == 0 then
        target :: free

      else
        free
    )
