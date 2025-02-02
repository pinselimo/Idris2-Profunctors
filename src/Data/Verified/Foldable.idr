module Data.Verified.Foldable

import Control.Applicative.Const
import Control.Monad.Either
import Control.Monad.Maybe
import Data.List.Alternating
import Data.List.Lazy
import Data.List1
import Data.SnocList
import Data.SortedSet
import Data.SortedMap
import Data.Validated
import Data.Vect
import Data.Vect.Properties.Foldr
import Text.Bounded

%default total

public export
interface Foldable t => FoldableV t where
  toListNeutralL : (f : r -> a -> r) -> (z : r) -> (fo : t a) -> foldl f z fo = foldl f z (Prelude.toList fo)
  toListNeutralR : (f : a -> r -> r) -> (z : r) -> (fo : t a) -> foldr f z fo = foldr f z (Prelude.toList fo)

export
implementation FoldableV Maybe where
  toListNeutralL f z Nothing  = Refl
  toListNeutralL f z (Just x) = Refl
  toListNeutralR f z Nothing  = Refl
  toListNeutralR f z (Just x) = Refl

export
implementation FoldableV m => FoldableV (MaybeT m) where
  toListNeutralL f z m@(MkMaybeT mm) = let
                                      funEq : (x : c) -> (g : c -> d) -> (f : c -> d) -> g = f -> g x = f x
                                      funEq x g f hyp = rewrite hyp in Refl
                                    in rewrite funEq
                                               z
                                             ( foldr (\x, xs => maybe (Delay xs) (Delay (\arg, x => xs (f x arg))) x) id mm )
                                             ( foldr (\x, xs => maybe (Delay xs) (Delay (\arg, x => xs (f x arg))) x) id (toList mm))
                                             $ toListNeutralR (\x, xs => maybe (Delay xs) (Delay (\arg, x => xs (f x arg))) x) id mm
                                    in rewrite toListNeutralR (\x, xs => maybe (Delay xs) (Delay (\arg => arg :: xs)) x) Prelude.Nil mm
                                    in prf (toList mm) z
                                    where prf : (l : List (Maybe a)) -> (zz : r)
                                             -> foldr (\x, xs => maybe (Delay xs) (Delay (\arg, x => xs (f x arg))) x) Prelude.Basics.id l zz
                                             = foldl f zz (foldr (\x,xs => maybe (Delay xs) (Delay (\arg => arg :: xs)) x) Prelude.Nil l)
                                          prf [] = \_ => Refl
                                          prf (Nothing::xs) = \zz => prf xs zz
                                          prf (Just x ::xs) = \zz => prf xs (f zz x)
  toListNeutralR f z (MkMaybeT mm) = rewrite toListNeutralR (\x, xs => maybe (Delay xs) (Delay (\arg => f arg xs)) x) z mm
                                  in rewrite toListNeutralR (\x, xs => maybe (Delay xs) (Delay (\arg => arg :: xs)) x) Prelude.Nil mm
                                  in prf (toList mm)
                                  where prf : (l : List (Maybe a))
                                           -> foldr (\x, xs => maybe (Delay xs) (Delay (\arg => f arg xs)) x) z l
                                            = foldr f z (foldr (\x,xs => maybe (Delay xs) (Delay (\arg => arg :: xs)) x) Prelude.Nil l)
                                        prf [] = Refl
                                        prf (Nothing::xs) = prf xs
                                        prf (Just x ::xs) = cong (f x) (prf xs)
export
implementation FoldableV (Either e) where
  toListNeutralL f z (Left x)  = Refl
  toListNeutralL f z (Right x) = Refl
  toListNeutralR f z (Left x)  = Refl
  toListNeutralR f z (Right x) = Refl

export
implementation FoldableV m => FoldableV (EitherT e m) where
  toListNeutralL f z m@(MkEitherT mm) = let
                                      funEq : (x : c) -> (g : c -> d) -> (f : c -> d) -> g = f -> g x = f x
                                      funEq x g f hyp = rewrite hyp in Refl
                                    in rewrite funEq
                                               z
                                             ( foldr (\x, xs => either (Delay (const xs)) (Delay (\arg, x => xs (f x arg))) x) id mm )
                                             ( foldr (\x, xs => either (Delay (const xs)) (Delay (\arg, x => xs (f x arg))) x) id (toList mm))
                                             $ toListNeutralR (\x, xs => either (Delay (const xs)) (Delay (\arg, x => xs (f x arg))) x) id mm
                                    in rewrite toListNeutralR (\x, xs => either (Delay (const xs)) (Delay (\arg => arg :: xs)) x) Prelude.Nil mm
                                    in prf (toList mm) z
                                    where prf : (l : List (Either e a)) -> (zz : r)
                                             -> foldr (\x, xs => either (Delay (const xs)) (Delay (\arg, x => xs (f x arg))) x) Prelude.Basics.id l zz
                                             = foldl f zz (foldr (\x,xs => either (Delay (const xs)) (Delay (\arg => arg :: xs)) x) Prelude.Nil l)
                                          prf [] = \_ => Refl
                                          prf (Left e ::xs) = \zz => prf xs zz
                                          prf (Right x::xs) = \zz => prf xs (f zz x)
  toListNeutralR f z m@(MkEitherT mm) = rewrite toListNeutralR (\x, xs => either (Delay (const xs)) (Delay (\arg => f arg xs)) x) z mm
                                     in rewrite toListNeutralR (\x, xs => either (Delay (const xs)) (Delay (\arg => arg :: xs)) x) Prelude.Nil mm
                                     in prf (toList mm)
                                     where prf : (l : List (Either e a))
                                              -> foldr (\x, xs => either (Delay (const xs)) (Delay (\arg => f arg xs)) x) z l
                                               = foldr f z (foldr (\x, xs => either (Delay (const xs)) (Delay (\arg => arg :: xs)) x) Prelude.Nil l)
                                           prf [] = Refl
                                           prf (Left e ::xs) = prf xs
                                           prf (Right x::xs) = cong (f x) (prf xs)

export
implementation FoldableV List where
  toListNeutralL f z fo = Refl
  toListNeutralR f z fo = Refl

export
implementation FoldableV (Const a) where
  toListNeutralL f z xs = Refl
  toListNeutralR f z xs = Refl

export
implementation FoldableV List1 where
  toListNeutralL f z (x ::: xs) = Refl
  toListNeutralR f z (x ::: xs) = Refl

export
implementation FoldableV (Validated e) where
  toListNeutralL f z (Valid x) = Refl
  toListNeutralL f z (Invalid _) = Refl
  toListNeutralR f z (Valid x) = Refl
  toListNeutralR f z (Invalid _) = Refl

export
implementation FoldableV WithBounds where
  toListNeutralL f z xs = Refl
  toListNeutralR f z xs = Refl

export
implementation FoldableV (Vect n) where
  toListNeutralL f z xs = let
      foldlEmptyIndependent : (f : r -> a -> r) -> (xs : Vect m a) -> (z : r) -> foldl f z xs = foldl f z (toList xs)
      foldlEmptyIndependent f Nil = \_ => Refl
      foldlEmptyIndependent f (y :: ys) = let homomorphism = foldrVectHomomorphism.cons {A=a, F=(::), E=[]}
                                       in \z => rewrite foldlEmptyIndependent f ys (f z y)
                                             in cong (foldl f z) (sym (homomorphism y ys))
    in foldlEmptyIndependent f xs z
  toListNeutralR f z Nil = Refl
  toListNeutralR f z (x :: xs) = let
    vectHomomorphismCons = foldrVectHomomorphism.cons {A=a, F=(::), E=[]}
    vectHomomorphismF = foldrVectHomomorphism.cons {A=a, F=f, E=z}
    in rewrite vectHomomorphismCons x xs
    in rewrite sym (toListNeutralR f z xs)
    in vectHomomorphismF x xs

namespace SortedSet
  toListRedundant : (xs : List a) -> xs = foldr (::) [] xs
  toListRedundant [] = Refl
  toListRedundant (x::xs) = cong (x::) (toListRedundant xs)

  export
  implementation FoldableV SortedSet where
    toListNeutralL f z xs = cong (foldl {t=List} f z) (toListRedundant (SortedSet.toList xs))
    toListNeutralR f z xs = cong (foldr {t=List} f z) (toListRedundant (SortedSet.toList xs))

  export
  implementation FoldableV (SortedMap k) where
    toListNeutralL f z xs = cong (foldl {t=List} f z) (toListRedundant (values xs))
    toListNeutralR f z xs = cong (foldr {t=List} f z) (toListRedundant (values xs))

export
implementation FoldableV SnocList where
  toListNeutralL f z sn = snocFoldlAsListFoldl f z sn
  toListNeutralR f z sn = let
    foldrListAppendDistributive : (f : a -> r -> r) -> (z : r) -> (l1, l2 : List a)
                               -> foldr f (foldr f z l2) l1 = foldr f z (l1 ++ l2)
    foldrListAppendDistributive f z [] = \_ => Refl
    foldrListAppendDistributive f z (x::xs) = \li => cong (f x) (foldrListAppendDistributive f z xs li)

    snocFoldrAsListFoldr : (f : a -> r -> r) -> (xs : SnocList a) -> (init : r) -> foldr f init xs = foldr f init (toList xs)
    snocFoldrAsListFoldr f Lin = \_ => Refl
    snocFoldrAsListFoldr f (xs :< x) = \init =>
                                       rewrite snocFoldrAsListFoldr f xs (f x init)
                                    in rewrite chipsAsListAppend xs [x]
                                    in foldrListAppendDistributive f init (xs <>> []) [x]
    in snocFoldrAsListFoldr f sn z

export
implementation FoldableV LazyList where
  toListNeutralL f z xs = let
      foldlEmptyIndependent : (f : r -> a -> r) -> (xs : LazyList a) -> (z : r) -> foldl f z xs = foldl f z (toList xs)
      foldlEmptyIndependent f   []    = \_ => Refl
      foldlEmptyIndependent f (y::ys) = \z => foldlEmptyIndependent f ys (f z y)
    in foldlEmptyIndependent f xs z
  toListNeutralR f z [] = Refl
  toListNeutralR f z (x::xs) = cong (f x) (toListNeutralR f z xs)

export
implementation FoldableV (Odd b) where
  toListNeutralL f z odd = let
    foldlEmptyIndependent : (f : r -> a -> r) -> (xs : Odd b a) -> (z : r) -> foldl f z xs = foldl f z (toList xs)
    foldlEmptyIndependent f (x :: xs) with (xs)
      _ | Nil = \_ => Refl
      _ | (y :: ys) with (ys)
        _ | (n :: ns) with (ns)
          _ | Nil = \_ => Refl
          _ | (m :: ms) = \z => foldlEmptyIndependent f ms (f (f z y) m)
    in foldlEmptyIndependent f odd z
  toListNeutralR f z (x :: xs) with (xs)
    _ | Nil = Refl
    _ | (y :: ys) with (ys)
      _ | (n :: ns) with (ns)
        _ | Nil = Refl
        _ | (m :: ms) = let rec = toListNeutralR f z ms in cong (f y) (cong (f m) (toListNeutralR f z ms))

