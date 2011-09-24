 {-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Tests for the 'Data.HashMap.Lazy' module.  We test functions by
-- comparing them to a simpler model, an association list.

module Main (main) where

import qualified Data.Foldable as Foldable
import Data.Function (on)
import Data.Hashable (Hashable(hash))
import qualified Data.List as L
import qualified Data.HashMap.Lazy as HM
import qualified Data.Map as M
import Test.QuickCheck (Arbitrary)
import Test.Framework (Test, defaultMain, testGroup)
import Test.Framework.Providers.QuickCheck2 (testProperty)

-- Key type that generates more hash collisions.
newtype Key = K { unK :: Int }
            deriving (Arbitrary, Eq, Ord, Show)

instance Hashable Key where
    hash k = hash (unK k) `mod` 20

------------------------------------------------------------------------
-- * Properties

------------------------------------------------------------------------
-- ** Instances

pEq :: [(Key, Int)] -> [(Key, Int)] -> Bool
pEq xs ys = (M.fromList xs ==) `eq` (HM.fromList xs ==) $ ys

pNeq :: [(Key, Int)] -> [(Key, Int)] -> Bool
pNeq xs = (M.fromList xs /=) `eq` (HM.fromList xs /=)

pFunctor :: [(Key, Int)] -> Bool
pFunctor = fmap (+ 1) `eq_` fmap (+ 1)

pFoldable :: [(Int, Int)] -> Bool
pFoldable = (L.sort . Foldable.foldr (:) []) `eq`
            (L.sort . Foldable.foldr (:) [])

------------------------------------------------------------------------
-- ** Basic interface

pSize :: [(Key, Int)] -> Bool
pSize = M.size `eq` HM.size

pLookup :: Key -> [(Key, Int)] -> Bool
pLookup k = M.lookup k `eq` HM.lookup k

pInsert :: Key -> Int -> [(Key, Int)] -> Bool
pInsert k v = M.insert k v `eq_` HM.insert k v

pDelete :: Key -> [(Key, Int)] -> Bool
pDelete k = M.delete k `eq_` HM.delete k

pInsertWith :: Key -> [(Key, Int)] -> Bool
pInsertWith k = M.insertWith (+) k 1 `eq_` HM.insertWith (+) k 1

------------------------------------------------------------------------
-- ** Combine

pUnion :: [(Key, Int)] -> [(Key, Int)] -> Bool
pUnion xs ys = M.union (M.fromList xs) `eq_` HM.union (HM.fromList xs) $ ys

pUnionWith :: [(Key, Int)] -> [(Key, Int)] -> Bool
pUnionWith xs ys = M.unionWith (-) (M.fromList xs) `eq_`
                   HM.unionWith (-) (HM.fromList xs) $ ys

------------------------------------------------------------------------
-- ** Transformations

pMap :: [(Key, Int)] -> Bool
pMap = M.map (+1 ) `eq_` HM.map (+ 1)

------------------------------------------------------------------------
-- ** Difference and intersection

pDifference :: [(Key, Int)] -> [(Key, Int)] -> Bool
pDifference xs ys = M.difference (M.fromList xs) `eq_`
                    HM.difference (HM.fromList xs) $ ys

pIntersection :: [(Key, Int)] -> [(Key, Int)] -> Bool
pIntersection xs ys = M.intersection (M.fromList xs) `eq_`
                      HM.intersection (HM.fromList xs) $ ys

------------------------------------------------------------------------
-- ** Folds

pFoldr :: [(Int, Int)] -> Bool
pFoldr = (L.sort . M.fold (:) []) `eq` (L.sort . HM.foldr (:) [])

pFoldrWithKey :: [(Int, Int)] -> Bool
pFoldrWithKey = (sortByKey . M.foldrWithKey f []) `eq`
                (sortByKey . HM.foldrWithKey f [])
  where f k v z = (k, v) : z

pFoldl' :: Int -> [(Int, Int)] -> Bool
pFoldl' z0 = M.foldlWithKey' (\ z _ v -> v + z) z0 `eq` HM.foldl' (+) z0

------------------------------------------------------------------------
-- ** Filter

pFilter :: [(Int, Int)] -> Bool
pFilter = M.filter odd `eq_` HM.filter odd

pFilterWithKey :: [(Int, Int)] -> Bool
pFilterWithKey = M.filterWithKey p `eq_` HM.filterWithKey p
  where p k v = odd (k + v)

------------------------------------------------------------------------
-- ** Conversions

pToList :: [(Key, Int)] -> Bool
pToList = M.toAscList `eq` toAscList

pElems :: [(Key, Int)] -> Bool
pElems = (L.sort . M.elems) `eq` (L.sort . HM.elems)

pKeys :: [(Key, Int)] -> Bool
pKeys = (L.sort . M.keys) `eq` (L.sort . HM.keys)

------------------------------------------------------------------------
-- * Test list

tests :: [Test]
tests =
    [
    -- Instances
      testGroup "instances"
      [ testProperty "==" pEq
      , testProperty "/=" pNeq
      , testProperty "Functor" pFunctor
      , testProperty "Foldable" pFoldable
      ]
    -- Basic interface
    , testGroup "basic interface"
      [ testProperty "size" pSize
      , testProperty "lookup" pLookup
      , testProperty "insert" pInsert
      , testProperty "delete" pDelete
      , testProperty "insertWith" pInsertWith
      ]
    -- Combine
    , testProperty "union" pUnion
    , testProperty "unionWith" pUnionWith
    -- Transformations
    , testProperty "map" pMap
    -- Folds
    , testGroup "folds"
      [ testProperty "foldr" pFoldr
      , testProperty "foldrWithKey" pFoldrWithKey
      , testProperty "foldl'" pFoldl'
      ]
    , testGroup "difference and intersection"
      [ testProperty "difference" pDifference
      , testProperty "intersection" pIntersection
      ]
    -- Filter
    , testGroup "filter"
      [ testProperty "filter" pFilter
      , testProperty "filterWithKey" pFilterWithKey
      ]
    -- Conversions
    , testGroup "conversions"
      [ testProperty "elems" pElems
      , testProperty "keys" pKeys
      , testProperty "toList" pToList
      ]
    ]

------------------------------------------------------------------------
-- * Model

type Model k v = M.Map k v

-- | Check that a function operating on a 'HashMap' is equivalent to
-- one operating on a 'Model'.
eq :: (Eq a, Eq k, Hashable k, Ord k)
   => (Model k v -> a)       -- ^ Function that modifies a 'Model'
   -> (HM.HashMap k v -> a)  -- ^ Function that modified a 'HashMap' in the same
                             -- way
   -> [(k, v)]               -- ^ Initial content of the 'HashMap' and 'Model'
   -> Bool                   -- ^ True if the functions are equivalent
eq f g xs = g (HM.fromList xs) == f (M.fromList xs)

eq_ :: (Eq k, Eq v, Hashable k, Ord k)
    => (Model k v -> Model k v)            -- ^ Function that modifies a 'Model'
    -> (HM.HashMap k v -> HM.HashMap k v)  -- ^ Function that modified a
                                           -- 'HashMap' in the same way
    -> [(k, v)]                            -- ^ Initial content of the 'HashMap'
                                           -- and 'Model'
    -> Bool                                -- ^ True if the functions are
                                           -- equivalent
eq_ f g = (M.toAscList . f) `eq` (toAscList . g)

------------------------------------------------------------------------
-- * Test harness

main :: IO ()
main = defaultMain tests

------------------------------------------------------------------------
-- * Helpers

sortByKey :: Ord k => [(k, v)] -> [(k, v)]
sortByKey = L.sortBy (compare `on` fst)

toAscList :: Ord k => HM.HashMap k v -> [(k, v)]
toAscList = L.sortBy (compare `on` fst) . HM.toList
