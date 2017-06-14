{-# LANGUAGE TypeOperators, TypeFamilies, LambdaCase, ScopedTypeVariables #-}

module GCBP where

import Prelude hiding ((.), id)
import Control.Category
import Control.Monad
import Control.Applicative
import Data.Maybe
import Data.Tuple
import Debug.Trace

import Test.QuickCheck
import Test.QuickCheck.Monadic
import System.Random.Shuffle

type (+) = Either

maybeLeft :: a + b -> Maybe a
maybeLeft = either Just (const Nothing)

maybeRight :: a + b -> Maybe b
maybeRight = either (const Nothing) Just

swapEither :: a + b -> b + a
swapEither = either Right Left

commute :: a + b <=> b + a
commute = swapEither :<=>: swapEither

assoc :: a + (b + c) <=> (a + b) + c
assoc = either (Left . Left) (either (Left . Right) Right) :<=>:
        either (either Left (Right . Left)) (Right . Right)

reassocL :: (a + (b + c)) <=> (a' + (b' + c'))
         -> ((a + b) + c) <=> ((a' + b') + c')
reassocL bij = assoc . bij . inverse assoc

reassocR :: ((a + b) + c) <=> ((a' + b') + c')
         -> (a + (b + c)) <=> (a' + (b' + c'))
reassocR bij = inverse assoc . bij . assoc

-- TODO: Conjugate bijections by each other?

class Category c => Groupoid c where
  inverse :: c a b -> c b a

data a <=> b = (a -> b) :<=>: (b -> a)
infixr 8 <=>
infixr 8 :<=>:
-- satisfying laws not (yet) stated here

-- TODO: Maybe later try modality-parameterized ___-jections?

instance Groupoid (<=>) where
  inverse (f :<=>: g) = g :<=>: f

instance Category (<=>) where
  id = id :<=>: id
  (f1 :<=>: g1) . (f2 :<=>: g2) =
    (f1 . f2) :<=>: (g2 . g1)

applyIso :: (a <=> b) -> a -> b
applyIso (f :<=>: _) = f

data a <-> b = (a -> Maybe b) :<->: (b -> Maybe a)
infixr 8 <->
infixr 8 :<->:
-- satisfying laws not (yet) stated here

partial :: (a <=> b) -> (a <-> b)
partial (f :<=>: g) = Just . f :<->: Just . g

unsafeTotal :: (a <-> b) -> (a <=> b)
unsafeTotal (f :<->: g) = fromJust . f :<=>: fromJust . g

instance Category (<->) where
  id = Just :<->: Just
  (f1 :<->: g1) . (f2 :<->: g2) =
    (f1 <=< f2) :<->: (g2 <=< g1)

instance Groupoid (<->) where
  inverse (f :<->: g) = g :<->: f

applyPartial :: (a <-> b) -> a -> Maybe b
applyPartial (f :<->: _) = f

leftPartial :: (a + c <-> b + d) -> (a <-> b)
leftPartial (f :<->: g) =
  (maybeLeft <=< f . Left) :<->:
  (maybeLeft <=< g . Left)

rightPartial :: (a + c <-> b + d) -> (c <-> d)
rightPartial (f :<->: g) =
  (maybeRight <=< f . Right) :<->:
  (maybeRight <=< g . Right)

class Category arr => Parallel arr where
  (|||) :: arr a c -> arr b d -> arr (a + b) (c + d)

-- NOTE: This is *not* the same as arrows, since bijections do not admit `arr`

instance Parallel (<=>) where
  (f :<=>: g) ||| (h :<=>: i) =
    either (Left . f) (Right . h) :<=>:
    either (Left . g) (Right . i)

instance Parallel (<->) where
  (f :<->: g) ||| (h :<->: i) =
    either (fmap Left . f) (fmap Right . h) :<->:
    either (fmap Left . g) (fmap Right . i)

--------------------------------------------------

gcbpReference :: (a0 + a1 <=> b0 + b1) -> (a1 <=> b1) -> (a0 <=> b0)
gcbpReference a0a1__b0b1 a1__b1 =
    (iter (applyIso a0a1__b0b1) (applyIso $ inverse a1__b1) . Left)
    :<=>:
    (iter (applyIso $ inverse a0a1__b0b1) (applyIso $ a1__b1) . Left)
  where
    iter a0a1_b0b1 b1_a1 a0a1 =
      case a0a1_b0b1 a0a1 of
        Left  b0 -> b0
        Right b1 -> iter a0a1_b0b1 b1_a1 (Right (b1_a1 b1))

gcbpExact :: Integer -> (a + c <=> b + d) -> (c <=> d) -> (a <=> b)
gcbpExact i minuend subtrahend =
  unsafeTotal . leftPartial $
    composeN i
      (step minuend subtrahend)
      (partial minuend)
  where
    composeN 0 _ = id
    composeN n f = f . composeN (n - 1) f

--------------------------------------------------

-- TODO: Think about how to use Cayley encoding to make both directions
-- use monadic right-recursion
step :: (a + c <=> b + d)
     -> (c <=> d)
     -> (a + c <-> b + d)
     -> (a + c <-> b + d)
step minuend subtrahend current =
  current
  >>>
  inverse (leftPartial current ||| partial subtrahend)
  >>>
  partial minuend

-- NOTE: We can omit the call to `leftPartial current` in gcbp, but not in gcbpExact,
-- because it is never needed, since the merge operation "locks in" a value, so we
-- never loop back around to use that chunk. Thus, we could replace it with the
-- partial bijection defined nowhere, and gcbp would behave identically.

infixl 3 <||>
(<||>) :: Alternative f => (a -> f b) -> (a -> f b) -> (a -> f b)
(f <||> g) a = f a <|> g a

-- Merge operation. In theory, should only merge compatible partial bijections.
instance Monoid (a <-> b) where
  mempty =
    const Nothing :<->: const Nothing
  mappend (f :<->: g) ~(h :<->: i) =  -- NOTE: this irrefutable match is Very Important
    (f <||> h) :<->: (g <||> i)       --       this is because of the infinite merge in gcbp

gcbp :: (a + c <=> b + d) -> (c <=> d) -> (a <=> b)
gcbp minuend subtrahend =
  unsafeTotal . foldMap leftPartial $
    iterate (step minuend subtrahend) (partial minuend)

-- NOTE: How to fix the slowness of gcbp:
--       1. *All* bijections should be automatically memoized on construction
--       2. Composition during gcbp should be the "wrong way", which is okay because everything's a palindrome

gmip :: (a <=> a')
     -> (b <=> b')
     -> (a' <=> b')
     -> (fa + a <=> fb + b)
     -> (fa <=> fb)
gmip involA involB f' f =
  gcbp (reassocR $ f ||| f') ((involA >>> f' >>> inverse involB) ||| f')

gcbp' :: (a + c <=> b + d) -> (c <=> d) -> (a <=> b)
gcbp' minuend subtrahend =
  gmip id id subtrahend minuend

-- TODO: gmip all by itself (is this worth it?)

--------------------------------------------------

data Three = One | Two | Three deriving (Eq, Show, Ord, Enum)

test :: Three + Bool <=> Three + Bool
test = unsafeBuildBijection
  [ (Left One,   Left Two  )
  , (Left Two,   Left Three)
  , (Left Three, Right False)
  , (Right False, Right True )
  , (Right True,  Left One  ) ]

-- NOTE: Invariant: input list must be the graph of a bijection
unsafeBuildBijection :: (Eq a, Eq b) => [(a,b)] -> (a <=> b)
unsafeBuildBijection pairs =
  unsafeTotal (f :<->: g)
  where
    f = flip lookup pairs
    g = flip lookup (map swap pairs)

-- generateTestCase m n generates random endobijections on [m]+[n] and
-- [n] (which can be subtracted to compute an endobijection on [m] for
-- testing/demonstration purposes).
generateTestCase :: Integer -> Integer
  -> IO (Integer + Integer <=> Integer + Integer, Integer <=> Integer)
generateTestCase m n = do
  let a = [1..m]
      c = [1..n]
      ac = (map Left a ++ map Right c)
  bd <- shuffleM ac
  d  <- shuffleM c
  return $ (unsafeBuildBijection $ zip ac bd, unsafeBuildBijection $ zip c d)

prop_gcbp_reference :: Positive Integer -> Positive Integer -> Property
prop_gcbp_reference (Positive m) (Positive n) = monadicIO $ do
  (f,g) <- run $ generateTestCase m n
  let h1 = gcbp f g
      h2 = gcbpReference f g
  assert $ map (applyIso h1) [1..m] == map (applyIso h2) [1..m]

--------------------------------------------------

instrument :: String -> [a] -> [a]
instrument s =
  foldr cons nil
  where
    cons a as = trace (s ++ " :")  (a : as)
    nil       = trace (s ++ " []") []
