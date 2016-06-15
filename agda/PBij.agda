-- Theory of partial bijections

module PBij where

open import Level renaming (zero to lzero)

open import Function using (const) renaming (_∘_ to _∘f_)

open import Data.Empty
open import Data.Unit
open import Data.Sum

open import Data.Maybe
open import Category.Monad

open import Relation.Binary.PropositionalEquality
open import Relation.Binary.Core

_⇀_ : ∀ {ℓ} → Set ℓ → Set ℓ → Set ℓ
A ⇀ B = A → Maybe B

-- Is associativity of _<=<_ recorded anywhere?
_•_ : ∀ {ℓ} {A B C : Set ℓ} → (B ⇀ C) → (A ⇀ B) → (A ⇀ C)
_•_ = _<=<_
  where
    open RawMonad Data.Maybe.monad

infixr 9 _•_

-- Assume function extensionality, just to get nicer proofs.  We won't
-- need the computational content of the proofs.
postulate
  funext : (a b : Level) → Extensionality a b

•-assoc-pt : ∀ {ℓ} {A B C D : Set ℓ} (f : C ⇀ D) (g : B ⇀ C) (h : A ⇀ B) (a : A)
        → ((f • g) • h) a ≡ (f • (g • h)) a
•-assoc-pt f g h a with h a
... | nothing = refl
... | just b  with g b
... | nothing = refl
... | just c  = refl

•-assoc : ∀ {ℓ} {A B C D : Set ℓ} (f : C ⇀ D) (g : B ⇀ C) (h : A ⇀ B)
        → (f • g) • h ≡ f • (g • h)
•-assoc {ℓ} f g h = funext ℓ ℓ (•-assoc-pt f g h)

id : ∀ {ℓ} {A : Set ℓ} → (A ⇀ A)
id = just

•-left-id : ∀ {ℓ} {A B : Set ℓ} (f : A ⇀ B) → id • f ≡ f
•-left-id {ℓ} {A} f = funext ℓ ℓ •-left-id-pt
  where
    •-left-id-pt : ∀ a → (id • f) a ≡ f a
    •-left-id-pt a with f a
    ... | nothing = refl
    ... | just _  = refl

•-right-id : ∀ {ℓ} {A B : Set ℓ} (f : A ⇀ B) → f • id ≡ f
•-right-id {ℓ} f = funext ℓ ℓ (λ _ → refl)

_⊑M_ : {B : Set} → Rel (Maybe B) lzero
just a ⊑M just b  = a ≡ b
just x ⊑M nothing = ⊥
nothing ⊑M b      = ⊤

⊑M-refl : {B : Set} (b : Maybe B) → b ⊑M b
⊑M-refl nothing  = tt
⊑M-refl (just _) = refl

_⊑_ : {A B : Set} → Rel (A ⇀ B) lzero
f ⊑ g = ∀ a → f a ⊑M g a

infix 4 _⊑_

⊑-refl : {A B : Set} (f : A ⇀ B) → f ⊑ f
⊑-refl f = λ a → ⊑M-refl (f a)

⊑-trans : {A B : Set} (f g h : A ⇀ B) → f ⊑ g → g ⊑ h
⊑-trans f g h f⊑g

------------------------------------------------------------

record _⇌_ (A B : Set) : Set where
  field
    fwd      : A → Maybe B
    bwd      : B → Maybe A
    left-id  : bwd • fwd ⊑ id
    right-id : fwd • bwd ⊑ id

_∘_ : {A B C : Set} → (B ⇌ C) → (A ⇌ B) → (A ⇌ C)
g ∘ f = record
  { fwd = g.fwd • f.fwd
  ; bwd = f.bwd • g.bwd
  ; left-id  = ∘-left-id
  ; right-id = ∘-right-id
  }
  where
    module f = _⇌_ f
    module g = _⇌_ g

    ∘-left-id : (f.bwd • g.bwd) • (g.fwd • f.fwd) ⊑ id
    ∘-left-id = {!!}

      {-
           (f.bwd • g.bwd) • (g.fwd • f.fwd)
         ≡ { •-assoc }
           ((f.bwd • g.bwd) • g.fwd) • f.fwd
         ≡ { •-assoc }
           (f.bwd • (g.bwd • g.fwd)) • f.fwd
         ⊑ { g.left-id , monotonicity }
           (f.bwd • id) • f.fwd
         ≡ { id is right identity }
           f.bwd • f.fwd
         ⊑
           id
      -}

    ∘-right-id : (g.fwd • f.fwd) • (f.bwd • g.bwd) ⊑ id
    ∘-right-id = {!!}
