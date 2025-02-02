module Data.Profunctor.Iso

import Data.Either
import Data.Profunctor

infixl 1 .&

export
(.&) : a -> (a -> b) -> b
a .& f = f a

||| A type-level function to make it easier to talk about "simple" `Lens`,
||| `Prism`, and `Iso`s
|||
||| ````idris example
||| fstStrLens : Profunctor p => Simple (Lens {p}) (String, String) String
||| fstStrLens = _1
||| ````
|||
public export
Simple : (Type -> Type -> Type -> Type -> Type) -> Type -> Type -> Type
Simple t s a = t s s a a

public export
preIso : {p : Type -> Type -> Type} -> Type -> Type -> Type -> Type -> Type
preIso s t a b = p a b -> p s t

||| An isomorphism family.
public export
Iso : {p : Type -> Type -> Type} -> Type -> Type -> Type -> Type -> Type
Iso s t a b = Profunctor p => preIso {p} s t a b

||| An isomorphism family that does not change types
public export
Iso' : {p : Type -> Type -> Type} -> Type -> Type -> Type
Iso' s a = Simple (Iso {p}) s a

||| Turns a coavariant and contravariant function into an `Iso`
export
iso : (s -> a) -> (b -> t) -> Iso s t a b
iso f g = dimap f g

||| Builds an `Iso` useful for constructing a `Lens`
export
lensIso : (s -> a) -> (s -> b -> t) -> Iso s t (a, s) (b, s)
lensIso gt = iso (\s => (gt s, s)) . uncurry . flip

||| Builds an `Iso` useful for constructing a `Prism`
export
prismIso : (b -> t) -> (s -> Either t a) -> Iso s t (Either t a) (Either t b)
prismIso f = flip iso $ either id $ Delay f

||| Convert an element of the first half of an iso to the second
export
forwards : Profunctor p => Iso {p=Forgotten a} s t a b -> s -> a
forwards i = runForget . i $ Forget id

||| Convert an element of the second half of an iso to the first
export
backwards : Profunctor p => Iso {p=Tagged} s t a b -> b -> t
backwards i = runTagged . i . Tag

||| An `Iso` between a function and it's arguments-flipped version
export
flipped : Iso (a -> b -> c) (d -> e -> f)
              (b -> a -> c) (e -> d -> f)
flipped = iso flip flip

||| An `Iso` between a function and it's curried version
export
curried : Iso ((a, b) -> c) ((d, e) -> f)
              (a -> b -> c) (d -> e -> f)
curried = iso curry uncurry

||| An `Iso` between a function and it's uncurried version
export
uncurried : Iso (a -> b -> c) (d -> e -> f)
                ((a, b) -> c) ((d, e) -> f)
uncurried = iso uncurry curry

||| An `Iso` between a list and its reverse
export
reversed : Iso (List a) (List b) (List a) (List b)
reversed = iso reverse reverse

||| An `Iso` between a string and a list of its characters
export
packed : Iso' String (List Char)
packed = iso unpack pack

||| An `Iso` between a list of characters and its string
export
unpacked : Iso' (List Char) String
unpacked = iso pack unpack

snooze : a -> Lazy a
snooze x = Delay x
ring : Lazy b -> b
ring x = Force x

||| An `Iso` between a lazy variable and its strict form
export
motivated : Iso a b (Lazy a) (Lazy b)
motivated = iso snooze ring

||| An `Iso` between a strict variable and its lazy form
export
unmotivated : Iso (Lazy a) (Lazy b) a b
unmotivated = iso ring snooze

-- TODO: Enum is currently commented out of base
--
-- ||| An `Iso` between an enumerable value and it's `Nat` representation
-- export
-- enum : (Profunctor p, Enum a) => Iso' {p} Nat a
-- enum = iso fromNat toNat
--
-- ||| An `Iso` between a `Nat` and its enumerable representation
-- export
-- denum : (Profunctor p, Enum a) => Iso' {p} a Nat
-- denum = iso toNat fromNat

export
mirrored : Iso (Either a b) (Either c d)
               (Either b a) (Either d c)
mirrored = iso mirror mirror
