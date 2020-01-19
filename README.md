# Interconfection for Racket

[![Travis build](https://travis-ci.org/lathe/interconfection-for-racket.svg?branch=master)](https://travis-ci.org/lathe/interconfection-for-racket)

Interconfection is a library for building extensible systems, especially module systems. Interconfection extensions cooperate using a kind of quasi-deterministic concurrency, reflecting the reality of a cultural context where authors have developed and published their extensions without staying in perfect lockstep with each other's work. Interconfection's concurrency is an expressive solution to module system design concerns having to do with closed-world and open-world extensibility, including the Expression Problem.

Since the extensions of an Interconfection system are considered to be separate processes that communicate, there is a sense in which Interconfection is all about side effects. However, Interconfection's side effects and Racket's side effects work at cross purposes. Careless use of Racket side effects can break some of the encapsulation Interconfection relies upon to enforce determinism. Hence, Interconfection is most useful for Racket programs written in a certain purely functional style. Interconfection's own side effects are expressed using techniques like monads so that they play well with that pure functional style.


## Quasi-determinism

_Quasi-determinism_ is a notion explored in "[Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars](https://www.cs.indiana.edu/~lkuper/papers/lvish-popl14.pdf)." No two runs of the same quasi-deterministic computation return different values, but some runs are allowed _not_ to return a value because they encounter synchronization errors, out-of-memory conditions, nontermination, or other detours.

For many realistic systems, quasi-determinism is semantically justified by the fact that the program can't determine for itself whether the user will pull the plug on it, and there's nothing it can do in that situation to return the correct result.

For the purposes of Interconfection, we actually use a somewhat stricter form of quasi-determinism: Yes our processes can shirk determinism if they encounter errors or resource exhaustion, but we still consider the fact that an error occurred to be part of the program's result. That is, if there are sufficient resources to run an Interconfection program and at least one error occurs, then at least one error is bound to occur no matter how many times we try to run it. (It's possible for it to be a different set of errors each time.)

Because of this slightly stronger determinism, Interconfection can't make much use of the LVar approach's "freeze after writing" technique. Using that technique, one process freezes a state resource so that later writes to that resource cause errors. In Interconfection, such a "freeze" can't occur until after we manage to guarentee there will be no more write attempts, at which point it doesn't accomplish much anyway.

Nevertheless, a similar effect can be achieved in Interconfection using a subsystem that's been designed for closed-world extensibility. Using a system of "tickets," which essentially maintain a reference count to the shared resource, it's possible to detect when there are no tickets remaining, at which point the _complete set_ of writes is known and can be passed along to further computations that need to use it.


## Order-invariance

The topic of concurrency might call to mind race conditions, but there are no race conditions as long as the order of effects doesn't matter. When those effects accumulate contributions to a set, then it's important that the computation that acts on that complete set can't detect what order the contributions were made in.

For that reason, many of the exports of Interconfection are operations we call _clines_, _dexes_, _merges_, and _fuses_, specifically designed for order-invariant manipulation of sets of values.


## Purity

Unfortunately, the arbitrary use of Racket side effects can record the order that the Racket code runs in, which can break the order-invariance of Interconfection's abstractions and thereby create true race conditions. Interconfection is designed for use in a more purely functional Racket programming style.

There are certain operations we're committed to calling "pure," in particular `raise`, `lambda`, and `#%app` (the function call operation). This is true even though `lambda` and `#%app` can risk out-of-memory errors and nontermination, even though a `lambda` expression can allocate a new value each time it's called, and even though `raise` and `#%app` (with the wrong arity) can cause run time errors.

Generally speaking, if a Racket operation obeys Interconfection's notion of quasi-determinism, has no external or internal side effects, and cannot be used to detect an impurity in `raise`, `lambda`, or `#%app`, then we consider it pure.

Of course, we consider operations like `set!`, `parameterize`, and the invocation of first-class continuations to be impure because they break referential transparency: They make it so the results of two identical expressions in the same lexical scope can be two completely different values. And we consider calls to procedures like `display` to be impure even though they always have the same return value, since having two identical `display` expressions in the same lexical scope has a different effect than having just one and reusing its result.

For Interconfection's purposes, we consider certain things like `eq?`, and anything like `equal?` that depends on them, to be impure operations. That's because they could otherwise detect an impurity in `lambda`. By taking this point of view, many other operations can be considered pure, like `list` and `append`. An impure program can distinguish the results of `(list 1 2)` and `(list 1 2)` using `eq?`, but a pure program finds them to be indistinguishable.

We consider it impure to catch an exception without (either exhausting resources or) raising an exception to replace it. By catching exceptions, a Racket program can detect which of two subcomputations was attempted first, which directly defeats the order invariance Interconfection's abstractions establish and depend on for their quasi-determinism.

There may be a few more subtleties than this.

There are cases where a Racket program may have to resort to impurity at the edges even if it makes use of Interconfection in regions of relative purity. For instance, the `struct` operation itself is impure since it generates a new structure type identity each time it's used, but Racket programs don't have a lot of other options for coining user-defined, encapsulated data types. Similarly, quite a number of essential operations in Racket's macro system are impure. As long as the functions passed to Interconfection operations are pure, these other impure techniques should be fine.


## Overview of the Interconfection codebase

For now, Interconfection offers a couple of modules:

  - `interconfection/order` - A module that re-exports `interconfection/order/base` and may someday offer more auxiliary utilities alongside it.
    - `interconfection/order/base` - A module offering basic support for doing comparisons and doing orderless merge operations.

API documentation is maintained in this repo and [hosted at the Racket website](https://docs.racket-lang.org/interconfection/).
