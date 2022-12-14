module SCC (scc, discardDisjointComponents) where
import qualified Data.Map as Map
import qualified Data.Set as Set

type Graph a = Map.Map a (Set.Set a)

type SCC a = [a]

-- Implementation of Tarjan's strongly connected components algorithm
-- Adapted from the pseudocode from
-- https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm

-- Keeps track of relevant information
data TarjanData a = TarjanData {
  indices :: Map.Map a Int,
  lowlinks :: Map.Map a Int,
  onStack :: Set.Set a,
  sStack :: [a],
  sccs :: [SCC a]
}

defaultData :: Ord a => TarjanData a
defaultData = TarjanData {
  indices = mempty,
  lowlinks = mempty,
  onStack = mempty,
  sStack = [],
  sccs = []
}

-- Setter methods
modIndices :: Ord a => (Map.Map a Int -> Map.Map a Int) -> TarjanData a -> TarjanData a
modIndices f t = t { indices = f (indices t) }

modLowlinks :: Ord a => (Map.Map a Int -> Map.Map a Int) -> TarjanData a -> TarjanData a
modLowlinks f t = t { lowlinks = f (lowlinks t) }

modOnStack :: Ord a => (Set.Set a -> Set.Set a) -> TarjanData a -> TarjanData a
modOnStack f t = t { onStack = f (onStack t) }

modStack :: Ord a => ([a] -> [a]) -> TarjanData a -> TarjanData a
modStack f t = t { sStack = f (sStack t) }

modSccs :: Ord a => ([SCC a] -> [SCC a]) -> TarjanData a -> TarjanData a
modSccs f t = t { sccs = f (sccs t) }


-- Tarjan's algorithm implementation: goes from a graph to a
-- topologically-sorted array of strongly connected components
scc :: (Eq a, Ord a) => Graph a -> [SCC a]
scc deps =
  reverse $ sccs $
  foldr (\ v t -> if Map.member v (indices t) then t else strongconnect v t)
    defaultData (Map.keys deps)
  where

    -- Adds a strongly connected component set with root v
    -- mkScc :: a -> TarjanData a -> TarjanData a
    mkScc v t =
      let h [] = []
          h (w : ws) = if w == v then [w] else (w : h ws)
          scc_nodes = h (sStack t)
          scc = case scc_nodes of
            [v] | not (v `elem` deps Map.! v) -> [v]
            _ -> scc_nodes
      in
        modSccs ((:) scc) $
        modStack (drop (length scc_nodes)) $
        modOnStack (\ os -> Set.difference os (Set.fromList scc_nodes)) t
    
    -- strongconnect :: a -> TarjanData a -> TarjanData a
    strongconnect v t =
      let t' = modIndices (\ m -> Map.insert v (Map.size m) m) $
               modLowlinks (Map.insert v (Map.size (indices t))) $
               modStack ((:) v) $
               modOnStack (Set.insert v) t
          t'' = foldr
            (\ w t ->
               if Map.member w (indices t) then
                 (if not (Set.member w (onStack t)) then t else
                    modLowlinks (Map.insertWith min v (indices t Map.! w)) t)
               else
                 modLowlinks (\ lls -> Map.insertWith min v (lls Map.! w) lls)
                   (strongconnect w t))
            t' (deps Map.! v)
          t''' = if lowlinks t'' Map.! v == indices t'' Map.! v then mkScc v t'' else t''
      in
        t'''

-- Returns the set of vertices reachable from any of a list of start vertices
reachableFrom :: (Eq a, Ord a) => [a] -> Graph a -> Set.Set a
reachableFrom starts graph = h mempty starts
  where
    --h :: Set.Set a -> [a] -> Set.Set a
    h visited [] = visited
    h visited (a : as) =
      if a `Set.member` visited then
        h visited as
      else
        h (Set.insert a visited) (maybe [] Set.toList (graph Map.!? a) ++ as)

discardDisjointComponents :: (Eq a, Ord a) => Graph a -> [a] -> [SCC a] -> [SCC a]
discardDisjointComponents graph starts sccs =
  let reachable = reachableFrom starts graph in
    [cs | cs <- sccs, not (null (Set.intersection reachable (Set.fromList cs)))]
