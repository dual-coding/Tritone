{-# LANGUAGE GHC2021, DataKinds, TypeApplications, TypeFamilies, TypeOperators #-}

module Tritone where

import Control.Monad

import Data.List
import Data.Modular
import Data.Monoid
import Data.Ratio

import GHC.TypeLits hiding (Mod)

-- Aliases and utility
type IntMod (n :: Nat) = Mod Int n

instance (Num b) => Num (a -> b) where
    (+) = liftM2 (+)
    (*) = liftM2 (*)
    abs = fmap abs
    signum = fmap signum
    fromInteger = return . fromInteger
    negate = fmap negate

  -- Abelian groups generated by...
class (Monoid a) => Generated a where
    type Gen a :: *
    basis :: Gen a -> a

  -- Tensor products
newtype Tensor a b = Tensor {getTensor :: [(a, b)]}

instance Semigroup (Tensor a b) where
    Tensor tensor1 <> Tensor tensor2 = Tensor $ tensor1 ++ tensor2

instance Monoid (Tensor a b) where
    mempty = Tensor []

instance Generated (Tensor a b) where
    type Gen (Tensor a b) = (a, b)
    basis = Tensor . return

groupTensor :: (Monoid a, Eq b) => Tensor a b -> Tensor a b
groupTensor (Tensor tensor) = let
    groupedB = groupBy (\t1 t2 -> snd t1 == snd t2) tensor
    addWithin [] = []
    addWithin term@((a, b):_) = foldl (\t1 t2 -> (fst t1 + fst t2, b)) (fromInteger 0, b) term in
        Tensor $ map addWithin groupedB

-- Time intervals - half open intervals
data TInterval = TInterval {tiStart :: Rational, tiDelta :: Rational} deriving (Eq)

withinInterval :: TInterval -> Rational -> Bool
withinInterval (TInterval start delta) x = start <= x && x < delta

-- Pitch with n tones.
newtype Pitch (n :: Nat) = Pitch {tone :: IntMod n} deriving (Eq)
newtype PitchSpace (n :: Nat) = PitchSpace {getPitchVector :: Pitch n -> Sum Int} deriving (Semigroup, Monoid, Num)

instance Generated (PitchSpace n) where
    type Gen (PitchSpace n) = Pitch n
    basis pitch = PitchSpace $ \p ->
        if p == pitch then Sum 1 else Sum 0

-- Time signatures.
data TimeSignature = TimeSignature {beats :: Nat, beatValue :: Nat} deriving (Eq)

-- Notes: 
data Note (n :: Nat) = Note {notePitch :: Pitch n, noteLocation :: TInterval, noteSignature :: TimeSignature} deriving (Eq)
newtype NoteSpace (n :: Nat) = NoteSpace {getNoteSpace :: Rational -> Tensor (PitchSpace n) TimeSignature} deriving (Semigroup, Monoid)

instance Generated (NoteSpace n) where
    type Gen (NoteSpace n) = Note n
    basis (Note pitch (TInterval start delta) sig) = NoteSpace $ \t ->
        if start <= t && t < start + delta then basis (basis pitch, sig) else mempty

-- Time signatures:
