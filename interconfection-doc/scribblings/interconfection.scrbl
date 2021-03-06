#lang parendown scribble/manual

@; interconfection/scribblings/interconfection.scrbl
@;
@; A library for building extensible systems, especially module
@; systems.

@;   Copyright 2017-2020 The Lathe Authors
@;
@;   Licensed under the Apache License, Version 2.0 (the "License");
@;   you may not use this file except in compliance with the License.
@;   You may obtain a copy of the License at
@;
@;       http://www.apache.org/licenses/LICENSE-2.0
@;
@;   Unless required by applicable law or agreed to in writing,
@;   software distributed under the License is distributed on an
@;   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
@;   either express or implied. See the License for the specific
@;   language governing permissions and limitations under the License.


@(require #/for-label racket/base)
@(require #/for-label #/only-in racket/contract/base
  -> any/c =/c cons/c contract? contract-name list/c listof)
@(require #/for-label #/only-in racket/contract/combinator
  contract-first-order)

@(require #/for-label #/only-in lathe-comforts/maybe
  just maybe? maybe/c nothing)
@(require #/for-label #/only-in lathe-comforts/struct tupler/c)
@(require #/for-label #/only-in lathe-comforts/trivial trivial?)

@(require #/for-label interconfection/extensibility/base)
@(require #/for-label interconfection/order)
@(require #/for-label interconfection/order/base)


@title{Interconfection}

Interconfection is a library for building extensible systems, especially module systems. Interconfection extensions cooperate using a kind of quasi-deterministic concurrency, reflecting the reality of a cultural context where authors have developed and published their extensions without staying in perfect lockstep with each other's work. Interconfection's concurrency is an expressive solution to module system design concerns having to do with closed-world and open-world extensibility, including the Expression Problem.

Since the extensions of an Interconfection system are considered to be separate processes that communicate, there is a sense in which Interconfection is all about side effects. However, Interconfection's side effects and Racket's side effects work at cross purposes. Careless use of Racket side effects can break some of the encapsulation Interconfection relies upon to enforce determinism. Hence, Interconfection is most useful for Racket programs written in a certain purely functional style. Interconfection's own side effects are expressed using techniques like monads so that they play well with that pure functional style.



@table-of-contents[]



@section[#:tag "concepts"]{Interconfection concepts}


@subsection[#:tag "quasi-determinism"]{Quasi-determinism}

@deftech{Quasi-determinism} is a notion explored in "@hyperlink["https://www.cs.indiana.edu/~lkuper/papers/lvish-popl14.pdf"]{Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars}." No two runs of the same quasi-deterministic computation return different values, but some runs are allowed @emph{not} to return a value because they encounter synchronization errors, out-of-memory conditions, nontermination, or other detours.

For many realistic systems, quasi-determinism is semantically justified by the fact that the program can't determine for itself whether the user will pull the plug on it, and there's nothing it can do in that situation to return the correct result.

For the purposes of Interconfection, we actually use a somewhat stricter form of quasi-determinism: Yes our processes can shirk determinism if they encounter errors or resource exhaustion, but we still consider the fact that an error occurred to be part of the program's result. That is, if there are sufficient resources to run an Interconfection program and at least one error occurs, then at least one error is bound to occur no matter how many times we try to run it. (It's possible for it to be a different set of errors each time.)

Because of this slightly stronger determinism, Interconfection can't make much use of the LVar approach's "freeze after writing" technique. Using that technique, one process freezes a state resource so that later writes to that resource cause errors. In Interconfection, such a "freeze" can't occur until after we manage to guarentee there will be no more write attempts, at which point it doesn't accomplish much anyway.

Nevertheless, a similar effect can be achieved in Interconfection using a subsystem that's been designed for closed-world extensibility. Using a system of "tickets," which essentially maintain a reference count to the shared resource, it's possible to detect when there are no tickets remaining, at which point the @emph{complete set} of writes is known and can be passed along to further computations that need to use it.


@subsection[#:tag "order-invariance"]{Order-invariance}

The topic of concurrency might call to mind race conditions, but there are no race conditions as long as the order of effects doesn't matter. When those effects accumulate contributions to a set, then it's important that the computation that acts on that complete set can't detect what order the contributions were made in.

For that reason, many of the exports of Interconfection are operations we call @tech{clines}, @tech[#:key "dex"]{dexes}, @tech{merges}, and @tech{fuses}, specifically designed for order-invariant manipulation of sets of values.


@subsection[#:tag "purity"]{Purity}

Unfortunately, the arbitrary use of Racket side effects can record the order that the Racket code runs in, which can break the order-invariance of Interconfection's abstractions and thereby create true race conditions. Interconfection is designed for use in a more @deftech{purely functional} Racket programming style.

There are certain operations we're committed to calling "pure," in particular @racket[raise], @racket[lambda], and @racket[#%app] (the function call operation). This is true even though @racket[lambda] and @racket[#%app] can risk out-of-memory errors and nontermination, even though a @racket[lambda] expression can allocate a new value each time it's called, and even though @racket[raise] and @racket[#%app] (with the wrong arity) can cause run time errors.

Generally speaking, if a Racket operation obeys Interconfection's notion of quasi-determinism, has no external or internal side effects, and cannot be used to detect an impurity in @racket[raise], @racket[lambda], or @racket[#%app], then we consider it pure.

Of course, we consider operations like @racket[set!], @racket[parameterize], and the invocation of first-class continuations to be impure because they break referential transparency: They make it so the results of two identical expressions in the same lexical scope can be two completely different values. And we consider calls to procedures like @racket[display] to be impure even though they always have the same return value, since having two identical @racket[display] expressions in the same lexical scope has a different effect than having just one and reusing its result.

For Interconfection's purposes, we consider certain things like @racket[eq?], and anything like @racket[equal?] that depends on them, to be impure operations. That's because they could otherwise detect an impurity in @racket[lambda]. By taking this point of view, many other operations can be considered pure, like @racket[list] and @racket[append]. An impure program can distinguish the results of @racket[(list 1 2)] and @racket[(list 1 2)] using @racket[eq?], but a pure program finds them to be indistinguishable.

We consider it impure to catch an exception without (either exhausting resources or) raising an exception to replace it. By catching exceptions, a Racket program can detect which of two subcomputations was attempted first, which directly defeats the order invariance Interconfection's abstractions establish and depend on for their quasi-determinism.

There may be a few more subtleties than this.

There are cases where a Racket program may have to resort to impurity at the edges even if it makes use of Interconfection in regions of relative purity. For instance, the @racket[struct] operation itself is impure since it generates a new structure type identity each time it's used, but Racket programs don't have a lot of other options for coining user-defined, encapsulated data types. Similarly, quite a number of essential operations in Racket's macro system are impure. As long as the functions passed to Interconfection operations are pure, these other impure techniques should be fine.


@section[#:tag "order"]{Order}

@defmodule[interconfection/order/base]

A @deftech{cline} is based on a total ordering on values in its domain, or in other words a binary relation that is reflexive, transitive, and antisymmetric. Its antisymmetry is as fine-grained as possible: If any two values in a cline’s domain are related by that cline in both directions, only @tech[#:key "purely functional"]{impure} code will be able to distinguish the two values.

However, a cline does not merely expose this total ordering. Within the cline’s domain, there may be equivalence classes of values for which every two nonequal values will not have their relative order exposed to pure code. When pure code uses @racket[getfx-compare-by-cline] to compare two values by a cline, it can get several results:

@itemlist[
    @item{@racket[(nothing)]: The values are not both in the domain.}
    @item{@racket[(just (ordering-lt))]: The first value candidly precedes the second.}
    @item{@racket[(just (ordering-eq))]: The first value is equal to the second.}
    @item{@racket[(just (ordering-private))]: The two values are not equal, and one of them secretly precedes the other, but they fall into the same equivalence class.}
    @item{@racket[(just (ordering-gt))]: The first value candidly follows the second.}
]

A @deftech{dex} is like a cline, but it never results in the “candidly precedes” and “candidly follows” cases. Thus, a dex is useful as a kind of equality test.

All the exports of @tt{interconfection/order/base} are also exported by @racketmodname[interconfection/order].


@subsection[#:tag "orderings"]{Orderings}

@deftogether[(
  @defidform[ordering-lt]
  @defform[#:link-target? #f (ordering-lt)]
  @defform[#:kind "match expander" #:link-target? #f (ordering-lt)]
  @defproc[(ordering-lt? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a value that represents the result of a comparison where the first value turned out to be candidly strictly less than the second value.
  
  For the purposes of @tech[#:key "purely functional"]{impure} Racket code, every two @tt{ordering-lt} values are @racket[equal?].
}

@deftogether[(
  @defidform[ordering-eq]
  @defform[#:link-target? #f (ordering-eq)]
  @defform[#:kind "match expander" #:link-target? #f (ordering-eq)]
  @defproc[(ordering-eq? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a value that represents the result of a comparison where the first value turned out to be equal to the second value.
  
  For the purposes of @tech[#:key "purely functional"]{impure} Racket code, every two @tt{ordering-eq} values are @racket[equal?].
}

@deftogether[(
  @defidform[ordering-private]
  @defform[#:link-target? #f (ordering-private)]
  @defform[#:kind "match expander" #:link-target? #f (ordering-private)]
  @defproc[(ordering-private? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a value that represents the result of a comparison where the first value turned out to be secretly strictly less than or secretly strictly greater than the second value.
  
  For the purposes of @tech[#:key "purely functional"]{impure} Racket code, every two @tt{ordering-private} values are @racket[equal?].
}

@deftogether[(
  @defidform[ordering-gt]
  @defform[#:link-target? #f (ordering-gt)]
  @defform[#:kind "match expander" #:link-target? #f (ordering-gt)]
  @defproc[(ordering-gt? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a value that represents the result of a comparison where the first value turned out to be candidly strictly greater than the second value.
  
  For the purposes of @tech[#:key "purely functional"]{impure} Racket code, every two @tt{ordering-gt} values are @racket[equal?].
}

@defproc[(dex-result? [x any/c]) boolean?]{
  Returns whether the given value is a possible result for a dex (something that satisfies either @racket[ordering-eq?] or @racket[ordering-private?]).
}

@defproc[(cline-result? [x any/c]) boolean?]{
  Returns whether the given value is a possible result for a dex (something that satisfies @racket[ordering-lt?], @racket[dex-result?], or @racket[ordering-gt?]).
}


@subsection[#:tag "dexes"]{Names, Dexes, and Dexed Values}

@defproc[(name? [x any/c]) boolean?]{
  Returns whether the given value is a name. In Interconfection, a @deftech{name} is something like a partial application of comparison by a @tech{dex}. Any value can be converted to a name using @racket[getfx-name-of] if any dex for that value is at hand (and it always converts to the same name regardless of which dex is chosen), and names themselves can be compared using @racket[(dex-name)].
}


@defproc[(dex? [x any/c]) boolean?]{
  Returns whether the given value is a dex.
}

@defproc[(getfx-is-in-dex [dex dex?] [x any/c]) (getfx/c boolean?)]{
  Given a dex and a value, returns a @racket[getfx?] computation that computes whether the value belongs to the dex's domain.
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given dex. This is one way to "call" a dex.
}

@defproc[
  (getfx-name-of [dex dex?] [x any/c])
  (getfx/c (maybe/c name?))
]{
  Given a dex and a value, returns a @racket[getfx?] computation. If the value belongs to the dex's domain, this computation results in a @racket[just] of a @tech{name} that the value can be compared by. Otherwise, it results in a @racket[nothing].
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given dex. This is one way to "call" a dex.
}

@defproc[
  (getfx-dexed-of [dex dex?] [x any/c])
  (getfx/c (maybe/c dexed?))
]{
  Given a dex and a value, returns a @racket[just] of a @tech[#:key "dexed value"]{dexed} version of the given value, if the value belongs to the dex's domain; otherwise returns a @racket[nothing].
  Given a dex and a value, returns a @racket[getfx?] computation. If the value belongs to the dex's domain, this computation results in a @racket[just] of a dexed version of the given value. Otherwise, it results in a @racket[nothing].
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given dex. This is one way to "call" a dex.
}

@defproc[
  (getfx-compare-by-dex [dex dex?] [a any/c] [b any/c])
  (getfx/c (maybe/c dex-result?))
]{
  Given a dex and two values, returns a @racket[getfx?] computation that compares those values according to the dex. The result is @racket[(nothing)] if either value is outside the dex's domain.
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given dex. This is one way to "call" a dex.
}


@defproc[(dexed? [x any/c]) boolean?]{
  Returns whether the given value is a dexed value. In Interconfection, a @deftech{dexed value} is a container that carries a value, its @tech{name}, and a dex that recognizes only that value. Dexed values and @tech{names} are obtained in similar ways (@racket[getfx-dexed-of] and @racket[getfx-name-of]) and both serve the purpose of being a value that can identify itself, but they differ in transparency: Dexed values allow the original value to be retrieved, whereas names can do nothing but be compared to other names.
}

@defproc[(dexed/c [c contract?]) contract?]{
  Returns a contract that recognizes a @tech{dexed value} and additionally imposes the given contract on its @racket[dexed-get-value]. That contract's projection must be @racket[ordering-eq] to the original value. This essentially means the contract must be first-order.
}

@defproc[(dexed-first-order/c [c contract?]) contract?]{
  Returns a contract that recognizes a @tech{dexed value} and additionally imposes the first-order behavior of the given contract on its @racket[dexed-get-value]. It ignores the contract's higher-order behavior altgoether, so using certain contracts with @tt{dexed-first-order/c} has little purpose other than documentation value.
  
  This is nearly the same as @racket[(dexed/c (contract-first-order c))], but its @racket[contract-name] is based on that of @racket[c].
}

@defproc[(dexed-get-dex [d dexed?]) dex?]{
  Given a @tech{dexed value}, returns a dex that has a domain consisting of just one value, namely the value of the given dexed value.
  
  A call to the resulting dex can be run through @racket[pure-run-getfx] without problems.
  
  When compared by @racket[(dex-dex)], all @tt{dexed-get-dex} results are @racket[ordering-eq] if the corresponding @racket[dexed-get-value] results are.
}

@defproc[(dexed-get-name [d dexed?]) name?]{
  Given a @tech{dexed value}, returns the @tech{name} of its value.
}

@defproc[(dexed-get-value [d dexed?]) any/c]{
  Given a @tech{dexed value}, returns its value.
}


@defproc[(dex-name) dex?]{
  Returns a dex that compares @tech{names}.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@defproc[(dex-dex) dex?]{
  Returns a dex that compares dexes.
  
  All presently existing dexes allow this comparison to be fine-grained enough that it trivializes their equational theory. For instance, @racket[(dex-default (dex-give-up) (dex-give-up))] and @racket[(dex-give-up)] can be distinguished this way despite otherwise having equivalent behavior.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@; TODO: Add this to Cene for Racket.
@defproc[(dex-dexed) dex?]{
  Returns a dex that compares @tech{dexed values}.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}


@defproc[(dex-give-up) dex?]{
  Returns a dex over an empty domain.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@defproc[
  (dex-default
    [dex-for-trying-first dex?]
    [dex-for-trying-second dex?])
  dex?
]{
  Given two dexes, returns a dex over the union of their domains.
  
  For the sake of nontermination, error, and performance concerns, this attempts to compute the result using @racket[dex-for-trying-first] before it moves on to @racket[dex-for-trying-second].
  
  The invocation of @racket[dex-for-trying-second] is a tail call.
  
  If calls to the given dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-default} values are @racket[ordering-eq] if their @racket[dex-for-trying-first] values are and their @racket[dex-for-trying-second] values are.
}

@defproc[(dex-opaque [name name?] [dex dex?]) dex?]{
  Given a @tech{name} and a dex, returns another dex that behaves like the given one but is not equal to it.
  
  If calls to the given dex can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-opaque} values are @racket[ordering-eq] if their @racket[name] values are and their @racket[dex] values are.
}

@defproc[
  (dex-by-own-method
    [dexed-getfx-get-method
      (dexed-first-order/c (-> any/c (getfx/c (maybe/c dex?))))])
  dex?
]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a dex that works like so:
  
  @itemlist[
    #:style 'ordered
    @item{
      It invokes the @racket[getfx?] operation with each value. If any of these invocations results in @racket[(nothing)], those values are not considered to be in this dex's domain, and the overall result is @racket[(nothing)]. Otherwise, the computation proceeds:
    }
    @item{
      It checks that the dex methods obtained this way are all @racket[ordering-eq]. If they're not, the values are evidently distinguishable, and the overall result is @racket[(just (ordering-private))]. Otherwise, the computation proceeds:
    }
    @item{
      It tail-calls the method.
    }
  ]
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-get-method] and the calls to their resulting dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-by-own-method} values are @racket[ordering-eq] if their @racket[dexed-getfx-get-method] values are.
}

@defproc[
  (dex-fix
    [dexed-getfx-unwrap
      (dexed-first-order/c (-> dex? (getfx/c dex?)))])
  dex?
]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a dex that works by passing itself to the operation and then tail-calling the resulting dex.
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-unwrap] and the calls to their resulting dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-fix} values are @racket[ordering-eq] if their @racket[dexed-getfx-unwrap] values are.
}

@defform[
  (dex-tuple-by-field-position tupler-expr
    [field-position-nat dex-expr]
    ...)
  
  #:contracts
  (
    [tupler-expr (tupler/c (=/c (length '(dex-expr ...))))]
    [dex-expr dex?])
]{
  Returns a dex that compares instances of the given tupler if their field values can be compared by the dexes produced by the @racket[dex-expr] expressions.
  
  Each @racket[field-position-nat] must be a distinct number indicating which field should be checked by the associated dex, and there must be an entry for every field.
  
  For the sake of nontermination, error, and performance concerns, this dex computes by attempting the given dexes in the order they appear in this call. If a dex before the last one determines a non-@racket[ordering-eq] result, the following dexes are only checked to be sure their domains contain the respective field values. Otherwise, the last dex, if any, is attempted as a tail call.
  
  If calls to the given dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-tuple-by-field-position} values are @racket[ordering-eq] if they're for the same tupler, if they have @racket[field-position-nat] values in the same sequence, and if their @racket[dex-expr] values are @racket[ordering-eq].
}

@defform[
  (dex-tuple tupler-expr dex-expr ...)
  
  #:contracts
  (
    [tupler-expr (tupler/c (=/c (length '(dex-expr ...))))]
    [dex-expr dex?])
]{
  Returns a dex that compares instances of the given tupler if their field values can be compared by the dexes produced by the @racket[dex-expr] expressions.
  
  For the sake of nontermination, error, and performance concerns, this dex computes by attempting the given dexes in the order they appear in this call. The last dex, if any, is attempted as a tail call.
  
  If calls to the given dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], each @tt{dex-tuple} value is @racket[ordering-eq] to the equivalent @racket[dex-tuple-by-field-position] value.
}


@subsection[#:tag "clines"]{Clines}

@defproc[(cline? [x any/c]) boolean?]{
  Returns whether the given value is a cline.
}

@defproc[(get-dex-from-cline [cline cline?]) dex?]{
  Given a cline, returns a dex over the same domain.
  
  If calls to the given cline can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting dex.
}

@defproc[
  (getfx-is-in-cline [cline cline?] [x any/c])
  (getfx/c boolean?)
]{
  Given a cline and a value, returns a @racket[getfx?] computation that computes whether the value belongs to the cline's domain.
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given cline. This is one way to "call" a cline.
}

@defproc[
  (getfx-compare-by-cline [cline cline?] [a any/c] [b any/c])
  (getfx/c (maybe/c cline-result?))
]{
  Given a cline and two values, returns a @racket[getfx?] computation that compares those values according to the cline. The result is @racket[(nothing)] if either value is outside the cline's domain.
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given cline. This is one way to "call" a cline.
}

@defproc[(dex-cline) dex?]{
  Returns a dex that compares clines.
  
  Almost all presently existing clines allow this comparison to be fine-grained enough that it trivializes their equational theory. For instance, @racket[(cline-default (cline-give-up) (cline-give-up))] and @racket[(cline-give-up)] can be distinguished this way despite otherwise having equivalent behavior. One exception is that calling @racket[cline-flip] twice in a row results in a cline that's @racket[ordering-eq] to the original.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}


@defproc[(cline-by-dex [dex dex?]) cline?]{
  Returns a cline that compares values by tail-calling the given dex. Since the dex never returns the "candidly precedes" or "candidly follows" results, this cline doesn't either.
  
  If calls to the given dex can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-by-dex} values are @racket[ordering-eq] if their dexes are.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the original @racket[dex].
}

@defproc[(cline-give-up) cline?]{
  Returns a cline over an empty domain.
  
  A call to this cline can be run through @racket[pure-run-getfx] without problems.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to @racket[(dex-give-up)].
}

@defproc[
  (cline-default
    [cline-for-trying-first cline?]
    [cline-for-trying-second cline?])
  cline?
]{
  Given two clines, returns a cline over the union of their domains. The resulting cline’s ascending order consists of the first cline’s ascending order in its domain, followed by the second cline’s ascending order outside the first cline’s domain.
  
  For the sake of nontermination, error, and performance concerns, this attempts to compute the result using @racket[cline-for-trying-first] before it moves on to @racket[cline-for-trying-second].
  
  The invocation of @racket[cline-for-trying-second] is a tail call.
  
  If calls to the given clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-default} values are @racket[ordering-eq] if their @racket[cline-for-trying-first] values are and their @racket[cline-for-trying-second] values are.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the similarly constructed @racket[dex-default].
}

@defproc[(cline-opaque [name name?] [cline cline?]) cline?]{
  Given a @tech{name} and a cline, returns another cline that behaves like the given one but is not equal to it.
  
  If calls to the given cline can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-opaque} values are @racket[ordering-eq] if their @racket[name] values are and their @racket[cline] values are.
}

@defproc[
  (cline-by-own-method
    [dexed-getfx-get-method
      (dexed-first-order/c (-> any/c (getfx/c (maybe/c cline?))))])
  cline?
]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a cline that works like so:
  
  @itemlist[
    #:style 'ordered
    @item{
      It invokes the @racket[getfx?] operation with each value. If any of these invocations results in @racket[(nothing)], those values are not considered to be in this cline's domain, and the overall result is @racket[(nothing)]. Otherwise, the computation proceeds:
    }
    @item{
      It checks that the cline methods obtained this way are all @racket[ordering-eq]. If they're not, it raises an error. Otherwise, the computation proceeds:
    }
    @item{
      It tail-calls the method.
    }
  ]
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-get-method] and the calls to their resulting clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-by-own-method} values are @racket[ordering-eq] if their @racket[dexed-getfx-get-method] values are.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to another dex only if that dex was obtained the same way from a cline @racket[ordering-eq] to this one.
}

@defproc[
  (cline-fix
    [dexed-getfx-unwrap
      (dexed-first-order/c (-> cline? (getfx/c cline?)))])
  cline?
]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a cline that works by passing itself to the operation and then tail-calling the resulting cline.
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-unwrap] and the calls to their resulting clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-fix} values are @racket[ordering-eq] if their @racket[dexed-getfx-unwrap] values are.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to another dex only if that dex was obtained the same way from a cline @racket[ordering-eq] to this one.
}

@defform[
  (cline-tuple-by-field-position tupler-expr
    [field-position-nat cline-expr]
    ...)
  
  #:contracts
  (
    [tupler-expr (tupler/c (=/c (length '(cline-expr ...))))]
    [cline-expr cline?])
]{
  Returns a cline that compares instances of the given tupler if their field values can be compared by the clines produced by the @racket[cline-expr] expressions. The comparison is lexicographic, with the most significant comparisons being the @racket[cline-expr] values that appear earliest in this call.
  
  Each @racket[field-position-nat] must be a distinct number indicating which field should be checked by the associated cline, and there must be an entry for every field.
  
  For the sake of nontermination, error, and performance concerns, this cline computes by attempting the given clines in the order they appear in this call. If a cline before the last one determines a non-@racket[ordering-eq] result, the following clines are only checked to be sure their domains contain the respective field values. Otherwise, the last cline, if any, is attempted as a tail call.
  
  If calls to the given clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-tuple-by-field-position} values are @racket[ordering-eq] if they're for the same tupler, if they have @racket[field-position-nat] values in the same sequence, and if their @racket[cline-expr] values are @racket[ordering-eq].
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the similarly constructed @racket[dex-tuple-by-field-position].
}

@defform[
  (cline-tuple tupler-expr cline-expr ...)
  
  #:contracts
  (
    [tupler-expr (tupler/c (=/c (length '(cline-expr ...))))]
    [cline-expr cline?])
]{
  Returns a cline that compares instances of the given tupler if their field values can be compared by the clines produced by the @racket[cline-expr] expressions. The comparison is lexicographic, with the most significant comparisons being the @racket[cline-expr] values that appear earliest in this call.
  
  For the sake of nontermination, error, and performance concerns, this cline computes by attempting the given clines in the order they appear in this call. If a cline before the last one determines a non-@racket[ordering-eq] result, the following clines are only checked to be sure their domains contain the respective field values. Otherwise, the last cline, if any, is attempted as a tail call.
  
  If calls to the given clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], each @tt{cline-tuple} value is @racket[ordering-eq] to the equivalent @racket[cline-tuple-by-field-position] value.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the similarly constructed @racket[dex-tuple].
}

@; TODO: Add this to Cene for Racket.
@defproc[(cline-flip [cline cline?]) cline?]{
  Returns a cline that compares values by calling the given dex but reverses the "candidly precedes" and "candidly follows" results (@racket[ordering-lt] and @racket[ordering-gt]). It dosn't reverse the "secretly precedes" and "secretly follows" results.
  
  If calls to the given cline can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting cline.
  
  When compared by @racket[(dex-cline)], @tt{cline-flip} values are usually @racket[ordering-eq] if their given clines are. The one exception is that calling @tt{cline-flip} twice in a row has no effect; the result of the second call is @racket[ordering-eq] to the original cline. This behavior is experimental; future revisions to this library may remove this exception or add more exceptions (such as having @racket[(@#,tt{cline-flip} (cline-default _a _b))] be @racket[ordering-eq] to @racket[(cline-default (@#,tt{cline-flip} _a) (@#,tt{cline-flip} _b))]).
  
  @; TODO: Stabilize that behavior.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the dex obtained the same way from the original cline.
}


@subsection[#:tag "merges-and-fuses"]{Merges and Fuses}

Interconfection offers a non-exhaustive but extensive selection of @deftech{merges} and @deftech{fuses}. These are values which can be compared for equality with like values (using @racket[(dex-merge)] and @racket[(dex-fuse)]), and they represent operations of two arguments (invocable using @racket[getfx-call-merge] and @racket[getfx-call-fuse]).

Merges represent operations that are commutative, associative, and idempotent, or in other words exactly the kind of operation that can operate on a (nonempty and finite) unordered set of inputs.

Fuses represent operations that are commutative and associative (and not necessarily idempotent). A fuse is ideal for operating on a (nonempty and finite) unordered @emph{multiset} of inputs.

The idempotence of a merge operation is such that if the two inputs to the merge are @racket[ordering-eq] by any dex, the result will be @racket[ordering-eq] to them both by the same dex.

Calling a merge/fuse is a partial operation. A single merge/fuse is associated with certain domains of values it works on, and these domains are disjoint from each other. If it's given a set/multiset of operands that are all elements of the same domain, it returns a @racket[just] of another value in that domain. If it's given a set/multiset of operands that don't all belong to the same domain, it returns @racket[(nothing)], even if each operand belongs to some domain it accepts.


@deftogether[(
  @defproc[(merge? [x any/c]) boolean?]
  @defproc[(fuse? [x any/c]) boolean?]
)]{
  Returns whether the given value is a merge/fuse.
}

@deftogether[(
  @defproc[
    (getfx-call-merge [merge merge?] [a any/c] [b any/c])
    (getfx/c maybe?)
  ]
  @defproc[
    (getfx-call-fuse [fuse fuse?] [a any/c] [b any/c])
    (getfx/c maybe?)
  ]
)]{
  Given a merge/fuse and two values, this @racket[getfx?] computation combines those values according to the merge/fuse. The result is @racket[(nothing)] if the two values don't both belong to the same domain of the merge/fuse. Otherwise, the result is @racket[(just _value)] for some @var[value] that also belongs to that domain.
  
  Whether this @racket[getfx?] computation can be run through @racket[pure-run-getfx] without problems depends on the given merge/fuse.
  
  For @tt{getfx-call-merge}, if there is any dex for which the input values are @racket[ordering-eq], then the result will be @racket[ordering-eq] to them both.
}

@deftogether[(
  @defproc[(dex-merge) dex?]
  @defproc[(dex-fuse) dex?]
)]{
  Returns a dex that compares merges/fuses.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}


@defproc[(merge-by-dex [dex dex?]) merge?]{
  Returns a merge that merges any values that are already @racket[ordering-eq] according the given dex. The result of the merge is @racket[ordering-eq] to both of the inputs.
  
  Note that this tends to be a merge with many domains, one domain for each value accepted by the given dex. In other words, two values that are each accepted by the given dex but which aren't @racket[ordering-eq] will not belong to the same domain of this merge, so the result of @racket[getfx-call-merge] on those values will be @racket[(nothing)].
  
  If calls to the given dex can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge.
  
  When compared by @racket[(dex-merge)], all @tt{merge-by-dex} values are @racket[ordering-eq] if their dexes are.
}

@; TODO: Add this to Cene for Racket.
@defproc[(merge-by-cline-min [cline cline?]) merge?]{
  Returns a merge that finds the minimum of any set of values in the given cline's domain. The result of the merge is @racket[ordering-eq] to at least one of the inputs, and it's @racket[ordering-lt] to the rest.
  
  If calls to the given cline can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge.
  
  When compared by @racket[(dex-merge)], all @tt{merge-by-cline-min} values are @racket[ordering-eq] if their clines are. They're also @racket[ordering-eq] to @racket[(merge-by-cline-max (cline-flip cline))].
}

@; TODO: Add this to Cene for Racket.
@defproc[(merge-by-cline-max [cline cline?]) merge?]{
  Returns a merge that finds the maximum of any set of values in the given cline's domain. The result of the merge is @racket[ordering-eq] to at least one of the inputs, and it's @racket[ordering-gt] to the rest.
  
  If calls to the given cline can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge.
  
  When compared by @racket[(dex-merge)], all @tt{merge-by-cline-max} values are @racket[ordering-eq] if their clines are. They're also @racket[ordering-eq] to @racket[(merge-by-cline-min (cline-flip cline))].
}

@defproc[(fuse-by-merge [merge merge?]) fuse?]{
  Returns a fuse that fuses values by merging them using the given merge.
  
  If calls to the given merge can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting fuse.
  
  When compared by @racket[(dex-fuse)], all @tt{fuse-by-merge} values are @racket[ordering-eq] if their merges are.
}

@deftogether[(
  @defproc[(merge-opaque [name name?] [merge merge?]) merge?]
  @defproc[(fuse-opaque [name name?] [fuse fuse?]) fuse?]
)]{
  Given a @tech{name} and a merge/fuse, returns another merge/fuse that behaves like the given one but is not equal to it.
  
  If calls to the given merge/fuse can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], all @tt{merge-opaque}/@tt{fuse-opaque} values are @racket[ordering-eq] if their @racket[name] values are and their @racket[merge]/@racket[fuse] values are.
}

@deftogether[(
  @defproc[
    (merge-by-own-method
      [dexed-getfx-get-method
        (dexed-first-order/c (-> any/c (getfx/c (maybe/c merge?))))])
    merge?
  ]
  @defproc[
    (fuse-by-own-method
      [dexed-getfx-get-method
        (dexed-first-order/c (-> any/c (getfx/c (maybe/c fuse?))))])
    fuse?
  ]
)]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a merge/fuse that works like so:
  
  @itemlist[
    #:style 'ordered
    @item{
      It invokes the @racket[getfx?] operation with each value. If any of these invocations results in @racket[(nothing)], those values are not considered to be in any of this merge's/fuse's domains, and the overall result is @racket[(nothing)]. Otherwise, the computation proceeds:
    }
    @item{
      It checks that the merge/fuse methods obtained this way are all @racket[ordering-eq]. If they're not, the values are considered to be in multiple disjoint domains, and the overall result is @racket[(nothing)]. Otherwise, the computation proceeds:
    }
    @item{
      It invokes the method. If the result of that invocation is @racket[(nothing)], the overall result is @racket[(nothing)]. Otherwise, the result of the invocation is of the form @racket[(just _result)], and the computation proceeds:
    }
    @item{
      To ensure that the overall merge/fuse is associative, it invokes the method-getting @racket[getfx?] operation one more time on @var[result]. If it does not obtain a merge/fuse method that's @racket[ordering-eq] to the one originally obtained from the inputs, it raises an error. Otherwise, the computation proceeds:
    }
    @item{
      The overall result is @racket[(just _result)].
    }
  ]
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-get-method] and the calls to their resulting merges/fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], all @tt{merge-by-own-method}/@tt{fuse-by-own-method} values are @racket[ordering-eq] if their @racket[dexed-get-method] values are.
}

@deftogether[(
  @defproc[
    (merge-fix
      [dexed-getfx-unwrap
        (dexed-first-order/c (-> merge? (getfx/c merge?)))])
    merge?
  ]
  @defproc[
    (fuse-fix
      [dexed-getfx-unwrap
        (dexed-first-order/c (-> fuse? (getfx/c fuse?)))])
    fuse?
  ]
)]{
  Given a @tech[#:key "dexed value"]{dexed} @racket[getfx?] operation, returns a merge/fuse that works by passing itself to the operation and then tail-calling the resulting merge/fuse.
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-unwrap] and the calls to their resulting merges/fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], all @tt{merge-fix}/@tt{fuse-fix} values are @racket[ordering-eq] if their @racket[dexed-getfx-unwrap] values are.
}

@deftogether[(
  @defform[
    (merge-tuple-by-field-position tupler-expr
      [field-position-nat field-method-expr]
      ...)
    
    #:contracts
    (
      [tupler-expr (tupler/c (=/c (length '(field-method-expr ...))))]
      [field-method-expr merge?])
  ]
  @defform[
    (fuse-tuple-by-field-position tupler-expr
      [field-position-nat field-method-expr]
      ...)
    
    #:contracts
    (
      [tupler-expr (tupler/c (=/c (length '(field-method-expr ...))))]
      [field-method-expr fuse?])
  ]
)]{
  Returns a merge/fuse that combines instances of the given tupler if their field values can be combined by the merges/fuses produced by the @racket[field-method-expr] expressions.
  
  Each @racket[field-position-nat] must be a distinct number indicating which field should be checked by the associated merge/fuse, and there must be an entry for every field.
  
  If calls to the given merges/fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], all @tt{merge-tuple-by-field-position}/@tt{fuse-tuple-by-field-position} values are @racket[ordering-eq] if they're for the same tupler, if they have @racket[field-position-nat] values in the same sequence, and if their @racket[field-method-expr] values are @racket[ordering-eq].
}

@deftogether[(
  @defform[
    (merge-tuple tupler-expr field-method-expr ...)
    
    #:contracts
    (
      [tupler-expr (tupler/c (=/c (length '(field-method-expr ...))))]
      [field-method-expr merge?])
  ]
  @defform[
    (fuse-tuple tupler-expr field-method-expr ...)
    
    #:contracts
    (
      [tupler-expr (tupler/c (=/c (length '(field-method-expr ...))))]
      [field-method-expr fuse?])
  ]
)]{
  Returns a merge/fuse that combines instances of the given tupler if their field values can be combined by the merges/fuses produced by the @racket[field-method-expr] expressions.
  
  If calls to the given merges/fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to this merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], each @tt{merge-tuple}/@tt{fuse-tuple} value is @racket[ordering-eq] to the equivalent @racket[merge-tuple-by-field-position]/@racket[fuse-tuple-by-field-position] value.
}


@subsection[#:tag "tables"]{Tables}

Interconfection's @deftech{tables} are similar to Racket hash tables where all the keys are Interconfection @tech{dexed values}. However, tables are encapsulated in such a way that @tech[#:key "purely functional"]{pure} code will always process the table entries in an order-oblivious way. For instance, an Interconfection table cannot be converted to a list in general. This makes tables useful for representing orderless sets that cross API boundaries, where the API client should not be able to depend on accidental details of the set representation.


@defproc[(table? [x any/c]) boolean?]{
  Returns whether the given value is an Interconfection table.
}

@defproc[(table-empty? [x table?]) boolean?]{
  Returns whether the given table is empty.
}

@defproc[(table-get [key dexed?] [table table?]) maybe?]{
  Returns the value associated with the given key in the given table, if any.
}

@defproc[(table-empty) table?]{
  Returns an empty table.
}

@defproc[
  (table-shadow [key dexed?] [maybe-val maybe?] [table table?])
  table?
]{
  Returns another table that's just like the given one, except that the @racket[table-get] result for the given key is the given @racket[maybe?] value. That is, this overwrites or removes the value associated with the given key.
}

@defproc[
  (getfx-table-map-fuse
    [table table?]
    [fuse fuse?]
    [key-to-operand (-> dexed? getfx?)])
  (getfx/c maybe?)
]{
  Given a table, a fuse, and a @racket[getfx?] operation, returns a @racket[getfx?] computation that calls that operation with each key of the table and results in a @racket[just] containing the fused value of all the operation's results. If the table is empty or if any operation result is outside the fuse’s domain, this computation results in @racket[(nothing)] instead.
  
  If the @racket[getfx?] computations that result from @racket[key-to-operand] and calls to the given fuse can be run through @racket[pure-run-getfx] without problems, then so can the overall computation.
}

@defproc[
  (getfx-table-sort [cline cline?] [table table?])
  (getfx/c (maybe/c (listof table?)))
]{
  Given a cline and a table, returns a @racket[getfx?] computation that sorts the values of the table by the cline, without determining an order on values that the cline doesn't determine an order on. This computation results in @racket[(nothing)] if any of the values are outside the cline's domain. Otherwise, it results in a @racket[just] containing a list of nonempty tables, partitioning the original table's values in ascending order.
  
  What we mean by partitioning is this: Each entry of the original table appears in one and only one table in the list, and the tables have no other entries.
  
  What we mean by ascending order is this: If the given cline computes that one value of the original table is @racket[(ordering-lt)] to a second value, then the two values are stored in two different tables, and the first value's table precedes the second value's table in the list. Likewise (and equivalently), if a value is @racket[(ordering-gt)] to a second value, the first occurs after the second in the list of tables.
}

@defproc[(dex-table [dex-val dex?]) dex?]{
  Returns a dex that compares tables, using the given dex to compare each value.
  
  If calls to the given dex can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-table} values are @racket[ordering-eq] if their @racket[dex-val] values are.
}

@; TODO: Add this to Cene for Racket.
@defproc[(dex-table-ordered [assoc (listof (list/c dexed? dex?))]) dex?]{
  Returns a dex that compares tables that have precisely the given set of @tech{dexed values} as keys and whose values can be compared by the corresponding dexes.
  
  The given keys must be mutually unique.
  
  For the sake of nontermination, error, and performance concerns, this dex computes by attempting the given dexes in the order they appear in the @racket[assoc] association list. If a dex before the last one determines a non-@racket[ordering-eq] result, the following dexes are only checked to be sure their domains contain the respective field values. Otherwise, the last dex, if any, is attempted as a tail call.
  
  If calls to the given dexes can be run through @racket[pure-run-getfx] without problems, then so can a call to this dex.
  
  When compared by @racket[(dex-dex)], all @tt{dex-table-ordered} values are @racket[ordering-eq] if they have the same keys in the same sequence and if the associated dexes are @racket[ordering-eq].
}

@; TODO: Add this to Cene for Racket.
@defproc[(cline-table-ordered [assoc (listof (list/c dexed? cline?))]) cline?]{
  Returns a cline that compares tables that have precisely the given set of @tech{dexed values} as keys and whose values can be compared by the corresponding clines. The comparison is lexicographic, with the most significant comparisons being the clines that appear earliest in the @racket[assoc] association list.
  
  The given keys must be mutually unique.
  
  For the sake of nontermination, error, and performance concerns, this cline computes by attempting the given clines in the order they appear in the @racket[assoc] association list. If a cline before the last one determines a non-@racket[ordering-eq] result, the following clines are only checked to be sure their domains contain the respective field values. Otherwise, the last cline, if any, is attempted as a tail call.
  
  If calls to the given clines can be run through @racket[pure-run-getfx] without problems, then so can a call to this cline.
  
  When compared by @racket[(dex-cline)], all @tt{cline-table-ordered} values are @racket[ordering-eq] if they have the same keys in the same sequence and if the associated clines are @racket[ordering-eq].
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to the similarly constructed @racket[dex-table-ordered].
}

@deftogether[(
  @defproc[(merge-table [merge-val merge?]) merge?]
  @defproc[(fuse-table [fuse-val fuse?]) fuse?]
)]{
  Returns a merge/fuse that combines tables by collecting all the nonoverlapping entries and combining the overlapping entries using the given @racket[merge-val]/@racket[fuse-val].
  
  If calls to the given merge/fuse can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting merge/fuse.
  
  When compared by @racket[(dex-merge)]/@racket[(dex-fuse)], all @tt{merge-table}/@tt{fuse-table} values are @racket[ordering-eq] if their @racket[merge-val]/@racket[fuse-val] values are.
}


@subsection[#:tag "fusable-functions"]{Fusable Functions}

The dex and cline utilities are good for early detection of equality on inductive information, information that we have access to all at once. For coinductive information -- that which we may never see the end of -- we cannot detect equality early. However, we may still do things based on an assumption of equality and then @emph{enforce} this assumption as new information comes to light.

Interconfection uses a dedicated kind of encapsulated data, @deftech{fusable functions}, for this purpose. As the name implies, fusable functions support a fuse operation. This operation returns a new fusable function right away. Subsequent calls to that function work by calling each of the original functions and fusing their results -- a computation which can cause errors if the return values turn out not to be as fusable as expected. We can use those errors to enforce our equality assumptions on the fly.

Interconfections's dexes and clines can't do this kind of delayed enforcement because they only compute simple values like @racket[(ordering-lt)].

It's arguable whether Interconfection's merges could do this. The property that sets apart a merge from a fuse is that a merge must be idempotent; the result of merging a value with itself must be indistinguishable from the original value. When we fuse a fusable function with itself, we end up with a function that does at least double the amount of computation, so in practice, the original and the fusion will not be indistinguishable. Because of this, Interconfection's fusable functions only come with a fuse operation, not a merge operation.

An Interconfection @racket[fusable-function?] is also a @racket[procedure?] value. It can be invoked just like any other Racket procedure.

There is currently no way to make a fusable function that performs a tail call. This property wouldn't be preserved by @racket[fuse-fusable-function] anyway.


@defproc[(fusable-function? [x any/c]) boolean?]{
  Returns whether the given value is an Interconfection fusable function value.
}

@defproc[
  (make-fusable-function [proc (-> any/c getfx?)])
  fusable-function?
]{
  Returns a fusable function that behaves like the given single-input, single-output @racket[getfx?] operation.
  
  If the @racket[getfx?] computations that result from @racket[proc] can be run through @racket[pure-run-getfx] without problems, then so can a call to the resulting fusable function.
}

@defproc[
  (fuse-fusable-function
    [dexed-getfx-arg-to-method
      (dexed-first-order/c (-> any/c (getfx/c fuse?)))])
  fuse?
]{
  Given @racket[dexed-getfx-arg-to-method] as a @tech[#:key "dexed value"]{dexed} function, returns a fuse that combines fusable functions. The combined fusable function works by calling the @racket[dexed-getfx-arg-to-method] function and running its @racket[getfx?] result to get a fuse; doing the same with both of the original fusable functions to get each of their results; and fusing the results by that fuse. If the results turn out not to be in the fuse's domain, this causes an error.
  
  If the @racket[getfx?] computations that result from @racket[dexed-getfx-arg-to-method] and the calls to their resulting fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to the fused fusable function.
  
  A call to this fuse can be run through @racket[pure-run-getfx] without problems.
  
  When compared by @racket[(dex-dex)], all @tt{fuse-fusable-function} values are @racket[ordering-eq] if their @racket[dexed-getfx-arg-to-method] values are.
}


@subsection[#:tag "order-contracts"]{Contracts for tables}

@defproc[(table-kv-of [unwrapped-k/c contract?] [v/c contract?]) contract?]{
  Returns a contract that recognizes a @racket[table?] where the keys are constrained in a certain way by the contract @racket[unwrapped-k/c] and the mapped values obey the contract @racket[v/c].
  
  Specifically, since the keys of a table are always @tech{dexed values}, the contract @racket[unwrapped-k/c] on the keys applies to the unwrapped values of the keys, rather than the keys themselves.
  
  The @racket[unwrapped-k/c] contract's projection on each unwrapped key must be @racket[ordering-eq] to the original unwrapped key. This essentially means the contract must be first-order.
}

@defproc[(table-v-of [c contract?]) contract?]{
  Returns a contract that recognizes a @racket[table?] where the mapped values obey the given contract.
}



@subsection[#:tag "other-data"]{Operations for Other Data Types and Derived Operations}

@defmodule[interconfection/order]

The @tt{interconfection/order} module exports all the definitions of @racketmodname[interconfection/order/base] plus the definitions below.

@defproc[(dex-trivial) dex?]{
  Returns a dex that compares @racket[trivial?] values from Lathe Comforts. Every two @racket[trivial?] values are @racket[ordering-eq].
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@; TODO: Add this to Cene for Racket.
@defproc[(dex-boolean) dex?]{
  Returns a dex that compares @racket[boolean?] values.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@; TODO: Add this to Cene for Racket.
@defproc[(cline-boolean-by-truer) cline?]{
  Returns a cline that compares booleans by an ordering where @racket[#f] is @racket[ordering-lt] to @racket[#t].
  
  A call to this cline can be run through @racket[pure-run-getfx] without problems.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to @racket[(dex-boolean)].
}

@; TODO: Add this to Cene for Racket.
@defproc[(cline-boolean-by-falser) cline?]{
  Returns a cline that compares booleans by an ordering where @racket[#t] is @racket[ordering-lt] to @racket[#f].
  
  A call to this cline can be run through @racket[pure-run-getfx] without problems.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to @racket[(dex-boolean)].
}

@; TODO: Add this to Cene for Racket.
@defproc[(merge-boolean-by-and) merge?]{
  Returns a merge that merges booleans using @racket[and].
  
  A call to this merge can be run through @racket[pure-run-getfx] without problems.
}

@; TODO: Add this to Cene for Racket.
@defproc[(merge-boolean-by-or) merge?]{
  Returns a merge that merges booleans using @racket[or].
  
  A call to this merge can be run through @racket[pure-run-getfx] without problems.
}

@defproc[(dex-immutable-string) dex?]{
  Returns a dex that compares immutable strings.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@defproc[(cline-immutable-string) cline?]{
  Returns a cline that compares immutable strings by their
  @racket[string<?] ordering.
  
  A call to this cline can be run through @racket[pure-run-getfx] without problems.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to @racket[(dex-immutable-string)].
}

@defproc[(dex-exact-rational) dex?]{
  Returns a dex that compares exact rational numbers.
  
  A call to this dex can be run through @racket[pure-run-getfx] without problems.
}

@defproc[(cline-exact-rational) cline?]{
  Returns a cline that compares exact rational numbers by their
  @racket[<] ordering.
  
  A call to this cline can be run through @racket[pure-run-getfx] without problems.
  
  When the dex obtained from this cline using @racket[get-dex-from-cline] is compared by @racket[(dex-dex)], it is @racket[ordering-eq] to @racket[(dex-exact-rational)].
}

@defproc[(fuse-exact-rational-by-plus) fuse?]{
  Returns a fuse that fuses exact rational numbers using @racket[+].
  
  A call to this fuse can be run through @racket[pure-run-getfx] without problems.
}

@defproc[(fuse-exact-rational-by-times) fuse?]{
  Returns a fuse that fuses exact rational numbers using @racket[*].
  
  A call to this fuse can be run through @racket[pure-run-getfx] without problems.
}

@defproc[
  (assocs->table-if-mutually-unique
    [assocs (listof (cons/c dexed? any/c))])
  (maybe/c table?)
]{
  Given an association list, returns a @racket[just] of a table with the same entries if the keys are mutually unique; otherwise returns @racket[(nothing)].
  
  This is a procedure that is convenient for two purposes: It's useful for detecting duplicates in a list of @tech{dexed values}, and it's useful for constructing tables. These purposes often coincide, since data structures which contain mutually unique values are often good candidates for converting to tables.
}

@defproc[
  (getfx-is-eq-by-dex [dex dex?] [a any/c] [b any/c])
  (getfx/c boolean?)
]{
  Given a dex and two values, returns a @racket[getfx?] computation that computes whether those values are @racket[ordering-eq] according to the dex. The two values must be in the dex's domain; otherwise, the computation raises an @racket[exn:fail:contract?] exception.
}

@defproc[
  (table-kv-map [table table?] [kv-to-v (-> dexed? any/c any/c)])
  maybe?
]{
  Returns a table with the same keys as the given one. The result is constructed by iterating over the given hash table's entries in an unspecified order and calling the given function with each entry's key and value to determine the corresponding result entry's mapped value.
}

@defproc[
  (table-kv-all?
    [table table?]
    [kv-accepted? (-> dexed? any/c boolean?)])
  boolean?
]{
  Iterates over the given hash table's entries in an unspecified order and calls the given function on each entry's key and value. If the function ever returns @racket[#f], then the overall result is @racket[#f]; otherwise, it's @racket[#t].
  
  There is no short-circuiting. Every entry is always visited, a policy which ensures that @tech[#:key "purely functional"]{pure} code can't use nontermination or run time errors to make assertions about the iteration order of the table. (Nevertheless, impure code can use Racket side effects to observe the iteration order.)
}

@defproc[
  (table-kv-any?
    [table table?]
    [kv-accepted? (-> dexed? any/c boolean?)])
  boolean?
]{
  Iterates over the given hash table's entries in an unspecified order and calls the given function on each entry's key and value. If the function ever returns @racket[#t], then the overall result is @racket[#t]; otherwise, it's @racket[#f].
  
  There is no short-circuiting. Every entry is always visited, a policy which ensures that @tech[#:key "purely functional"]{pure} code can't use nontermination or run time errors to make assertions about the iteration order of the table. (Nevertheless, impure code can use Racket side effects to observe the iteration order.)
}

@defproc[
  (table-v-map [table table?] [v-to-v (-> any/c any/c)])
  maybe?
]{
  Returns a table with the same keys as the given one. The result is constructed by iterating over the given hash table's entries in an unspecified order and calling the given function with each entry's mapped value to determine the corresponding result entry's mapped value.
}

@defproc[
  (table-v-all? [table table?] [v-accepted? (-> any/c boolean?)])
  boolean?
]{
  Iterates over the given hash table's entries in an unspecified order and calls the given function on each entry's mapped value. If the function ever returns @racket[#f], then the overall result is @racket[#f]; otherwise, it's @racket[#t].
  
  There is no short-circuiting. Every entry is always visited, a policy which ensures that @tech[#:key "purely functional"]{pure} code can't use nontermination or run time errors to make assertions about the iteration order of the table. (Nevertheless, impure code can use Racket side effects to observe the iteration order.)
}

@defproc[
  (table-v-any? [table table?] [v-accepted? (-> any/c boolean?)])
  boolean?
]{
  Iterates over the given hash table's entries in an unspecified order and calls the given function on each entry's mapped value. If the function ever returns @racket[#t], then the overall result is @racket[#t]; otherwise, it's @racket[#f].
  
  There is no short-circuiting. Every entry is always visited, a policy which ensures that @tech[#:key "purely functional"]{pure} code can't use nontermination or run time errors to make assertions about the iteration order of the table. (Nevertheless, impure code can use Racket side effects to observe the iteration order.)
}



@section[#:tag "extensibility"]{Extensibility}

@defmodule[interconfection/extensibility/base]

This module supplies an effect system designed for deterministic concurrency for the sake of implementing module systems. So that modules don't have to be able to observe the relative order they're processed in, this makes use of the orderless @racket[table?] collections from @racketmodname[interconfection/order/base]. In turn, some parts of @racketmodname[interconfection/order/base] are designed to be able to read modular extensions of the currently running program using @racket[getfx?] effects.

For now, nothing but some trivial @racket[getfx?] effects are documented. The full system also has "extfx" effects which can read and write to definition spaces.

@; TODO: Document some more of this module.

@; TODO: Add the text "All the exports of @tt{interconfection/extensibility/base} are also exported by @racketmodname[interconfection/extensibility]." once we actually have an `interconfection/extensibility` module.


@subsection[#:tag "getfx"]{Read-only extensibility effects ("getfx")}

@defproc[(getfx? [v any/c]) boolean?]{
  Returns whether the given value is a representation of an effectful computation that performs read-only extensibility side effects as it computes a result.
}

@defproc[(getfx/c [result/c contract?]) contract?]{
  Returns a contract that recognizes a representation of an effectful computation that performs read-only extensibility side effects and returns a value that abides by the given contract.
}

@defproc[(pure-run-getfx [effects getfx?]) any/c]{
  Attempts to run the given @racket[getfx?] computation, raising an error if it attempts to read just about anything.
}

@defproc[(getfx-done [result any/c]) getfx?]{
  Returns a @racket[getfx?] computation that performs no side effects and has the given result.
}

@defproc[
  (getfx-bind [effects getfx?] [then (-> any/c getfx?)])
  getfx?
]{
  Returns a @racket[getfx?] computation that proceeds by running the given @racket[effects] @racket[getfx?] computation, passing its result to @racket[then], and finally running the @racket[getfx?] computation that results from that.
  
  If both the subcomputations performed this way can be run through @racket[pure-run-getfx] without problems, then so can the overall computation.
}

@defproc[
  (fuse-getfx
    [dexed-getfx-method (dexed-first-order/c (-> (getfx/c fuse?)))])
  fuse?
]{
  Given @racket[dexed-getfx-method] as a @tech[#:key "dexed value"]{dexed} function, returns a fuse that combines @racket[getfx?] computations. The combined @racket[getfx?] computation works by calling the @racket[dexed-getfx-method] function and running its @racket[getfx?] result to get a fuse; doing the same with both of the original @racket[getfx?] computations to get each of their results; and fusing the results by that fuse. If the results turn out not to be in the fuse's domain, this causes an error.
  
  If the @racket[getfx?] computation that results from @racket[dexed-getfx-method] and the calls to its resulting fuses can be run through @racket[pure-run-getfx] without problems, then so can a call to the fused @racket[getfx?] computation.
  
  A call to this fuse can be run through @racket[pure-run-getfx] without problems.
  
  When compared by @racket[(dex-dex)], all @tt{fuse-getfx} values are @racket[ordering-eq] if their @racket[dexed-getfx-method] values are.
}
