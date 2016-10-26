module Form.Tree exposing (Tree(..), getAtPath, getAtName, getAtIndex, valuesWithPath, group, list, asList, asValue, setAtPath)

{-| Data structures

# Tree structure and builders
@docs Tree, group, list

# Readers
@docs getAtPath, getAtName, getAtIndex, asList, asValue, valuesWithPath

# Writers
@docs setAtPath
-}

import Dict exposing (Dict)
import String


{-| Field values and errors are stored as trees.
-}
type Tree value
    = Group (Dict String (Tree value))
    | List (List (Tree value))
    | Value value


type Fragment
    = StringFragment String
    | IntFragment Int


{-| Get node at given path
-}
getAtPath : String -> Tree value -> Maybe (Tree value)
getAtPath path tree =
    let
        walkPath fragment maybeField =
            case fragment of
                IntFragment index ->
                    maybeField `Maybe.andThen` getAtIndex index

                StringFragment name ->
                    maybeField `Maybe.andThen` getAtName name
    in
        List.foldl walkPath (Just tree) (extractFragments path)


{-| Get node at name, if group
-}
getAtName : String -> Tree value -> Maybe (Tree value)
getAtName name value =
    case value of
        Group group ->
            Dict.get name group

        _ ->
            Nothing


{-| Get node at index, if list of nodes.
-}
getAtIndex : Int -> Tree value -> Maybe (Tree value)
getAtIndex index value =
    asList value
        |> List.drop index
        |> List.head


{-| Get list of errors on qualified paths.
-}
valuesWithPath : Tree value -> List ( String, value )
valuesWithPath tree =
    let
        mapGroupItem path ( name, error ) =
            walkTree (path ++ [ name ]) error

        walkTree path value =
            case value of
                Group group ->
                    List.concatMap
                        (mapGroupItem path)
                        (Dict.toList group)

                List items ->
                    List.concatMap
                        (mapGroupItem path)
                        (List.indexedMap (\index item -> ( toString index, item )) items)

                Value value ->
                    [ ( String.join "." path, value ) ]
    in
        walkTree [] tree


{-| Extract value, if possible.
-}
asValue : Tree value -> Maybe value
asValue node =
    case node of
        Value value ->
            Just value

        _ ->
            Nothing


{-| Get field as a list of fields
-}
asList : Tree value -> List (Tree value)
asList value =
    case value of
        List items ->
            items

        _ ->
            []


{-| Helper to create a group value.
-}
group : List ( String, Tree value ) -> Tree value
group items =
    items
        |> Dict.fromList
        |> Group


{-| Build a list of values, for dynamic fields list
-}
list : List (Tree value) -> Tree value
list =
    List


extractFragments : String -> List Fragment
extractFragments name =
    String.split "." name
        |> List.map toFragment


toFragment : String -> Fragment
toFragment s =
    case String.toInt s of
        Ok i ->
            IntFragment i

        Err _ ->
            StringFragment s


{-| Set node in tree at given path.
-}
setAtPath : String -> Tree value -> Tree value -> Tree value
setAtPath path node tree =
    recursiveSet (extractFragments path) node (Just tree)


recursiveSet : List Fragment -> Tree value -> Maybe (Tree value) -> Tree value
recursiveSet fragments node maybeTree =
    case fragments of
        head :: rest ->
            case head of
                IntFragment index ->
                    maybeTree
                        |> Maybe.map asList
                        |> Maybe.withDefault []
                        |> updateListAtIndex index (\f -> recursiveSet rest node (Just f))
                        |> List

                StringFragment name ->
                    let
                        tree =
                            Maybe.withDefault (Group Dict.empty) maybeTree

                        childNode =
                            recursiveSet rest node (getAtName name tree)
                    in
                        merge (Group (Dict.fromList [ ( name, childNode ) ])) tree

        [] ->
            node


updateListAtIndex : Int -> (a -> a) -> List a -> List a
updateListAtIndex index updater =
    List.indexedMap
        (\i f ->
            if i == index then
                updater f
            else
                f
        )


merge : Tree value -> Tree value -> Tree value
merge t1 t2 =
    case ( t1, t2 ) of
        ( Group g1, Group g2 ) ->
            Group (Dict.union g1 g2)

        _ ->
            t1
