{-# LANGUAGE RankNTypes, ScopedTypeVariables, GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | @operational@-style programs for 'MonadPlus'.  See the
-- documentation for "Control.Applicative.Operational" and
-- "Control.Monad.Operational" for guidance on how to use this module.
module Control.MonadPlus.Operational
    ( ProgramP(..)
    , singleton
    , interpret
      
    , ProgramViewP(..)
    , view
    ) where

import Control.Applicative
import Control.Monad
import Control.MonadPlus.Free
import Control.Operational.Class
import Data.Functor.Yoneda.Contravariant

newtype ProgramP instr a = 
    ProgramP { -- | Interpret the program as a free 'MonadPlus'.
               toFree :: Free (Yoneda instr) a 
             } deriving (Functor, Applicative, Alternative, Monad, MonadPlus)

instance Operational ProgramP where
    singleton = ProgramP . liftF . liftYoneda

interpret :: forall m instr a. (Functor m, MonadPlus m) => 
             (forall x. instr x -> m x)
          -> ProgramP instr a
          -> m a
interpret evalI = retract . hoistFree evalF . toFree
    where evalF :: forall x. Yoneda instr x -> m x
          evalF (Yoneda f i) = fmap f (evalI i)


data ProgramViewP instr a where
    Return :: a -> ProgramViewP instr a
    (:>>=) :: instr a -> (a -> ProgramP instr b) -> ProgramViewP instr b
    MEmpty :: ProgramViewP instr a
    MPlus  :: ProgramViewP instr a
           -> ProgramViewP instr a
           -> ProgramViewP instr a

view :: ProgramP instr a -> ProgramViewP instr a
view = eval . toFree 
    where eval (Pure a) = Return a
          eval (Free (Yoneda f i)) = i :>>= (ProgramP . f)
          eval (Plus mas) = foldr MPlus MEmpty (map eval mas)
