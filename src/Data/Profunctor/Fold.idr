module Data.Profunctor.Fold

import Control.Algebra
import Data.Profunctor
import Data.Profunctor.Choice
import Data.Profunctor.Prism
import Data.SortedSet
import Data.Verified.Foldable

liftA2 : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2 f x y = f <$> x <*> y

public export
interface Fold f where
  run : Foldable t => f a b -> t a -> b

  ||| Two folds are equal if they are point wise equal in their ``run`` function.
  ||| We need this axiom because otherwise the Applicative instance would be unlawful.
  ||| The requirement for a ``FoldableV`` instance stems from the necessity to destruct ``t``.
  foldExtensionality : Fold f => (fa, fb : f a b) -> (forall t. FoldableV t => (l : t a) -> run fa l = run fb l) -> fa = fb

namespace Fold
  public export
  finish : (r1 -> a -> b) -> (r2 -> a) -> (r1, r2) -> b
  finish f g (x, y) = f x (g y)

  namespace L
    public export
    step : (r1 -> a -> r1) -> (r2 -> a -> r2) -> (r1, r2) -> a -> (r1, r2)
    step u v (x, y) b = (u x b, v y b)

  namespace R
    public export
    step : (a -> r1 -> r1) -> (a -> r2 -> r2) -> a -> (r1, r2) -> (r1, r2)
    step u v b (x, y) = (u b x, v b y)

||| A leftwards fold
public export
data L a b = MkL (r -> b) (r -> a -> r) r

||| Turn a finalization function, an accumulation function, and an initial value
||| into an `L`
export
unfoldL : (s -> (b, a -> s)) -> s -> L a b
unfoldL f = MkL (fst . f) (snd . f)

||| Run an `L` on a `Foldable` container
export
runL : Foldable t => L a b -> t a -> b
runL (MkL k h z) = k . foldl h z

||| Run an `L` on a `Foldable` container, accumulating results
export
scanL : L a b -> List a -> List b
scanL (MkL k _ z) []      = pure $ k z
scanL (MkL k h z) (x::xs) = k (h z x) :: scanL (MkL k h (h z x)) xs

export
implementation Fold L where
  run = runL
  foldExtensionality a b = believe_me

export
implementation Profunctor L where
  dimap f g (MkL k h z) = MkL (g . k) ((. f) . h) z
  rmap    g (MkL k h z) = MkL (g . k) h           z
  lmap  f   (MkL k h z) = MkL k       ((. f) . h) z

export
implementation Choice L where
  left' (MkL {r} k h z) = MkL (\e => case e of Left a  => Left $ k a
                                               Right b => Right b)
                              step
                              (Left z) where
    step : Either r c -> Either a c -> Either r c
    step (Left x)  (Left y)  = Left $ h x y
    step (Right c) _         = Right c
    step _         (Right c) = Right c
  right' (MkL {r} k h z) = MkL (\e => case e of Right a => Right $ k a
                                                Left b  => Left b)
                               step
                               (Right z) where
    step : Either c r -> Either c a -> Either c r
    step (Right x) (Right y) = Right $ h x y
    step (Left c)  _         = Left c
    step _         (Left c)  = Left c

export
implementation Prisming L where
  costrength = rmap (either id id) . right'

export
implementation Functor (L a) where
  map = rmap

export
implementation Applicative (L a) where
  pure b = MkL (const b) (const $ const ()) ()
  (MkL f u y) <*> (MkL a v z) = MkL (Fold.finish f a) (Fold.L.step u v) (y, z)

export
implementation Monad (L a) where
  m >>= f = MkL ((. f) . flip runL) ((. pure) . (++)) [] <*> m

export
implementation Semigroup m => Semigroup (L a m) where
  (<+>) = liftA2 (<+>)

public export
runLSemigroupDistributive : (FoldableV t, Semigroup m) => (ll, lr : L a m) -> (fo : t a) -> runL (ll <+> lr) fo = runL ll fo <+> runL lr fo
runLSemigroupDistributive (MkL {r=r1} d g u) (MkL {r=r2} e h v) fo = let
    prf : (xs : List a) -> (u : r1) -> (v : r2) -> foldl (L.step g h) (u, v) xs = (foldl g u xs, foldl h v xs)
    prf []      = \_, _ => Refl
    prf (x::xs) = \y, z => prf xs (g y x) (h z x)
 in rewrite toListNeutralL g u fo
 in rewrite toListNeutralL h v fo
 in rewrite toListNeutralL (step g h) (u, v) fo
 in cong (Fold.finish (\n, m => d n <+> m) e) (prf (toList fo) u v)

export
implementation (SemigroupV m) => SemigroupV (L a m) where
  semigroupOpIsAssociative l@(MkL {r=r1} d g u) c@(MkL {r=r2} e h v) r@(MkL {r=r3} f j w)
    = let
      prf : forall t. FoldableV t => (fo : t a) -> runL (l <+> (c <+> r)) fo = runL ((l <+> c) <+> r) fo
      prf fo = rewrite runLSemigroupDistributive l (c <+> r) fo
            in rewrite runLSemigroupDistributive c r fo
            in rewrite semigroupOpIsAssociative (d (foldl g u fo)) (e (foldl h v fo)) (f (foldl j w fo))
            in rewrite sym (runLSemigroupDistributive l c fo)
            in sym (runLSemigroupDistributive (l <+> c) r fo)
    in foldExtensionality (l <+> (c <+> r)) ((l <+> c) <+> r) prf

export
implementation Monoid m => Monoid (L a m) where
  neutral = pure neutral

export
implementation MonoidV m => MonoidV (L a m) where
  monoidNeutralIsNeutralL l@(MkL k h z) = let
    neut : L a m
    neut = neutral
    prf : forall t. FoldableV t => (fo : t a) -> runL (l <+> neut) fo = runL l fo
    prf fo = rewrite runLSemigroupDistributive l neut fo
          in monoidNeutralIsNeutralL (k (foldl h z fo))

    in foldExtensionality (l <+> neut) l prf
  monoidNeutralIsNeutralR l@(MkL k h z) = let
    neut : L a m
    neut = neutral
    prf : forall t. FoldableV t => (fo : t a) -> runL (neut <+> l) fo = runL l fo
    prf fo = rewrite runLSemigroupDistributive neut l fo
          in monoidNeutralIsNeutralR (k (foldl h z fo))
    in foldExtensionality (neut <+> l) l prf

export
implementation Group m => Group (L a m) where
  inverse = map inverse
  groupInverseIsInverseR l@(MkL k h z) = let
       neut : L a m
       neut = neutral
       prf : forall t. FoldableV t => (fo : t a) -> runL (inverse l <+> l) fo = runL neut fo
       prf fo = rewrite runLSemigroupDistributive (inverse l) l fo
             in groupInverseIsInverseR (k (foldl h z fo))
    in foldExtensionality (inverse l <+> l) neut prf

export
implementation AbelianGroup m => AbelianGroup (L a m) where
  groupOpIsCommutative l@(MkL d g u) r@(MkL f j w) = let
      prf : forall t. FoldableV t => (fo : t a) -> runL (l <+> r) fo = runL (r <+> l) fo
      prf fo = rewrite runLSemigroupDistributive l r fo
            in rewrite groupOpIsCommutative (d (foldl g u fo)) (f (foldl j w fo))
            in sym (runLSemigroupDistributive r l fo)
    in foldExtensionality (l <+> r) (r <+> l) prf

mutual
  export
  implementation Ring m => Ring (L a m) where
    (<.>) = liftA2 (<.>)
    ringOpIsAssociative l@(MkL d g u) c@(MkL e h v) r@(MkL f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runL (l <.> (c <.> r)) fo = runL ((l <.> c) <.> r) fo
         prf fo = rewrite runLRingDistributive l (c <.> r) fo
               in rewrite runLRingDistributive c r fo
               in rewrite ringOpIsAssociative (d (foldl g u fo)) (e (foldl h v fo)) (f (foldl j w fo))
               in rewrite sym (runLRingDistributive l c fo)
               in sym (runLRingDistributive (l <.> c) r fo)
      in foldExtensionality (l <.> (c <.> r)) ((l <.> c) <.> r) prf
    ringOpIsDistributiveL l@(MkL d g u) c@(MkL e h v) r@(MkL f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runL (l <.> (c <+> r)) fo = runL ((l <.> c) <+> (l <.> r)) fo
         prf fo = rewrite runLRingDistributive l (c <+> r) fo
               in rewrite runLSemigroupDistributive c r fo
               in rewrite ringOpIsDistributiveL (d (foldl g u fo)) (e (foldl h v fo)) (f (foldl j w fo))
               in rewrite sym (runLRingDistributive l c fo)
               in rewrite sym (runLRingDistributive l r fo)
               in sym (runLSemigroupDistributive (l <.> c) (l <.> r) fo)
      in foldExtensionality (l <.> (c <+> r)) ((l <.> c) <+> (l <.> r)) prf
    ringOpIsDistributiveR l@(MkL d g u) c@(MkL e h v) r@(MkL f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runL ((l <+> c) <.> r) fo = runL ((l <.> r) <+> (c <.> r)) fo
         prf fo = rewrite runLRingDistributive (l <+> c) r fo
               in rewrite runLSemigroupDistributive l c fo
               in rewrite ringOpIsDistributiveR (d (foldl g u fo)) (e (foldl h v fo)) (f (foldl j w fo))
               in rewrite sym (runLRingDistributive l r fo)
               in rewrite sym (runLRingDistributive c r fo)
               in sym (runLSemigroupDistributive (l <.> r) (c <.> r) fo)
      in foldExtensionality ((l <+> c) <.> r) ((l <.> r) <+> (c <.> r)) prf

  public export
  runLRingDistributive : (FoldableV t, Ring m) => (ll, lr : L a m) -> (fo : t a) -> runL (ll <.> lr) fo = runL ll fo <.> runL lr fo
  runLRingDistributive (MkL {r=r1} d g u) (MkL {r=r2} e h v) fo = let
      prf : (xs : List a) -> (u : r1) -> (v : r2) -> foldl (L.step g h) (u, v) xs = (foldl g u xs, foldl h v xs)
      prf [] = \_, _ => Refl
      prf (x::xs) = \u, v => prf xs (g u x) (h v x)
   in rewrite toListNeutralL (step g h) (u, v) fo
   in rewrite toListNeutralL g u fo
   in rewrite toListNeutralL h v fo
   in cong (finish (\n, m => d n <.> m) e) (prf (toList fo) u v)

export
implementation RingWithUnity m => RingWithUnity (L a m) where
  unity = pure unity
  unityIsRingIdL l@(MkL d g u) = let
      uni : L a m
      uni = unity
      prf : forall t. FoldableV t => (fo : t a) -> runL (l <.> uni) fo = runL l fo
      prf fo = rewrite runLRingDistributive l uni fo
            in unityIsRingIdL (d (foldl g u fo))
    in foldExtensionality (l <.> uni) l prf
  unityIsRingIdR l@(MkL d g u) = let
      uni : L a m
      uni = unity
      prf : forall t. FoldableV t => (fo : t a) -> runL (uni <.> l) fo = runL l fo
      prf fo = rewrite runLRingDistributive uni l fo
            in unityIsRingIdR (d (foldl g u fo))
    in foldExtensionality (uni <.> l) l prf

-- The `Field` implementation won't type check, but it should exist

export
implementation Num n => Num (L a n) where
  (+)         = liftA2 (+)
  (*)         = liftA2 (*)
  fromInteger = pure . fromInteger

export
implementation Neg n => Neg (L a n) where
  (-)         = liftA2 (-)
  negate      = map negate

export
implementation Abs n => Abs (L a n) where
  abs         = map abs

||| An `L` to calculate the size of a `Foldable` container
export
length : Num a => L _ a
length = MkL id (const . (+ 1)) 0

||| An `L` which returns `True` if the container is empty, and `False` otherwise
export
null : L _ Bool
null = MkL id (const $ const False) True

||| An `L` which returns either `Just` an element satisfying a given condition or
||| `Nothing`
export
find : (a -> Bool) -> L a (Maybe a)
find p = MkL id step Nothing where
  step : Maybe a -> a -> Maybe a
  step x a = case x of Nothing => if p a then Just a else Nothing
                       _       => x

||| An `L` which returns either `Just` the index of a given element or `Nothing`
export
index : Nat -> L a (Maybe a)
index i = MkL done step (Left 0) where
  step : Either Nat a -> a -> Either Nat a
  step x = case x of Left j => if i == j then Right else const . Left $ S j
                     _      => const x
  done : Either Nat a -> Maybe a
  done = either (const Nothing) Just

||| An `L` which returns a `List` containing each unique element in the input
export
nub : Eq a => L a (List a)
nub = MkL (flip snd []) step ([], id) where
  step : (List a, List a -> List a) -> a -> (List a, List a -> List a)
  step (k, r) i = if elem i k then (k, r) else (i :: k, r . (i ::))

||| A faster `nub`
export
fastNub : {a : Type} -> Ord a => L a (List a)
fastNub {a} = MkL (flip snd $ the (List a) [])
                  (\(s, r), a => if contains a s then (s, r)
                                                 else (insert a s, r . (a ::)))
                  (the (SortedSet a) empty, id)

||| An `L` which returns a sorted `List` of each element in the input
export
sort : Ord a => L a (List a)
sort = MkL id (flip $ merge . pure) [] where
  merge : List a -> List a -> List a
  merge xs [] = xs
  merge [] ys = ys
  merge (x :: xs) (y :: ys) = if x < y then x :: merge xs (y :: ys)
                                       else y :: merge (x :: xs) ys

||| Turns a binary function into a lazy `L`
export
L1 : (a -> a -> a) -> L a (Lazy (Maybe a))
L1 s = MkL (\x => Delay x) (\m => Just . case m of Just x => s x; _ => id) Nothing

||| Returns the first element of its input, if it exists
export
first : L a (Lazy (Maybe a))
first = map (\x => Force x) $ L1 const

||| Returns the last element of its input, if it exists
export
last : L a (Lazy (Maybe a))
last = map (\x => Force x) . L1 $ flip const

||| Returns the maximum element of its input, if it exists
export
maximum : Ord a => L a (Lazy (Maybe a))
maximum = map (\x => Force x) $ L1 max

||| Returns the minimum element of its input, if it exists
export
minimum : Ord a => L a (Lazy (Maybe a))
minimum = map (\x => Force x) $ L1 min

||| Sums the elements of its input
export
sum : Num a => L a a
sum = MkL id (+) 0

||| Returns the product of the elements of its input
export
product : Num a => L a a
product = MkL id (*) 0

||| Concats the elements of its input
export
concat : Monoid a => L a a
concat = MkL id (<+>) neutral

||| Concats the elements of its input using binary operation given by the ring
export
concatR : RingWithUnity a => L a a
concatR = MkL id (<.>) unity

||| A rightwards fold
public export
data R a b = MkR (r -> b) (a -> r -> r) r

||| Run an `R` on a `Foldable` container
export
runR : Foldable t => R a b -> t a -> b
runR (MkR k h z) = k . foldr h z

||| Run an `R` on a `Foldable` container, accumulating results
export
scanR : {r : Type} -> R a b -> List a -> List b
scanR (MkR {r} k h z) = map k . scan' where
  scan' : List a -> List r
  scan' []      = z :: []
  scan' (x::xs) = let l = scan' xs in h x (case l of [] => z; (q::_) => q) :: l

export
implementation Fold R where
  run = runR
  foldExtensionality a b = believe_me

export
implementation Profunctor R where
  dimap f g (MkR k h z) = MkR (g . k) (h . f) z
  rmap    g (MkR k h z) = MkR (g . k) h       z
  lmap  f   (MkR k h z) = MkR k       (h . f) z

export
implementation Choice R where
  left' (MkR {r} k h z) = MkR (\e => case e of Left a  => Left $ k a
                                               Right b => Right b)
                              step
                              (Left z) where
    step : Either a c -> Either r c -> Either r c
    step (Left x)  (Left y)  = Left $ h x y
    step (Right c) _         = Right c
    step _         (Right c) = Right c
  right' (MkR {r} k h z) = MkR (\e => case e of Right a => Right $ k a
                                                Left b  => Left b)
                               step
                               (Right z) where
    step : Either c a -> Either c r -> Either c r
    step (Right x) (Right y) = Right $ h x y
    step (Left c)  _         = Left c
    step _         (Left c)  = Left c

export
implementation Prisming R where
  costrength = rmap (either id id) . right'

export
implementation Functor (R a) where
  map = rmap

export
implementation Applicative (R a) where
  pure b = MkR (const b) (const $ const ()) ()
  (MkR f u y) <*> (MkR a v z) = MkR (Fold.finish f a) (Fold.R.step u v) (y, z)

export
implementation Monad (R a) where
  m >>= f = MkR ((. f) . flip runR) (::) [] <*> m

export
implementation Semigroup m => Semigroup (R a m) where
  (<+>) = liftA2 (<+>)

public export
runRSemigroupDistributive : (FoldableV t, Semigroup m) => (rl, rr : R a m) -> (li : t a) -> runR (rl <+> rr) li = runR rl li <+> runR rr li
runRSemigroupDistributive (MkR {r=r1} d g u) (MkR {r=r2} e h v) fo = let
    prf : (xs : List a) -> foldr (R.step g h) (u, v) xs = (foldr g u xs, foldr h v xs)
    prf [] = Refl
    prf (x::xs) = cong (step g h x) (prf xs)
 in rewrite toListNeutralR g u fo
 in rewrite toListNeutralR h v fo
 in rewrite toListNeutralR (step g h) (u, v) fo
 in cong (Fold.finish (\n, m => d n <+> m) e) (prf (toList fo))

export
implementation SemigroupV m => SemigroupV (R a m) where
  semigroupOpIsAssociative l@(MkR d g u) c@(MkR e h v) r@(MkR f j w) = let
      prf : forall t. FoldableV t => (fo : t a) -> runR (l <+> (c <+> r)) fo = runR ((l <+> c) <+> r) fo
      prf fo = rewrite runRSemigroupDistributive l (c <+> r) fo
            in rewrite runRSemigroupDistributive c r fo
            in rewrite semigroupOpIsAssociative (d (foldr g u fo)) (e (foldr h v fo)) (f (foldr j w fo))
            in rewrite sym (runRSemigroupDistributive l c fo)
            in sym (runRSemigroupDistributive (l <+> c) r fo)
      in foldExtensionality (l <+> (c <+> r)) ((l <+> c) <+> r) prf

export
implementation Monoid m => Monoid (R a m) where
  neutral = pure neutral

export
implementation MonoidV m => MonoidV (R a m) where
  monoidNeutralIsNeutralL r@(MkR k h z) = let
    neut : R a m
    neut = neutral
    prf : forall t. FoldableV t => (fo : t a) -> runR (r <+> neut) fo = runR r fo
    prf fo = rewrite runRSemigroupDistributive r neut fo
            in monoidNeutralIsNeutralL (k (foldr h z fo))
    in foldExtensionality (r <+> neut) r prf

  monoidNeutralIsNeutralR r@(MkR k h z) = let
    neut : R a m
    neut = neutral
    prf : forall t. FoldableV t => (fo : t a) -> runR (neut <+> r) fo = runR r fo
    prf fo = rewrite runRSemigroupDistributive neut r fo
            in monoidNeutralIsNeutralR (k (foldr h z fo))
    in foldExtensionality (neut <+> r) r prf

export
implementation Num n => Num (R a n) where
  (+)         = liftA2 (+)
  (*)         = liftA2 (*)
  fromInteger = pure . fromInteger

export
implementation Neg n => Neg (R a n) where
  (-)         = liftA2 (-)
  negate      = map negate

export
implementation Abs n => Abs (R a n) where
  abs         = map abs

export
implementation Group m => Group (R a m) where
  inverse = map inverse
  groupInverseIsInverseR r@(MkR k h z) = let
       neut : R a m
       neut = neutral
       prf : forall t. FoldableV t => (fo : t a) -> runR (inverse r <+> r) fo = runR neut fo
       prf fo = rewrite runRSemigroupDistributive (inverse r) r fo
             in groupInverseIsInverseR (k (foldr h z fo))
    in foldExtensionality (inverse r <+> r) neut prf

export
implementation AbelianGroup m => AbelianGroup (R a m) where
  groupOpIsCommutative l@(MkR d g u) r@(MkR f j w) = let
      prf : forall t. FoldableV t => (fo : t a) -> runR (l <+> r) fo = runR (r <+> l) fo
      prf fo = rewrite runRSemigroupDistributive l r fo
            in rewrite groupOpIsCommutative (d (foldr g u fo)) (f (foldr j w fo))
            in sym (runRSemigroupDistributive r l fo)
    in foldExtensionality (l <+> r) (r <+> l) prf

mutual
  export
  implementation Ring m => Ring (R a m) where
    (<.>) = liftA2 (<.>)
    ringOpIsAssociative l@(MkR d g u) c@(MkR e h v) r@(MkR f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runR (l <.> (c <.> r)) fo = runR ((l <.> c) <.> r) fo
         prf fo = rewrite runRRingDistributive l (c <.> r) fo
               in rewrite runRRingDistributive c r fo
               in rewrite ringOpIsAssociative (d (foldr g u fo)) (e (foldr h v fo)) (f (foldr j w fo))
               in rewrite sym (runRRingDistributive l c fo)
               in sym (runRRingDistributive (l <.> c) r fo)
      in foldExtensionality (l <.> (c <.> r)) ((l <.> c) <.> r) prf
    ringOpIsDistributiveL l@(MkR d g u) c@(MkR e h v) r@(MkR f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runR (l <.> (c <+> r)) fo = runR ((l <.> c) <+> (l <.> r)) fo
         prf fo = rewrite runRRingDistributive l (c <+> r) fo
               in rewrite runRSemigroupDistributive c r fo
               in rewrite ringOpIsDistributiveL (d (foldr g u fo)) (e (foldr h v fo)) (f (foldr j w fo))
               in rewrite sym (runRRingDistributive l c fo)
               in rewrite sym (runRRingDistributive l r fo)
               in sym (runRSemigroupDistributive (l <.> c) (l <.> r) fo)
      in foldExtensionality (l <.> (c <+> r)) ((l <.> c) <+> (l <.> r)) prf

    ringOpIsDistributiveR l@(MkR d g u) c@(MkR e h v) r@(MkR f j w) = let
         prf : forall t. FoldableV t => (fo : t a) -> runR ((l <+> c) <.> r) fo = runR ((l <.> r) <+> (c <.> r)) fo
         prf fo = rewrite runRRingDistributive (l <+> c) r fo
               in rewrite runRSemigroupDistributive l c fo
               in rewrite ringOpIsDistributiveR (d (foldr g u fo)) (e (foldr h v fo)) (f (foldr j w fo))
               in rewrite sym (runRRingDistributive l r fo)
               in rewrite sym (runRRingDistributive c r fo)
               in sym (runRSemigroupDistributive (l <.> r) (c <.> r) fo)
      in foldExtensionality ((l <+> c) <.> r) ((l <.> r) <+> (c <.> r)) prf

  public export
  runRRingDistributive : (FoldableV t, Ring m) => (rl, rr : R a m) -> (li : t a) -> runR (rl <.> rr) li = runR rl li <.> runR rr li
  runRRingDistributive (MkR {r=r1} d g u) (MkR {r=r2} e h v) fo = let
      prf : (xs : List a) -> foldr (R.step g h) (u, v) xs = (foldr g u xs, foldr h v xs)
      prf [] = Refl
      prf (x::xs) = cong (step g h x) (prf xs)
   in rewrite toListNeutralR (step g h) (u, v) fo
   in rewrite toListNeutralR g u fo
   in rewrite toListNeutralR h v fo
   in cong (Fold.finish (\n, m => d n <.> m) e) (prf (toList fo))

export
implementation RingWithUnity m => RingWithUnity (R a m) where
  unity = pure unity
  unityIsRingIdL r@(MkR d g u) = let
      uni : R a m
      uni = unity
      prf : forall t. FoldableV t => (fo : t a) -> runR (r <.> uni) fo = runR r fo
      prf fo = rewrite runRRingDistributive r uni fo
            in unityIsRingIdL (d (foldr g u fo))
    in foldExtensionality (r <.> uni) r prf
  unityIsRingIdR r@(MkR d g u) = let
      uni : R a m
      uni = unity
      prf : forall t. FoldableV t => (fo : t a) -> runR (uni <.> r) fo = runR r fo
      prf fo = rewrite runRRingDistributive uni r fo
            in unityIsRingIdR (d (foldr g u fo))
    in foldExtensionality (uni <.> r) r prf

||| Convert an `L` to an `R`
export
lr : L a b -> R a b
lr (MkL k h z) = MkR k (flip h) z

||| Convert an `R` to an `L`
export
rl : R a b -> L a b
rl (MkR k h z) = MkL k (flip h) z
