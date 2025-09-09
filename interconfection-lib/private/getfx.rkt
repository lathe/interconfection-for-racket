#lang parendown racket/base

; interconfection/private/getfx
;
; Private operations for read-only extensibility side effects.

;   Copyright 2019-2022, 2025 The Lathe Authors
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing,
;   software distributed under the License is distributed on an
;   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
;   either express or implied. See the License for the specific
;   language governing permissions and limitations under the License.


(require interconfection/private/shim)
(init-shim)


(provide
  internal:getfx-done
  internal:getfx-bind
  internal:getfx-err
  internal:getfx-get
  internal:getfx-private-get)
(provide #/own-contract-out
  error-definer?
  error-definer-uninformative
  error-definer-from-message
  error-definer-from-exn
  error-definer-or-message
  getfx?
  pure-run-getfx
  getfx/c
  getfx-done
  getfx-bind)
(provide
  ; TODO: Give this one a contract like the others.
  getfx-map)
(provide #/own-contract-out
  getfx-err)
(provide
  getfx-err-unraise)
(provide #/own-contract-out
  getmaybefx-bind
  getmaybefx-map
  monad-list-map
  getfx-list-map
  getmaybefx-list-map)


(module private racket/base
  
  (require interconfection/private/shim)
  (init-shim)
  
  
  (define-syntax-parse-rule/autoptic
    (provide-struct {~autoptic-list (name:id field:id ...)})
    (begin
      (struct-easy (name field ...))
      (provide #/struct-out name)))
  
  
  (provide-struct (error-definer-uninformative))
  (provide-struct (error-definer-from-message message))
  (provide-struct (error-definer-from-exn exn))
  
  
  (provide-struct (getfx-done result))
  (provide-struct (getfx-bind effects then))
  (provide-struct (getfx-err on-execute))
  
  ; NOTE: We define this here so we can define `getfx?`, but we really
  ; only finish defining it in `interconfection/extensibility/base`.
  (provide-struct (getfx-get ds n on-stall))
  
  ; NOTE: We define this here so we can define `getfx?`, but we really
  ; only finish defining it in `interconfection/extensibility/base`.
  (provide-struct
    (getfx-private-get ds putter-name getter-name on-stall))
  
  )

(require #/prefix-in internal: 'private)


; An `error-definer?` is a way of specifying a custom error message.
; Although all the ways of constructing `error-definer?` values are
; currently very simple, they may someday (TODO) perform more
; sophisticated computations to produce holistic error reports.
;
; NOTE:
;
; Once they do this, it may be tempting to call them "error handlers".
; However, they cannot be used to recover from an error. They can only
; produce an error report.
;
; The Interconfection extensibility process calculus depends on
; monotonicity of all state resources to ensure the backwards
; compatibility of each extension. If Interconfection's notion of a
; pure computation had a way to recover from all errors, then a
; computation could positively depend on the *presence* of an error,
; even an error that results from the *lack* of some definition or an
; *incomplete* implementation, meaning that the very act of
; implementing an unimplemented thing could break backwards
; compatibility. We can't very well disallow implementing things, so
; we disallow recovering from errors instead.

; TODO:
;
; Add more expressive ways to create `error-definer?` values. It seems
; like in general, they should be similar to top-level Cene
; definitions (i.e. `extfx?`-returning functions which take a unique
; `authorized-name?` and a `(-> name? authorized-name?)` name
; qualification function), but with the distinction that the
; information they define is only used to construct a detailed and
; focused error report.
;
; Treating them as *services* (i.e. top-level definitions which have
; familiarity tickets for each other) this way would make it possible
; for them to coordinate to produce *simpler* error reports than they
; could produce independently. However, for them to obtain familiarity
; tickets for each other, we'll need to create variations of
; `extfx-split-list`, `extfx-split-table`, and `extfx-disburse` which
; take their own top-level definitions that act like phone operator
; switchboards to allow cousin unspent ticket errors to connect with
; each other. We may also need variations of `fuse-extfx` and
; `extfx-table-each` which do the same kind of thing to allow
; concurrent processes' error definers to coordinate with each other,
; as well as possibly some more effects (unlike any we currently have)
; which allow concurrent errors and unspent ticket errors to interact
; with each other.
;
; It's possible we may also want a way to twist-tie (so to speak) some
; ticket values so that their unspent ticket errors are managed
; together. Perhaps in order to do this, we could hide them all inside
; a single ticket value until it's unwrapped again, but it seems like
; we might just be able to install this kind of connection using a
; side effect without changing the way we pass the tickets around.

(define/own-contract (error-definer? v)
  (-> any/c boolean?)
  (mat v (internal:error-definer-uninformative) #t
  #/mat v (internal:error-definer-from-message message) #t
  #/mat v (internal:error-definer-from-exn exn) #t
    #f))

(define/own-contract (error-definer-uninformative)
  (-> error-definer?)
  (internal:error-definer-uninformative))

(define/own-contract (error-definer-from-message message)
  (-> immutable-string? error-definer?)
  (internal:error-definer-from-message message))

(define/own-contract (error-definer-from-exn exn)
  (-> exn:fail? error-definer?)
  (internal:error-definer-from-exn exn))

; TODO: See if we should export this.
;
; TODO: Make a corresponding `error-definer-or-exn`. Consider
; migrating all uses of this one to that one.
;
(define/own-contract (error-definer-or-message ed message)
  (-> error-definer? immutable-string? error-definer?)
  (expect ed (internal:error-definer-uninformative) ed
  #/internal:error-definer-from-message message))

; TODO: See if we should export this.
(define/own-contract (raise-error-definer error-definer)
  (-> error-definer? none/c)
  (mat error-definer (internal:error-definer-uninformative)
    ; TODO: See if we should make this more informative.
    (error "error")
  #/mat error-definer (internal:error-definer-from-message message)
    ; TODO: See if we should make this more informative, like being a
    ; specific kind of exception.
    (error message)
  #/dissect error-definer (internal:error-definer-from-exn exn)
    (raise exn)))


(define/own-contract (getfx? v)
  (-> any/c boolean?)
  (mat v (internal:getfx-done result) #t
  #/mat v (internal:getfx-bind effects then) #t
  #/mat v (internal:getfx-err on-execute) #t
  
  #/mat v (internal:getfx-get ds n on-stall) #t
  
  #/mat v
    (internal:getfx-private-get ds putter-name getter-name on-stall)
    #t
  
    #f))

(define/own-contract (pure-run-getfx effects)
  (-> getfx? any/c)
  (mat effects (internal:getfx-done result) result
  #/mat effects (internal:getfx-bind effects then)
    (pure-run-getfx #/then #/pure-run-getfx effects)
  #/mat effects (internal:getfx-err on-execute)
    (raise-error-definer on-execute)
  
  #/mat effects (internal:getfx-get ds n on-stall)
    ; TODO: See if we should use `on-stall` here.
    (raise-arguments-error 'pure-run-getfx
      "expected a getfx computation that did not perform a getfx-get"
      "ds" ds
      "n" n
      "on-stall" on-stall)
  
  #/dissect effects
    (internal:getfx-private-get ds putter-name getter-name on-stall)
    ; TODO: See if we should use `on-stall` here.
    (raise-arguments-error 'pure-run-getfx
      "expected a getfx computation that did not perform a getfx-private-get"
      "ds" ds
      "putter-name" putter-name
      "getter-name" getter-name
      "on-stall" on-stall)))

(define/own-contract (getfx/c result/c)
  (-> contract? contract?)
  (define result/c-coerced (coerce-contract 'getfx/c result/c))
  (define c
    (make-contract
      
      #:name `(getfx/c ,(contract-name result/c-coerced))
      
      #:first-order (fn v #/getfx? v)
      
      #:late-neg-projection
      (fn blame
        (w- result/c-late-neg-projection
          ( (get/build-late-neg-projection result/c-coerced)
            (blame-add-context blame "the anticipated value of"))
        #/w- then/c-blame
          (blame-add-context blame "a function returning the anticipated value of")
        #/fn v missing-party
          (expect (getfx? v) #t
            (raise-blame-error blame #:missing-party missing-party v
              '(expected: "a getfx effectful computation" given: "~e")
              v)
          
          ; NOTE OPTIMIZATION: We could use `getfx-map` for all `v`,
          ; but that would give us the kind of problem Racket's
          ; collapsible contracts are meant to fix. Contract
          ; projection applications would pile up on the forthcoming
          ; getfx result, even if some of them are equivalent
          ; contracts. Here, we apply the contract projection to the
          ; component values of come `getfx?` values. In the case of
          ; `getfx-bind` in particular, we apply the projection of a
          ; `->` contract, and in so doing, we automatically benefit
          ; from the collapsible contract support `->` has built in.
          ;
          #/mat v (internal:getfx-done result)
            (internal:getfx-done
              (result/c-late-neg-projection result missing-party))
          #/mat v (internal:getfx-err on-execute) v
          #/mat v (internal:getfx-bind effects then)
            (w- then/c-late-neg-projection
              ((get/build-late-neg-projection any->c) then/c-blame)
            #/internal:getfx-bind effects
              (then/c-late-neg-projection then missing-party))
          
          #/getfx-map v #/fn result
            (result/c-late-neg-projection result missing-party))))))
  (define any->c (-> any/c c))
  c)

(define/own-contract (getfx-done result)
  (-> any/c getfx?)
  (internal:getfx-done result))

(define/own-contract (getfx-bind effects then)
  (-> getfx? (-> any/c getfx?) getfx?)
  (internal:getfx-bind effects then))

; TODO: See if we should export this from
; `interconfection/extensibility`.
(define (getfx-map effects func)
  (getfx-bind effects #/fn result
  #/getfx-done #/func result))

(define/own-contract (getfx-err on-execute)
  (-> error-definer? (getfx/c none/c))
  (internal:getfx-err on-execute))

(define/own-contract (getfx-err-unraise-fn body)
  (-> (-> any) getfx?)
  (dissect
    (with-handlers ([exn:fail? (fn e #/list #t e)])
      (list #f #/call-with-values body #/fn results results))
    (list okay result)
  #/expect okay #t
    (raise-arguments-error 'getfx-err-unraise
      "expected the body to raise an exception rather than return values"
      "return-values" result)
  #/getfx-err #/error-definer-from-exn result))

; TODO: See if we should export this.
(define-syntax-parse-rule/autoptic (getfx-err-unraise body:expr)
  (getfx-err-unraise-fn #/fn body))

; TODO: See if we should export this.
(define/own-contract (getmaybefx-bind effects then)
  (-> (getfx/c maybe?) (-> any/c #/getfx/c maybe?) #/getfx/c maybe?)
  (getfx-bind effects #/fn maybe-intermediate
  #/expect maybe-intermediate (just intermediate)
    (getfx-done #/nothing)
  #/then intermediate))

; TODO: See if we should export this.
(define/own-contract (getmaybefx-map effects func)
  (-> (getfx/c maybe?) (-> any/c any/c) #/getfx/c maybe?)
  (getmaybefx-bind effects #/fn intermediate
  #/getfx-done #/just #/func intermediate))

; TODO: See if we should export this from somewhere.
(define/own-contract (monad-list-map fx-done fx-bind list-of-fx)
  (-> (-> any/c any/c) (-> any/c (-> any/c any/c) any/c) list? any/c)
  (w-loop next rest list-of-fx rev-result (list)
    (expect rest (cons fx-first rest)
      (fx-done #/reverse rev-result)
    #/fx-bind fx-first #/fn first
    #/next rest (cons first rev-result))))

; TODO: See if we should export this.
(define/own-contract (getfx-list-map list-of-getfx)
  (-> (listof getfx?) #/getfx/c list?)
  (monad-list-map
    (fn result #/getfx-done result)
    (fn effects then #/getfx-bind effects then)
    list-of-getfx))

; TODO: See if we should export this.
(define/own-contract (getmaybefx-list-map list-of-getmaybefx)
  (-> (listof #/getfx/c maybe?) #/getfx/c #/maybe/c list?)
  (monad-list-map
    (fn result #/getfx-done #/just result)
    (fn effects then #/getmaybefx-bind effects then)
    list-of-getmaybefx))
