module Data.Profunctor.Ran

import Data.Profunctor
import Data.Profunctor.Composition

||| The right Kan extension of a profunctor
public export
record Ran (p : Type -> Type -> Type) (q : Type -> Type -> Type)
           (a : Type) (b : Type) where
  -- Run : {x : _} -> (runRan : p x a -> q x b) -> Ran p q a b
  constructor Run
  runRan : p x a -> q x b

export
implementation (Profunctor p, Profunctor q) => Profunctor (Ran p q) where
  dimap ca bd f = Run $ rmap bd . runRan f . rmap ca
  lmap  ca    f = Run $           runRan f . rmap ca
  rmap     bd f = Run $ rmap bd . runRan f

export
implementation Profunctor q => Functor (Ran p q a) where
  map bd f = Run $ rmap bd . runRan f

||| Split up composed Profunctors by putting a Ran in the middle
export
curryRan : (Procomposed p q a b -> r a b) -> p a b -> Ran q r a b
curryRan fpro pab = Run $ \qaa => fpro (Procompose pab qaa)
