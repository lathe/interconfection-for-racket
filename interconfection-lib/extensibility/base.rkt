#lang parendown racket/base

; interconfection/extensibility/base
;
; Fundamental operations for extensibility side effects.

;   Copyright 2018-2020 The Lathe Authors
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


; NOTE: The Racket documentation says `get/build-late-neg-projection`
; is in `racket/contract/combinator`, but it isn't. It's in
; `racket/contract/base`. Since it's also in `racket/contract` and the
; documentation correctly says it is, we require it from there.
(require #/only-in racket/contract get/build-late-neg-projection)
(require #/only-in racket/contract/base
  -> ->i any any/c contract? contract-name contract-out list/c listof
  none/c or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract make-flat-contract raise-blame-error)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/hash hash-union)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect expectfn fn mat w- w-loop)
(require #/only-in lathe-comforts/hash
  hash-ref-maybe hash-v-all hash-v-any hash-v-map)
(require #/only-in lathe-comforts/list
  list-any list-bind list-foldl list-map list-zip-map nat->maybe)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe-bind nothing)
(require #/only-in lathe-comforts/string immutable-string?)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-struct istruct/c
  struct-easy)
(require #/only-in lathe-comforts/trivial trivial trivial?)

(require #/only-in interconfection/order
  getfx-is-eq-by-dex table-v-of)
(require #/only-in interconfection/order/base
  dex? dexed? dexed/c dexed-first-order/c dexed-get-name
  dexed-get-value dex-name fuse? getfx-compare-by-dex name?
  ordering-eq table? table-empty? table-empty table-get table-shadow)
(require #/only-in (submod interconfection/order/base private)
  getfx-dex-internals-simple-dexed-of getmaybefx-ordering-or)
(require interconfection/private/getfx)
(require #/only-in interconfection/private/order
  object-identities-autodex)

(require #/prefix-in unsafe: #/only-in interconfection/order/unsafe
  dex fuse gen:dex-internals gen:furge-internals name table)


; TODO: Finish implementing each of these exports, and document them.
(provide #/contract-out
  
  [getfx? (-> any/c boolean?)]
  [getfx/c (-> contract? contract?)]
  [extfx? (-> any/c boolean?)]
  [dspace? (-> any/c boolean?)]
  [dspace-shadower (-> name? dspace? dspace?)]
  [dex-dspace (-> dex?)]
  [dspace-eq? (-> dspace? dspace? boolean?)]
  [dspace-descends? (-> dspace? dspace? boolean?)]
  
  [error-definer? (-> any/c boolean?)]
  [error-definer-uninformative (-> error-definer?)]
  [error-definer-from-message (-> immutable-string? error-definer?)]
  [error-definer-from-exn (-> exn:fail? error-definer?)]
  [success-or-error-definer? (-> any/c boolean?)]
  [success-or-error-definer
    (-> error-definer? extfx? success-or-error-definer?)]
  
  [ticket? (-> any/c boolean?)]
  [intuitionistic-ticket? (-> any/c boolean?)]
  [intuitionistic-ticket-dspace-descends?
    (-> intuitionistic-ticket? dspace? boolean?)]
  [intuitionistic-ticket-ancestor/c (-> dspace? contract?)]
  [continuation-ticket? (-> any/c boolean?)]
  [continuation-ticket-of (-> contract? contract?)]
  [familiarity-ticket? (-> any/c boolean?)]
  [familiarity-ticket-dspace-ancestor/c (-> dspace? contract?)]
  
  [pure-run-getfx (-> getfx? any/c)]
  [getfx-done (-> any/c getfx?)]
  [getfx-bind (-> getfx? (-> any/c getfx?) getfx?)]
  [extfx-noop (-> extfx?)]
  [fuse-extfx (-> fuse?)]
  [extfx-run-getfx (-> getfx? (-> any/c extfx?) extfx?)]
  [getfx-err (-> error-definer? (getfx/c none/c))]
  [extfx-spawn-dexed (-> (dexed-first-order/c #/-> extfx?) extfx?)]
  [extfx-table-each
    (-> table?
      (-> any/c
        (list/c error-definer? #/-> continuation-ticket? extfx?))
      (-> table? extfx?)
      extfx?)]
  
  [authorized-name? (-> any/c boolean?)]
  [authorized-name-dspace-descends?
    (-> authorized-name? dspace? boolean?)]
  [authorized-name-dspace-ancestor/c (-> dspace? contract?)]
  [authorized-name-get-name (-> authorized-name? name?)]
  [dex-authorized-name (-> dex?)]
  [name-subname (-> name? name? name?)]
  [authorized-name-subname
    (-> name? authorized-name? authorized-name?)]
  [extfx-claim-unique
    (-> authorized-name? error-definer? error-definer?
      (-> authorized-name? familiarity-ticket? extfx?)
      extfx?)]
  
  [optionally-dexed? (-> any/c boolean?)]
  ; TODO: See if we'll use `optionally-dexed/c`. We were once using it
  ; in the signature of `extfx-sub-write`, but its `unique-name`
  ; parameter now makes that unnecessary.
;  [optionally-dexed/c (-> contract? contract?)]
  [optionally-dexed-once (-> any/c optionally-dexed?)]
  [optionally-dexed-dexed (-> dexed? optionally-dexed?)]
  
  [extfx-put
    (->i
      (
        [ds dspace?]
        [n (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-cont-unspent error-definer?]
        [comp
          (->
            (continuation-ticket-of
              (list/c success-or-error-definer? optionally-dexed?))
            extfx?)])
      [_ extfx?])]
  [getfx-get (-> dspace? name? error-definer? getfx?)]
  
  [extfx-private-put
    (->i
      (
        [ds dspace?]
        [putter-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [getter-name name?]
        [on-cont-unspent error-definer?]
        [comp
          (->
            (continuation-ticket-of
              (list/c success-or-error-definer? optionally-dexed?))
            extfx?)])
      [_ extfx?])]
  [getfx-private-get
    (->i
      (
        [ds dspace?]
        [putter-name name?]
        [getter-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-stall error-definer?])
      [_ getfx?])]
  
  [pub? (-> any/c boolean?)]
  [sub? (-> any/c boolean?)]
  [pub-dspace-descends? (-> dspace? pub? boolean?)]
  [sub-dspace-descends? (-> dspace? sub? boolean?)]
  [pub-ancestor/c (-> dspace? contract?)]
  [sub-ancestor/c (-> dspace? contract?)]
  [make-pub
    (->i
      (
        [ds dspace?]
        [pubsub-name (ds) (authorized-name-dspace-ancestor/c ds)])
      [_ (ds) (pub-ancestor/c ds)])]
  [make-sub
    (->i
      (
        [ds dspace?]
        [pubsub-name (ds) (authorized-name-dspace-ancestor/c ds)])
      [_ (ds) (sub-ancestor/c ds)])]
  [pub-restrict
    (->i ([new-ds dspace?] [p (new-ds) (pub-ancestor/c new-ds)])
      [_ (new-ds) (pub-ancestor/c new-ds)])]
  [sub-restrict
    (->i ([new-ds dspace?] [s (new-ds) (sub-ancestor/c new-ds)])
      [_ (new-ds) (pub-ancestor/c new-ds)])]
  [extfx-pub-write
    (->i
      (
        [ds dspace?]
        [p (ds) (pub-ancestor/c ds)]
        [unique-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-conflict success-or-error-definer?]
        [arg any/c])
      [_ extfx?])]
  [extfx-sub-write
    (->i
      (
        [ds dspace?]
        [s (ds) (sub-ancestor/c ds)]
        [unique-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-conflict success-or-error-definer?]
        [func (-> any/c extfx?)])
      [_ extfx?])]
  
  [extfx-freshen
    (-> ticket? error-definer? (-> ticket? extfx?) extfx?)]
  [extfx-split-list
    (-> intuitionistic-ticket? natural? error-definer?
      (-> (listof intuitionistic-ticket?) extfx?)
      extfx?)]
  [extfx-split-table
    (-> intuitionistic-ticket? (table-v-of trivial?) error-definer?
      (-> (table-v-of intuitionistic-ticket?) extfx?)
      extfx?)]
  [extfx-disburse
    (->i
      (
        [ds dspace?]
        [hub-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-cont-unspent error-definer?]
        [comp-ticket (ds)
          (->
            (continuation-ticket-of #/list/c
              success-or-error-definer?
              (intuitionistic-ticket-ancestor/c ds))
            extfx?)])
      [_ extfx?])]
  [extfx-imburse
    (-> dspace? familiarity-ticket? error-definer?
      (-> intuitionistic-ticket? extfx?)
      extfx?)]
  [extfx-ct-continue
    (-> continuation-ticket? error-definer? any/c extfx?)]
  [extfx-ft-subname
    (-> familiarity-ticket? name? error-definer?
      (-> familiarity-ticket? extfx?)
      extfx?)]
  [extfx-ft-restrict
    (-> familiarity-ticket? dspace? error-definer? error-definer?
      (-> familiarity-ticket? extfx?)
      extfx?)]
  
  [extfx-contribute
    (->i
      (
        [ds dspace?]
        [collector-familiarity-ticket (ds)
          (familiarity-ticket-dspace-ancestor/c ds)]
        [contributor-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [on-familiarity-double-spend error-definer?]
        [on-cont-unspent error-definer?]
        [comp
          (->
            (continuation-ticket-of
              (list/c success-or-error-definer? optionally-dexed?))
            extfx?)])
      [_ extfx?])]
  [extfx-collect
    (->i
      (
        [ds dspace?]
        [collector-name (ds) (authorized-name-dspace-ancestor/c ds)]
        [then (-> table? extfx?)])
      [_ extfx?])]
  
  )

; TODO: Document these exports, which wind up exported from
; `interconfection/extensibility/unsafe`.
(module+ private/unsafe #/provide #/contract-out
  [run-extfx-result-success? (-> any/c boolean?)]
  [run-extfx-result-success-value
    (-> run-extfx-result-success? any/c)])
(module+ private/unsafe #/provide
  run-extfx-result-success)
(module+ private/unsafe #/provide #/contract-out
  [run-extfx-result-failure? (-> any/c boolean?)]
  [run-extfx-result-failure-errors
    (-> run-extfx-result-failure? any/c)])
(module+ private/unsafe #/provide
  run-extfx-result-failure)
(module+ private/unsafe #/provide #/contract-out
  [run-extfx!
    (-> error-definer?
      (->i
        (
          [ds dspace?]
          [unique-name (ds) (authorized-name-dspace-ancestor/c ds)]
          [then continuation-ticket?])
        [_ extfx?])
      (or/c
        (match/c run-extfx-result-failure run-extfx-errors?)
        (match/c run-extfx-result-success any/c)))])


; TODO: There are still some uses of `define/contract` in this module.
; We use `contract-out` instead wherever possible, and these should
; probably be converted in similar ways. Let's do that after we've put
; this module to the test somewhat.


(module private racket/base
  
  (require #/only-in lathe-comforts/struct struct-easy)
  
  
  (define-syntax-rule (provide-struct (name field ...) option ...)
    (begin
      (struct-easy (name field ...) option ...)
      (provide #/struct-out name)))
  
  
  (provide-struct (dspace runtime-symbol name parents-list))
  
  (provide-struct (success-or-error-definer on-error on-success))
  
  (provide-struct (authorized-name ds name parents))
  
  (provide-struct (optionally-dexed-once v))
  (provide-struct (optionally-dexed-dexed dexed))
  
  (provide-struct (pub ds pubsub-name))
  (provide-struct (sub ds pubsub-name))
  
  (provide-struct (continuation-ticket ticket-symbol ds then))
  (provide-struct (familiarity-ticket ticket-symbol ds))
  
  
  (provide-struct (extfx-noop))
  (provide-struct (extfx-fused a b))
  (provide-struct (extfx-run-getfx effects then))
  (provide-struct (extfx-spawn-dexed dexed-then))
  (provide-struct (extfx-table-each t on-element then))
  
  (provide-struct
    (extfx-claim-unique
      n on-conflict on-familiarity-ticket-unspent then))
  
  (provide-struct (extfx-put ds n on-cont-unspent comp))
  
  (provide-struct
    (extfx-private-put
      ds putter-name getter-name on-cont-unspent comp))
  
  (provide-struct (extfx-pub-write ds p unique-name on-conflict arg))
  (provide-struct (extfx-sub-write ds s unique-name on-conflict func))
  
  (provide-struct (extfx-freshen ticket on-conflict then))
  (provide-struct (extfx-split-list ticket times on-conflict then))
  (provide-struct
    (extfx-split-table ticket times on-conflict then))
  (provide-struct
    (extfx-disburse ds hub-name on-cont-unspent comp-ticket))
  (provide-struct
    (extfx-imburse ds hub-familiarity-ticket on-conflict then))
  (provide-struct (extfx-ct-continue ticket on-conflict value))
  (provide-struct (extfx-ft-subname ticket key on-conflict then))
  (provide-struct
    (extfx-ft-restrict
      ticket ds on-conflict on-restriction-error then))
  
  (provide-struct
    (extfx-contribute
      ds collector-familiarity-ticket contributor-name
      on-familiarity-double-spend on-cont-unspent comp))
  (provide-struct (extfx-collect ds collector-name then))
  
  
  (provide-struct (run-extfx-errors errors))
  
  
  )

(require #/prefix-in internal: 'private)



; TODO: Consider putting this into Lathe Comforts.
(define/contract (list-keep lst check)
  (-> list? (-> any/c boolean?) list?)
  (filter check lst))

; TODO: Consider putting this into `interconfection/order`.
(define/contract (table-update-default t k default-v func)
  (-> table? name? any/c (-> any/c any/c) table?)
  (table-shadow k
    (just #/func #/mat (table-get k t) (just v) v default-v)
    t))

; TODO: Consider putting this into `interconfection/order`.
(define/contract (table-union a b func)
  (-> table? table? (-> any/c any/c any/c) table?)
  (dissect a (unsafe:table a)
  #/dissect b (unsafe:table b)
  #/unsafe:table #/hash-union a b #:combine #/fn a b #/func a b))

(define/contract (trivial-union a b)
  (-> trivial? trivial? trivial?)
  (trivial))

; TODO: Consider putting this into `interconfection/order`.
;
; TODO: See if some of the other places we use `unsafe:table` can use
; this or `table-v-map-maybe` instead.
;
(define/contract (table-kv-map-maybe t func)
  (-> table? (-> name? any/c maybe?) table?)
  (dissect t (unsafe:table t)
  #/unsafe:table #/list-bind (hash->list t) #/dissectfn (cons k v)
    (expect (func (unsafe:name k) v) (just v)
      (list)
    #/list #/cons k v)))

; TODO: Consider putting this into `interconfection/order`.
(define/contract (table-v-map-maybe t func)
  (-> table? (-> any/c maybe?) table?)
  (table-kv-map-maybe t #/fn k v #/func v))

; TODO: Consider putting this into `interconfection/order/unsafe`.
(define/contract (unsafe-table-kv-any-short-circuiting t body)
  (-> table? (-> name? any/c boolean?) boolean?)
  (dissect t (unsafe:table t)
  #/list-any (hash->list t) #/dissectfn (cons k v)
    (body (unsafe:name k) v)))

; TODO: Consider putting this into `interconfection/order/unsafe`.
(define/contract (unsafe-table-v-any-short-circuiting t body)
  (-> table? (-> any/c boolean?) boolean?)
  (unsafe-table-kv-any-short-circuiting t #/fn k v #/body v))



(struct-easy
  (extfx-finish-table-each-element ds table-each-symbol k result))
(struct-easy (extfx-finish-table-each-then ds table-each-symbol then))
(struct-easy (extfx-finish-put ds n on-conflict value))
(struct-easy
  (extfx-finish-private-put
    ds putter-name getter-name on-conflict value))
(struct-easy (extfx-finish-disburse ds hub-name on-conflict ticket))
(struct-easy
  (extfx-finish-contribute
    ds collector-name contributor-name on-value-conflict value))

(struct-easy (extfx-finish-run ds value))

(define (extfx? v)
  (mat v (internal:extfx-noop) #t
  #/mat v (internal:extfx-fused a b) #t
  #/mat v (internal:extfx-run-getfx effects then) #t
  #/mat v (internal:extfx-spawn-dexed dexed-then) #t
  #/mat v (internal:extfx-table-each t on-element then) #t
  #/mat v
    (extfx-finish-table-each-element ds table-each-symbol k result)
    #t
  #/mat v (extfx-finish-table-each-then ds table-each-symbol then) #t
  
  #/mat v
    (internal:extfx-claim-unique
      n on-conflict on-familiarity-ticket-unspent then)
    #t
  
  #/mat v (internal:extfx-put ds n on-cont-unspent comp) #t
  #/mat v (extfx-finish-put ds n on-conflict value) #t
  
  #/mat v
    (internal:extfx-private-put
      ds putter-name getter-name on-cont-unspent comp)
    #t
  
  #/mat v (internal:extfx-pub-write ds p unique-name on-conflict arg)
    #t
  #/mat v (internal:extfx-sub-write ds s unique-name on-conflict func)
    #t
  
  #/mat v (internal:extfx-freshen ticket on-conflict then) #t
  #/mat v (internal:extfx-split-list ticket times on-conflict then) #t
  #/mat v (internal:extfx-split-table ticket times on-conflict then)
    #t
  #/mat v
    (internal:extfx-disburse ds hub-name on-cont-unspent comp-ticket)
    #t
  #/mat v
    (internal:extfx-imburse
      ds hub-familiarity-ticket on-conflict then)
    #t
  #/mat v (internal:extfx-ct-continue ticket on-conflict value) #t
  #/mat v (internal:extfx-ft-subname ticket key on-conflict then) #t
  #/mat v
    (internal:extfx-ft-restrict
      ticket ds on-conflict on-restriction-error then)
    #t
  
  #/mat v
    (internal:extfx-contribute
      ds collector-familiarity-ticket contributor-name
      on-familiarity-double-spend on-cont-unspent comp)
    #t
  #/mat v (extfx-finish-disburse ds hub-name on-conflict ticket) #t
  #/mat v
    (extfx-finish-contribute
      ds collector-name contributor-name on-value-conflict value)
    #t
  #/mat v (internal:extfx-collect ds collector-name then) #t
  
  #/mat v (extfx-finish-run ds value) #t
  
    #f))

(define (dspace? v)
  (internal:dspace? v))

(define (dspace-shadower key-name ds)
  (dissect ds (internal:dspace runtime-symbol name parents-list)
  #/internal:dspace
    runtime-symbol
    (name-subname key-name name)
    (cons name parents-list)))

(struct-easy (dex-internals-dspace)
  #:other
  
  #:methods unsafe:gen:dex-internals
  [
    
    (define (dex-internals-tag this)
      'tag:dex-dspace)
    
    (define (dex-internals-autoname this)
      'tag:dex-dspace)
    
    (define (dex-internals-autodex this other)
      (just #/ordering-eq))
    
    (define (getfx-dex-internals-is-in this x)
      (getfx-done #/dspace? x))
    
    (define (getfx-dex-internals-name-of this x)
      (getfx-done
        (expect x (internal:dspace runtime-symbol name parents-list)
          (nothing)
        #/dissect name (unsafe:name name)
        #/just #/unsafe:name #/list 'name:dspace name)))
    
    (define (getfx-dex-internals-dexed-of this x)
      (getfx-dex-internals-simple-dexed-of this x))
    
    (define (getfx-dex-internals-compare this a b)
      (expect a (internal:dspace a-runtime-symbol a-name _)
        (getfx-done #/nothing)
      #/expect b (internal:dspace b-runtime-symbol b-name _)
        (getfx-done #/nothing)
      #/getmaybefx-ordering-or
        (getfx-done #/just #/object-identities-autodex
          a-runtime-symbol
          b-runtime-symbol)
        (getfx-compare-by-dex (dex-name) a-name b-name)))
  ])

(define (dex-dspace)
  (unsafe:dex #/dex-internals-dspace))

(define (dspace-eq? a b)
  (pure-run-getfx #/getfx-is-eq-by-dex (dex-dspace) a b))

(define (dspace-descends? ancestor descendant)
  (dissect ancestor
    (internal:dspace
      ancestor-runtime-symbol ancestor-name ancestor-parents-list)
  #/dissect descendant
    (internal:dspace
      descendant-runtime-symbol
      descendant-name
      descendant-parents-list)
  #/and (eq? ancestor-runtime-symbol descendant-runtime-symbol)
  #/mat ancestor-parents-list (list) #t
  #/list-any (cons descendant-name descendant-parents-list) #/fn name
    (pure-run-getfx
      (getfx-is-eq-by-dex (dex-name) ancestor-name name))))

; NOTE: In our interfaces here, the point of
; `success-or-error-definer?` values is not only to let conflicts be
; reported, but to let certain `extfx?` computations run only after
; the avoidance of a conflict has been (at least provisionally)
; confirmed. Using these success handlers is about as easy as using
; `fuse-extfx` to run the other `extfx?` computations concurrently,
; but this way we save the program from the trouble of running those
; computations if we already know there's an error.

(define (success-or-error-definer? v)
  (internal:success-or-error-definer? v))

(define (success-or-error-definer on-error on-success)
  (internal:success-or-error-definer on-error on-success))


(define (ticket? v)
  (mat v (internal:continuation-ticket ticket-symbol ds then) #t
  #/mat v (internal:familiarity-ticket ticket-symbol ds) #t
    #f))

(define (intuitionistic-ticket? v)
  (mat v (internal:familiarity-ticket ticket-symbol ds) #t
    #f))

(define (intuitionistic-ticket-dspace-descends? ticket ds)
  (dissect ticket
    (internal:familiarity-ticket ticket-symbol ticket-ds)
  #/dspace-descends? ticket-ds ds))

(define (intuitionistic-ticket-ancestor/c ds)
  (make-flat-contract
    
    #:name `(intuitionistic-ticket-ancestor/c ,ds)
    
    #:first-order
    (fn v
      (and
        (intuitionistic-ticket? v)
        (intuitionistic-ticket-dspace-descends? v ds)))))

(define (continuation-ticket? v)
  (internal:continuation-ticket? v))

(define (continuation-ticket-of c)
  (w- c (coerce-contract 'continuation-ticket-of c)
  #/make-contract
    
    #:name `(continuation-ticket-of ,(contract-name c))
    
    #:first-order
    (fn v
      (contract-first-order-passes?
        (istruct/c internal:continuation-ticket any/c any/c
          (-> c any))
        v))
    
    #:late-neg-projection
    (fn blame
      (w- c-late-neg-projection
        ( (get/build-late-neg-projection c)
          (blame-add-context blame #:swap? #t
            "the anticipated value of"))
      #/fn v missing-party
        (expect v
          (internal:continuation-ticket ticket-symbol ds then)
          (raise-blame-error blame #:missing-party missing-party v
            '(expected: "a continuation ticket" given: "~e")
            v)
        #/internal:continuation-ticket ticket-symbol ds
          (fn result
            (then #/c-late-neg-projection result missing-party)))))))

(define (familiarity-ticket? v)
  (internal:familiarity-ticket? v))

(define (familiarity-ticket-dspace-ancestor/c ds)
  (make-flat-contract
    
    #:name `(familiarity-ticket-dspace-ancestor/c ,ds)
    
    #:first-order
    (fn v
      (and
        (familiarity-ticket? v)
        (intuitionistic-ticket-dspace-descends? v ds)))))


(define (extfx-noop)
  (internal:extfx-noop))

(struct-easy (fuse-internals-extfx)
  #:other
  
  #:methods unsafe:gen:furge-internals
  [
    
    (define (furge-internals-tag this)
      'tag:fuse-extfx)
    
    (define (furge-internals-autoname this)
      'tag:fuse-extfx)
    
    (define (furge-internals-autodex this other)
      (just #/ordering-eq))
    
    (define (getfx-furge-internals-call this a b)
      (getfx-done
        (expect (extfx? a) #t (nothing)
        #/expect (extfx? b) #t (nothing)
        #/just #/internal:extfx-fused a b)))
  ])

(define (fuse-extfx)
  (unsafe:fuse #/fuse-internals-extfx))

(define (extfx-run-getfx effects then)
  (internal:extfx-run-getfx effects then))

(define (extfx-spawn-dexed dexed-then)
  (internal:extfx-spawn-dexed dexed-then))

(define (extfx-table-each t on-element then)
  (internal:extfx-table-each t on-element then))


; TODO: See if we'll ever want to use this representation of parent
; sets. It avoids storing more than one entry for names of the form
; `(list 'name:subname-n n key orig)` that differ only in `n`, but the
; extra complexity seems to slow us down more than it helps us right
; now.
;
#|
(define-imitation-simple-struct
  (name-parent-bag? subnames direct-names)
  name-parent-bag
  'name-parent-bag
  (current-inspector)
  (auto-write)
  (auto-equal))

(define (name-parent-bag-empty)
  (name-parent-bag (hash) (hash)))

(define (name-parent-bag-add name bag)
  (dissect bag (name-parent-bag subnames direct-names)
  #/dissect name (unsafe:name name)
  #/w- go
    (fn n key original
      (name-parent-bag
        (hash-update subnames original
          (fn subnames
            (hash-update subnames key
              (fn existing-n #/max n existing-n)
              (fn n)))
          (fn #/hash))
        direct-names))
  #/mat name (list 'name:subname key original) (go 1 key original)
  #/mat name (list 'name:subname-n n key original) (go n key original)
  #/name-parent-bag subnames #/hash-set direct-names name #/trivial))

(define (name-parent-bag-has? name bag)
  (dissect bag (name-parent-bag subnames direct-names)
  #/dissect name (unsafe:name name)
  #/w- go
    (fn n key original
      (expect (hash-ref-maybe subnames original) (just subnames) #f
      #/expect (hash-ref-maybe subnames key) (just existing-n) #f
      #/<= n existing-n))
  #/mat name (list 'name:subname key original) (go 1 key original)
  #/mat name (list 'name:subname-n n key original) (go n key original)
  #/hash-has-key? direct-names name))
|#

(define (name-parent-bag-empty)
  (hash))

(define (name-parent-bag-add name bag)
  (dissect name (unsafe:name name)
  #/hash-set bag name #/trivial))

(define (name-parent-bag-has? name bag)
  (dissect name (unsafe:name name)
  #/hash-has-key? bag name))

(define (authorized-name? v)
  (internal:authorized-name? v))

(define/contract (authorized-name-subname-descends? a b)
  (-> authorized-name? authorized-name? boolean?)
  (dissect a (internal:authorized-name a-ds a-n a-parents)
  #/dissect b (internal:authorized-name b-ds b-n b-parents)
  #/mat (name-parent-bag-has? a-n b-parents) (just _)
    #t
    #f))

; NOTE:
;
; We always associate authorized names with root definition spaces,
; never with shadowing definition spaces. That's because we don't want
; to have to worry about whether those two parts of the code obtain
; the same familiarity tickets when they use `extfx-claim-unique` on
; the same authorized name value. They must, since that operation must
; be deterministic, but they must not, since the familiarity ticket is
; supposed to represent exclusive access.
;
; Most programs will only deal with a single call to `run-extfx!` and
; hence a single root definition space, which makes the
; `authorized-name-dspace-descends?` utility unnecessary. So the
; design of this utility is focused on serving the use needs of
; programs that use `run-extfx!` more than once.
;
; In this utility, we could just compare using `dspace-eq?` instead of
; `dspace-descends?`. However, it's reasonable that some parts of a
; program that might like to check for error conditions will only have
; access to a shadowing definition space, not the root. By using
; `dspace-descends?` here, we allow those programs to perform their
; checks.
;
(define (authorized-name-dspace-descends? name ds)
  (dissect name (internal:authorized-name name-ds _ _)
  #/dspace-descends? name-ds ds))

(define (authorized-name-dspace-ancestor/c ds)
  (make-flat-contract
    
    #:name `(authorized-name-dspace-ancestor/c ,ds)
    
    #:first-order
    (fn v
      (and
        (authorized-name? v)
        (authorized-name-dspace-descends? v ds)))))

(define (authorized-name-get-name n)
  (dissect n (internal:authorized-name ds n parents)
    n))

(struct-easy (dex-internals-authorized-name)
  #:other
  
  #:methods unsafe:gen:dex-internals
  [
    
    (define (dex-internals-tag this)
      'tag:dex-authorized-name)
    
    (define (dex-internals-autoname this)
      'tag:dex-authorized-name)
    
    (define (dex-internals-autodex this other)
      (just #/ordering-eq))
    
    (define (getfx-dex-internals-is-in this x)
      (getfx-done #/authorized-name? x))
    
    (define (getfx-dex-internals-name-of this x)
      (getfx-done
        (expect x (internal:authorized-name ds n parents) (nothing)
        #/dissect ds (internal:dspace _ (unsafe:name ds-name) _)
        #/dissect n (unsafe:name n)
        #/just #/unsafe:name #/list 'name:authorized-name ds-name n)))
    
    (define (getfx-dex-internals-dexed-of this x)
      (getfx-dex-internals-simple-dexed-of this x))
    
    (define (getfx-dex-internals-compare this a b)
      (expect a (internal:authorized-name a-ds a-n a-parents)
        (getfx-done #/nothing)
      #/expect b (internal:authorized-name b-ds b-n b-parents)
        (getfx-done #/nothing)
      #/getmaybefx-ordering-or
        (getfx-compare-by-dex (dex-dspace) a-ds b-ds)
        (getfx-compare-by-dex (dex-name) a-n b-n)))
  ])

(define (dex-authorized-name)
  (unsafe:dex #/dex-internals-authorized-name))

(define (nat-minus-name-size n name)
  (maybe-bind (nat->maybe n) #/fn n
  #/expect name (cons a b) (just n)
  #/maybe-bind (nat-minus-name-size n a) #/fn n
  #/maybe-bind (nat-minus-name-size n b) #/fn n
  #/just n))

(define (name-subname key-name original-name)
  (dissect key-name (unsafe:name key-name)
  #/dissect original-name (unsafe:name original-name)
  #/unsafe:name
  
  ; NOTE: As an optimization, if we take subnames multiple times in a
  ; row with the same key, we run-length-encode them so that we can
  ; more quickly compare one name with another.
  ;
  #/w- default (list 'name:subname key-name original-name)
  ; NOTE: If the key would take longer than a small constant amount of
  ; time to compare, we don't apply the optimization.
  #/expect (nat-minus-name-size 3 key-name) (just _) default
  #/w- go
    (fn n k orig
      (expect (equal? key-name k) #t default
      #/list 'name:subname-n (add1 n) k orig))
  #/mat original-name (list 'name:subname k orig) (go 1 k orig)
  #/mat original-name (list 'name:subname-n n k orig) (go n k orig)
    default))

(define (authorized-name-subname key-name original-name)
  (dissect original-name
    (internal:authorized-name ds original-name parents)
  #/internal:authorized-name
    ds
    (name-subname key-name original-name)
    (name-parent-bag-add original-name parents)))

; NOTE: The `authorized-name?` and the `familiarity-ticket?` passed
; into the body are for the same `name?`. The `authorized-name?`
; allows owner-style access to state resources using this name and its
; subnames, and the `familiarity-ticket?` allows making
; closed-world assumption (CWA) contributions to those state
; resources. Since the resources are all fresh, the body receives full
; permissions over them, and it can subdivide these permissions as
; needed for various access control policies.
;
(define
  (extfx-claim-unique
    n on-conflict on-familiarity-ticket-unspent then)
  (internal:extfx-claim-unique
    n on-conflict on-familiarity-ticket-unspent then))


(define (optionally-dexed? v)
  (or
    (internal:optionally-dexed-once? v)
    (internal:optionally-dexed-dexed? v)))

(define (optionally-dexed/c c)
  (w- c (coerce-contract 'optionally-dexed/c c)
  #/rename-contract
    (or/c
      (istruct/c internal:optionally-dexed-once c)
      (istruct/c internal:optionally-dexed-dexed #/dexed/c c))
    `(optionally-dexed/c ,(contract-name c))))

(define (optionally-dexed-once v)
  (internal:optionally-dexed-once v))

(define (optionally-dexed-dexed d)
  (internal:optionally-dexed-dexed d))

; TODO: See if we should export this.
(define/contract (optionally-dexed-value od)
  (-> optionally-dexed? any/c)
  (mat od (internal:optionally-dexed-once v) v
  #/dissect od (internal:optionally-dexed-dexed d)
    (dexed-get-value d)))


(define (extfx-put ds n on-cont-unspent comp)
  (internal:extfx-put ds n on-cont-unspent comp))

(define (getfx-get ds n on-stall)
  (internal:getfx-get ds n on-stall))


(define
  (extfx-private-put ds putter-name getter-name on-cont-unspent comp)
  (internal:extfx-private-put
    ds putter-name getter-name on-cont-unspent comp))

(define (getfx-private-get ds putter-name getter-name on-stall)
  (internal:getfx-private-get ds putter-name getter-name on-stall))


; An Interconfection pubsub is a monotonic state resource that can be
; used for extensibility purposes where the open-world assumption
; (OWA) is held. Each function written to a sub will be called exactly
; once for each argument written to a pub, much like event listeners
; being invoked with event values.
;
; When `dspace-shadower` is in use, pub or sub writes to a shadowing
; definition space will only interact with sub or pub writes to the
; same definition space or any of its ancestors. If two definition
; spaces are cousins or completely unrelated, their pub and sub writes
; will not interact.
;
; TODO:
;
; It may be possible to come up with a design for `extfx-pub-write`
; and `extfx-sub-write` where their `unique-name` parameter is
; replaced with a name that doesn't have to be unique. For instance,
; the `arg` and `func` parameters could be `optionally-dexed?` values
; such that two writes of the same dexed value to the same pub or sub
; under the same "pubber name" or "subber name" would combine together
; to act like a single write.
;
; However, it seems to be difficult to account for shadowing
; definition spaces this way. If writes of two different values are
; made to the same pubber name on two cousin definition spaces, that's
; fine and should lead to processes being spawned for each of them.
; However, if writes of the same value are made to those places, and
; then a write of the same value is made to a common ancestor
; definition space, then once all is said and done, there should only
; have been processes spawned for one of these writes.
;
; There are a few ways we could approach that:
;
;   - We could spawn processes only once if the same value is written
;     to two cousins, even if that value is never written to one of
;     their shared ancestors. Unfortunately, this essentially means
;     *all* values we might like to write to two different cousins
;     must be dexed (as opposed to optionally dexed).
;
;   - We could consider the identity of the definition space we're
;     writing to to be part of the name we're writing to. That way,
;     only writes to the exact same definition space can combine or
;     conflict with each other; writes to two different definition
;     spaces are always considered to be writes to two different
;     names.
;
;   - We could consider the identity of the definition space we're
;     writing to to be part of the *value* we're writing. That way,
;     writes to a definition space will always conflict with writes to
;     an ancestor or descendant thereof, since this extra part of the
;     value will differ.
;
; The latter two approaches seem the most likely to pay off well. The
; last one especially seems likely to be the most expressive in the
; right ways.
;
; The approach we're taking now, where the "name we're writing to" is
; claimed as a unique name, is sort of an inexpressive baseline while
; we figure out which of these others (or which combination of them!)
; would be best.
;
; Hmm, the reason our unique-name-based approach is inexpressive is
; that two processes can't use it to coordinate to spawn a single
; process. That is, if two processes perform writes, they're always
; under two names, and hence if they spawn any processes, they spawn a
; different process for each of those two writes. In the other
; approaches, two processes can write the same dexed value to the same
; name, spawning a single process as a result.
;
; So instead of pursuing those other approaches directly, what if we
; simply implemented a state resource that allowed
; `(dexed-first-order/c #/-> extfx?)` values to be written as a way to
; spawn processes? (TODO: Update this comment to reflect that we've
; now implemented this as `extfx-spawn-dexed`.)
;
; Well, then we run across the same design problem as before: What
; happens when two cousin shadowing definition spaces write to the
; same name and then one of their shared ancestors does too?
;
; Fortunately, in this case, the answer is much clearer: The value
; written is always dexed, so we don't need to store it under a "name"
; apart from the name obtained from the value itself; and since pure
; functions (in the Interconfection sense) and `extfx?` effects are
; deterministic and `extfx?` effects are idempotent, we never need to
; run the same process more than once, even if it's written to
; different definition spaces.
;
; Hmm, this means we should give `dspace?` and `authorized-name?`
; values dexes so they can be used from those dexed processes.
; (TODO: Update this comment to reflect that we've now implemented
; `dex-dspace` and `dex-authorized-name`.)
;
; It seems like with this infrastructure in place, we'll be able to
; emulate the other approaches above like so: Represent definition
; spaces (as far as those approaches are concerned) as pairs of a
; definition space and an unclaimed unique authorized name. Perform
; pub writes and sub writes by performing pub writes of certain
; compound data structures which include unique names derived from
; the one used. These are each processed by a single sub write at a
; definition space that all the others descend from. This sub write
; acts by spawning certain dexed processes, thereby achieving the
; spawn-only-once behavior we expect of dexed pub and sub writes.
; Differences between the three approaches can be accomplished using
; differences in this implementation. (Will this actually work? I'm
; not sure of the details here.)

(define (pub? v)
  (internal:pub? v))

(define (sub? v)
  (internal:sub? v))

(define (pub-dspace-descends? p ds)
  (dissect p (internal:pub p-ds pubsub-name)
  #/dspace-descends? p-ds ds))

(define (sub-dspace-descends? s ds)
  (dissect s (internal:sub s-ds pubsub-name)
  #/dspace-descends? s-ds ds))

(define (pub-ancestor/c ds)
  (make-flat-contract
    
    #:name `(pub-ancestor/c ,ds)
    
    #:first-order
    (fn v
      (and (pub? v) (pub-dspace-descends? v ds)))))

(define (sub-ancestor/c ds)
  (make-flat-contract
    
    #:name `(sub-ancestor/c ,ds)
    
    #:first-order
    (fn v
      (and (sub? v) (sub-dspace-descends? v ds)))))

(define (make-pub ds pubsub-name)
  (internal:pub ds pubsub-name))

(define (make-sub ds pubsub-name)
  (internal:sub ds pubsub-name))

(define (pub-restrict new-ds p)
  (dissect p (internal:pub original-ds pubsub-name)
  #/internal:pub new-ds pubsub-name))

(define (sub-restrict new-ds s)
  (dissect s (internal:sub original-ds pubsub-name)
  #/internal:sub new-ds pubsub-name))

(define (extfx-pub-write ds p unique-name on-conflict arg)
  (internal:extfx-pub-write ds p unique-name on-conflict arg))

(define (extfx-sub-write ds s unique-name on-conflict func)
  (internal:extfx-sub-write ds s unique-name on-conflict func))


(define (extfx-freshen ticket on-conflict then)
  (internal:extfx-freshen ticket on-conflict then))

(define (extfx-split-list ticket times on-conflict then)
  (internal:extfx-split-list ticket times on-conflict then))

(define (extfx-split-table ticket times on-conflict then)
  (internal:extfx-split-table ticket times on-conflict then))

(define (extfx-disburse ds hub-name on-cont-unspent comp-ticket)
  (internal:extfx-disburse ds hub-name on-cont-unspent comp-ticket))

(define (extfx-imburse ds hub-familiarity-ticket on-conflict then)
  (internal:extfx-imburse ds hub-familiarity-ticket on-conflict then))

(define (extfx-ct-continue ticket on-conflict value)
  (internal:extfx-ct-continue ticket on-conflict value))

(define (extfx-ft-subname ticket key on-conflict then)
  (internal:extfx-ft-subname ticket key on-conflict then))

(define
  (extfx-ft-restrict ticket ds on-conflict on-restriction-error then)
  (internal:extfx-ft-restrict
    ticket ds on-conflict on-restriction-error then))


(define
  (extfx-contribute
    ds collector-familiarity-ticket contributor-name
    on-familiarity-double-spend on-cont-unspent comp)
  (internal:extfx-contribute
    ds collector-familiarity-ticket contributor-name
    on-familiarity-double-spend on-cont-unspent comp))

(define (extfx-collect ds collector-name then)
  (internal:extfx-collect ds collector-name then))


(define-imitation-simple-struct
  (run-extfx-result-success? run-extfx-result-success-value)
  run-extfx-result-success
  'run-extfx-result-success
  (current-inspector)
  (auto-write)
  (auto-equal))
(define-imitation-simple-struct
  (run-extfx-result-failure? run-extfx-result-failure-errors)
  run-extfx-result-failure
  'run-extfx-result-failure
  (current-inspector)
  (auto-write)
  (auto-equal))

(define/contract (run-extfx-errors? v)
  (-> any/c boolean?)
  (internal:run-extfx-errors? v))


(struct-easy (process-entry reads process))
(struct-easy
  (disbursement-entry source-ds source-name target-ds target-name))
(struct-easy
  (unspent-ticket-entry-familiarity-ticket
    on-unspent ds n disbursements))
(struct-easy (unspent-ticket-entry-anonymous on-unspent))
(struct-easy (db-table-each-entry-incomplete))
(struct-easy (db-table-each-entry-complete reads v))
(struct-easy (do-not-conflict-entry ds value))
(struct-easy
  (db-put-entry-not-written
    do-not-conflict-entries continuation-ticket-symbols))
(struct-easy
  (db-put-entry-written reads-of-first-write existing-value))
(struct-easy (pubsub-write-entry reads value))
(struct-easy (db-pubsub-entry descendants pub-writes sub-writes))

; TODO: Clients can abuse a call to `run-extfx!` just to generate a
; fresh `name?` value for use outside that call. If there's anything
; we can do to prevent that, let's consider doing it.
(define (run-extfx! on-continuation-ticket-unspent body)
  (w- runtime-symbol (gensym)
  #/w- root-ds
    (internal:dspace runtime-symbol
      (unsafe:name #/list 'name:dspace runtime-symbol)
      (list))
  #/w- root-unique-name
    (unsafe:name #/list 'name:root-unique-name runtime-symbol)
  #/w- root-unique-authorized-name
    (internal:authorized-name root-ds root-unique-name
      (name-parent-bag-empty))
  #/w- root-continuation-ticket-symbol (gensym)
  #/w- root-continuation-ticket
    (internal:continuation-ticket
      root-continuation-ticket-symbol root-ds
      (fn result
        (extfx-finish-run root-ds result)))
  #/w- reads-union
    (fn a b
      (hasheq
        
        'spend-ticket
        (hash-union
          (hash-ref a 'spend-ticket)
          (hash-ref b 'spend-ticket)
          #:combine
        #/fn a b
        #/trivial-union a b)
        
        'claim-unique
        (table-union
          (hash-ref a 'claim-unique)
          (hash-ref b 'claim-unique)
        #/fn a b
        #/trivial-union a b)
        
        'put
        (table-union
          (hash-ref a 'put)
          (hash-ref b 'put)
        #/fn a b
        #/table-union a b #/fn a b
        #/table-union a b #/fn a b
        #/trivial-union a b)
        
        'private-put
        (table-union
          (hash-ref a 'private-put)
          (hash-ref b 'private-put)
        #/fn a b
        #/table-union a b #/fn a b
        #/table-union a b #/fn a b
        #/trivial-union a b)))
  #/w-loop next-full
    
    processes
    (list #/process-entry
      (hasheq
        'spend-ticket (hasheq)
        'claim-unique (table-empty)
        'put (table-empty)
        'private-put (table-empty))
      (body root-ds root-unique-authorized-name
        root-continuation-ticket))
    
    rev-next-processes (list)
    
    unspent-tickets
    (hasheq
      root-continuation-ticket-symbol
      (unspent-ticket-entry-anonymous on-continuation-ticket-unspent))
    
    db
    (hasheq
      'claim-unique (table-empty)
      'spawn-dexed (table-empty)
      'table-each (hasheq)
      'put (table-empty)
      'private-put (table-empty)
      'pubsub (table-empty)
      'finish-run (nothing))
    
    rev-errors (list)
    did-something #f
    
    (expect processes (cons this-process-entry processes)
      (mat rev-next-processes (list)
        
        ; If there are no processes left, we're done. If we haven't
        ; encountered any particular errors yet, then we look for
        ; unspent tickets and assemble the errors associated with
        ; those. Then, if we have any errors, we return that
        ; collection of errors. Otherwise, we return the `finish-run`
        ; value.
        ;
        ; NOTE: We could have this report the unspent ticket errors
        ; all the time, but if we've encountered any other errors,
        ; those are more likely to describe the proximal cause of the
        ; problems with the program. After all, if the computation had
        ; been able to proceed without encountering those errors, it
        ; would have had more chances to spend the remaining tickets.
        ;
        (w- rev-errors
          (expect rev-errors (list) rev-errors
          #/list-map (hash->list unspent-tickets)
          #/dissectfn (cons ticket-symbol entry)
            (mat entry
              (unspent-ticket-entry-familiarity-ticket
                on-unspent ds n disbursements)
              on-unspent
            #/mat entry (unspent-ticket-entry-anonymous on-unspent)
              on-unspent
            #/error "Internal error: Encountered an unrecognized unspent ticket entry"))
        #/mat rev-errors (list)
          (dissect (hash-ref db 'finish-run) (just finish-value)
          #/run-extfx-result-success finish-value)
          (run-extfx-result-failure #/internal:run-extfx-errors
          #/reverse rev-errors))
      #/if (not did-something)
        ; The processes are stalled. We log errors corresponding to
        ; all the processes.
        (run-extfx-result-failure #/internal:run-extfx-errors
        #/reverse #/append
          (list-bind rev-next-processes
          #/dissectfn (process-entry reads process)
            (w- handle-generic-get
              (fn ds on-stall maybe-db-part
                (dissect ds (internal:dspace _ ds-name parents-list)
                #/w-loop next places (cons ds-name parents-list)
                  (expect places (cons place places) (list on-stall)
                  #/expect maybe-db-part (just db-part)
                    (next places)
                  #/expect (table-get place db-part) (just entry)
                    (next places)
                  #/mat entry
                    (db-put-entry-not-written
                      do-not-conflict-entries
                      continuation-ticket-symbols)
                    (if
                      (list-any continuation-ticket-symbols #/fn sym
                        (hash-has-key? unspent-tickets sym))
                      ; There's an unspent continuation ticket which
                      ; would have unstalled this process if it were
                      ; spent, so it can describe a more proximal cause
                      ; of the error than this process can.
                      (list)
                    #/next places)
                  #/mat entry (db-put-entry-written _ _)
                    (error "Internal error: Expected an getfx-get not to be stalled if any of the parents had db-put-entry-written")
                  #/error "Internal error: Encountered an unknown kind of db-put entry")))
            
            #/mat process
              (extfx-finish-table-each-then ds table-each-symbol then)
              ; NOTE: These processes can't stall unless there's still
              ; an unspent ticket at large, so the error message for
              ; that unspent ticket can describe a more proximal cause
              ; than we can here.
              (list)
            #/mat process
              (internal:extfx-run-getfx
                (internal:getfx-get ds n on-stall)
                then)
              (handle-generic-get ds
                (error-definer-or-message on-stall
                  "Read from a name that was never defined")
                (table-get n (hash-ref db 'put)))
            #/mat process
              (internal:extfx-run-getfx
                (internal:getfx-private-get
                  ds putter-name getter-name on-stall)
                then)
              (w- getter-name (authorized-name-get-name getter-name)
              #/handle-generic-get ds
                (error-definer-or-message on-stall
                  "Read from a private name that was never defined")
                (maybe-bind
                  (table-get putter-name (hash-ref db 'private-put))
                #/fn db-private-put-for-putter
                #/table-get getter-name db-private-put-for-putter))
            #/mat process
              (internal:extfx-collect ds collector-name then)
              ; NOTE: These processes can't stall unless there's still
              ; an unspent ticket at large, so the error message for
              ; that unspent ticket can describe a more proximal cause
              ; than we can here.
              (list)
            #/error "Internal error: Encountered a stalled process that shouldn't have been able to stall"))
          rev-errors)
      #/next-full (reverse rev-next-processes) (list) unspent-tickets
        db rev-errors #f)
    #/dissect this-process-entry (process-entry reads process)
    #/w- next-simple
      (fn processes
        (next-full
          processes rev-next-processes unspent-tickets db rev-errors
          #t))
    #/w- next-zero
      (fn
        (next-simple processes))
    #/w- next-one-fruitful
      (fn process
        (next-simple #/cons process processes))
    #/w- next-fruitless
      (fn
        ; NOTE: We can't use `next-one-fruitful` here because we don't
        ; want to make `did-something` true if it isn't already.
        (next-full
          processes (cons this-process-entry rev-next-processes)
          unspent-tickets db rev-errors did-something))
    #/w- next-with-error-definer
      (fn on-error default-message
        (next-full
          processes rev-next-processes unspent-tickets db
          (cons (error-definer-or-message on-error default-message)
            rev-errors)
          #t))
    #/w- next-with-error
      (fn error
        (next-with-error-definer (error-definer-uninformative) error))
    #/w- next-purging
      (fn on-error default-message should-keep
        (next-full
          (list-keep processes #/dissectfn (process-entry reads _)
            (should-keep reads))
          (list-keep rev-next-processes
          #/dissectfn (process-entry reads _)
            (should-keep reads))
          
          ; TODO:
          ;
          ; Filter `unspent-tickets`, `db`, and `rev-errors` the way
          ; we're already filtering `processes` and
          ; `rev-next-processes`. It'll be particularly complicated to
          ; filter `db`, since we may want to remove entries that were
          ; based on conflicts but not remove certain entries that are
          ; actively causing conflicts themselves. If we remove all
          ; but one of the conflicting entries for something, should
          ; the last one suddenly proceed as though there wasn't a
          ; conflict? I suppose it should... in which case we should
          ; really be doing all this filtering-out in a way we can
          ; restore again when the conflict has been cleared up.
          ;
          ; There might be an easier approach where if we *would* add
          ; a process with a new `reads` entry to the list, we set it
          ; aside instead. We only unblock the set-aside processes
          ; once we've run out of other processes, and we only unblock
          ; the ones whose dependencies we haven't encountered
          ; conflicts for yet (and we unblock them all at once, for
          ; determinism's sake). When we encounter a conflict, if it's
          ; for a dependency we haven't approved yet, we simply never
          ; run the things that depend on it. If it's for a dependency
          ; we *have* approved, then... we have a more complicated
          ; situation.
          ;
          ; In that case, for the sake of conveying as much
          ; information as possible, we could unblock various
          ; *possible subsets* of the processes we unblocked and
          ; report each of the errors that happens in each of those
          ; cases. However, those alternate universes are bound to be
          ; pretty confusing for someone who's trying to read an error
          ; report, and it could take a long time to compute them all.
          ;
          ; How about this: If a conflict is caused purely by the
          ; recently unblocked processes, we try purging those and
          ; reporting the error as though we didn't unblock them,
          ; treating the newer writes as non-canonical. If there is no
          ; error after we purge them, then we go ahead and report the
          ; errors they cause, but the errors reported this way may
          ; vary from one run to the next depending on race conditions
          ; in `run-extfx!`, choices made by a user through a step
          ; debugger interface, or slight, seemingly unrelated
          ; differences in the architecture of the program.
          ;
          unspent-tickets db
          (cons (error-definer-or-message on-error default-message)
            rev-errors)
          
          #t))
    
    #/w- claim-unique
      (fn n reads db on-error default-message then
        (w- n (authorized-name-get-name n)
        #/expect (table-get n (hash-ref db 'claim-unique)) (nothing)
          (next-purging on-error default-message
            (fn reads
              (mat (table-get n (hash-ref reads 'claim-unique))
                (just _)
                #t
                #f)))
        #/w- reads
          (hash-update reads 'claim-unique #/fn reads-claim-unique
            (table-shadow n (just #/trivial) reads-claim-unique))
        #/w- db
          (hash-update db 'claim-unique #/fn db-claim-unique
            (table-shadow n (just #/trivial) db-claim-unique))
        #/then reads db))
    #/w- spend-ticket
      (fn
        ticket-symbol reads unspent-tickets on-error default-message
        then
        
        (expect (hash-ref-maybe unspent-tickets ticket-symbol)
          (just entry)
          (next-purging on-error default-message
            (fn reads
              (hash-has-key? (hash-ref reads 'spend-ticket)
                ticket-symbol)))
        #/w- reads
          (hash-update reads 'spend-ticket #/fn reads-spend-ticket
            (hash-set reads-spend-ticket ticket-symbol (trivial)))
        #/w- unspent-tickets
          (hash-remove unspent-tickets ticket-symbol)
        #/then reads unspent-tickets entry))
    #/w- handle-generic-put
      (fn
        unspent-tickets reads ds db-update make-finish on-cont-unspent
        comp
        
        (dissect ds (internal:dspace _ ds-name _)
        #/w- continuation-ticket-symbol (gensym)
        #/w- continuation-ticket
          (internal:continuation-ticket
            continuation-ticket-symbol root-ds
            (dissectfn (list on-conflict value)
              (make-finish on-conflict value)))
        #/next-full
          (cons (process-entry reads (comp continuation-ticket))
            processes)
          rev-next-processes
          (hash-set unspent-tickets continuation-ticket-symbol
            (unspent-ticket-entry-anonymous on-cont-unspent))
          
          ; NOTE: We modify `db-part` here so that we know
          ; that this value will be written using this continuation
          ; ticket. That way, we're able to focus the error message by
          ; removing "couldn't read" errors if there's an unspent
          ; ticket error involving the continuation ticket.
          ;
          (db-update db #/fn db-part
            (table-update-default db-part ds-name
              (db-put-entry-not-written (list) (list))
            #/fn entry
              (expect entry
                (db-put-entry-not-written
                  do-not-conflict-entries continuation-ticket-symbols)
                entry
              #/db-put-entry-not-written
                do-not-conflict-entries
                (cons continuation-ticket-symbol
                  continuation-ticket-symbols))))
          
          rev-errors #t))
    #/w- handle-generic-finish-put
      (fn unspent-tickets reads ds db-get db-update on-conflict value
        ; If there has already been a definition installed for this
        ; purpose in this definition space, this checks that the
        ; proposed dexed value matches the stored dexed value.
        ; Otherwise, it stores the proposed value without question.
        (dissect on-conflict
          (internal:success-or-error-definer
            on-conflict on-no-conflict)
        #/dissect ds (internal:dspace _ ds-name parents-list)
        #/w- next-conflict
          (fn message
            (next-purging on-conflict message #/fn reads
              (expect (db-get reads) (just reads-part) #f
              #/list-any (cons ds-name parents-list) #/fn parent
                (mat (table-get parent reads-part) (just _)
                  #t
                  #f))))
        #/w- err-once
          (fn
            (next-conflict
              "Wrote to the same name where at least one of the writes was only expecting one write overall"))
        #/w- do-not-conflict
          (fn existing-value then
            (mat existing-value
              (internal:optionally-dexed-once existing-value)
              (err-once)
            #/mat existing-value
              (internal:optionally-dexed-dexed existing-dexed)
              (mat value (internal:optionally-dexed-once value)
                (err-once)
              #/mat value (internal:optionally-dexed-dexed d)
                (expect
                  (pure-run-getfx #/getfx-is-eq-by-dex (dex-name)
                    (dexed-get-name existing-dexed)
                    (dexed-get-name d))
                  #t
                  (next-conflict
                    "Wrote to the same name where two of the writes were dexed writes with different values")
                #/then)
              #/error "Internal error: Encountered an unknown kind of optionally dexed value")
            #/error "Internal error: Encountered an unknown kind of optionally dexed value"))
        #/w- next-after-put
          (fn ds-name-written-to db
            (next-full
              (cons
                (process-entry
                  (db-update reads #/fn reads-part
                    (table-shadow ds-name-written-to (just #/trivial)
                      reads-part))
                  on-no-conflict)
                processes)
              rev-next-processes unspent-tickets db rev-errors #t))
        #/w- check-ds-name
          (fn then
            (expect (db-get db) (just db-part) (then #/nothing)
            #/expect (table-get ds-name db-part) (just entry)
              (then #/nothing)
            #/mat entry
              (db-put-entry-not-written
                do-not-conflict-entries continuation-ticket-symbols)
              (w-loop next
                do-not-conflict-entries do-not-conflict-entries
                
                (expect do-not-conflict-entries
                  (cons entry do-not-conflict-entries)
                  (then #/nothing)
                #/dissect entry
                  (do-not-conflict-entry _ do-not-conflict-value)
                #/do-not-conflict do-not-conflict-value #/fn
                  (next do-not-conflict-entries)))
            #/mat entry (db-put-entry-written _ existing-value)
              (do-not-conflict existing-value #/fn
                (then #/just ds-name))
            #/error "Internal error: Encountered an unknown kind of db put entry"))
        #/check-ds-name #/fn already-written
        #/mat already-written (just ds-name-written-to)
          (next-after-put ds-name-written-to db)
        #/w- check-parents
          (fn then
            (w-loop next parents-to-check parents-list
              (expect parents-to-check (cons parent parents-to-check)
                (then #/nothing)
              #/expect (db-get db) (just db-part)
                (next parents-to-check)
              #/expect (table-get parent db-part) (just entry)
                (next parents-to-check)
              #/mat entry
                (db-put-entry-not-written
                  do-not-conflict-entries continuation-ticket-symbols)
                (next parents-to-check)
              #/mat entry (db-put-entry-written _ existing-value)
                
                ; NOTE: If we find a `db-put-entry-written` entry for
                ; even one of the parents, checking that one is enough
                ; to check all the parents. That's why we can proceed
                ; with `(then #/just parent)` instead of
                ; `(next parents-to-check)` here.
                ;
                (do-not-conflict existing-value #/fn
                  (then #/just parent))
              
              #/error "Internal error: Encountered an unknown kind of db put entry")))
        #/check-parents #/fn already-written
        #/mat already-written (just ds-name-written-to)
          (next-after-put ds-name-written-to db)
        
        ; We write the entry for `ds-name`, and we erase the existing
        ; entries for names that shadowed it since they're redundant.
        ;
        ; TODO: There's no point in erasing the redundant entries, but
        ; we implemented it in case we want to iterate over them for
        ; `extfx-{pub,sub}-write` and don't want to see duplicates.
        ; See if we'll need it for that. If not, se if we should
        ; remove it to simplify. If we remove it, we also won't need
        ; the `ds` slot of `do-not-conflict-entry` struct any more.
        ;
        #/w- db
          (db-update db #/fn db-part
            (table-shadow ds-name
              (just #/db-put-entry-written reads value)
            #/expect (table-get ds-name db-part) (just entry) db-part
            #/dissect entry
              (db-put-entry-not-written
                do-not-conflict-entries continuation-ticket-symbols)
            #/list-foldl db-part do-not-conflict-entries
            #/fn db-part entry
              (dissect entry
                (do-not-conflict-entry ds-name-to-erase _)
              #/table-shadow ds-name-to-erase (nothing) db-part)))
        
        ; We write the entries for `parents-list`.
        #/w- write-parents
          (fn db then
            (w-loop next parents-to-write parents-list db db
              (expect parents-to-write (cons parent parents-to-write)
                (then db)
              #/next parents-to-write
                (db-update db #/fn db-part
                  (table-update-default db-part parent
                    (db-put-entry-not-written (list) (list))
                  #/fn entry
                    (mat entry
                      (db-put-entry-not-written
                        do-not-conflict-entries
                        continuation-ticket-symbols)
                      (db-put-entry-not-written
                        (cons (do-not-conflict-entry ds-name value)
                          do-not-conflict-entries)
                        continuation-ticket-symbols)
                    #/mat entry
                      (db-put-entry-written _ existing-value)
                      (error "Internal error: Expected already-written to become true if any of the parents had db-put-entry-written")
                    #/error "Internal error: Encountered an unknown kind of db-put entry"))))))
        #/write-parents db #/fn db
        #/next-after-put ds-name db))
    #/w- handle-generic-get-next
      (fn reads ds db-get db-update next-then
        (dissect ds (internal:dspace _ ds-name parents-list)
        #/expect (db-get db) (just db-part) (next-fruitless)
        #/w-loop next places-to-check (cons ds-name parents-list)
          (expect places-to-check (cons place places-to-check)
            (next-fruitless)
          #/expect (table-get place db-part) (just value)
            (next places-to-check)
          #/expect value
            (db-put-entry-written reads-of-first-write existing-value)
            (next places-to-check)
          #/next-then
            
            ; NOTE: In the past, we've called
            ; `(reads-union reads-of-first-write ...)` on this updated
            ; `reads` table so that it'll be easy to purge processes
            ; when there's a write conflict. However, this
            ; `reads-union` operation likely imposed a time cost on
            ; *every read* proportional to the number of unique things
            ; the process had already read. We've observed this having
            ; a significant performance cost in the Cene for Racket
            ; unit tests.
            ;
            ; TODO: Instead, have `next-purging` iterate over `db`
            ; and do a recursive purge for each entry that has a
            ; `reads-of-first-write` containing the conflicted entry.
            ; (That is to say, definitions which were based on a
            ; purged definition should also be purged.) Purging
            ; information after an error is probably something we
            ; should only have to pay for when we have an error
            ; anyway, and even then, it only serves to simplify the
            ; error report, which may often be simple enough already.
            ;
            (db-update reads #/fn reads-part
              (table-shadow place (just #/trivial) reads-part))
            
            (optionally-dexed-value existing-value))))
    #/w- handle-generic-get
      (fn ds db-get db-update then
        ; If there has not yet been a definition installed for this
        ; purpose in this definition space, we set this process aside
        ; and come back to it later. If there has, we call `then` with
        ; that defined value and set up its result process to be
        ; handled next.
        (handle-generic-get-next reads ds db-get db-update
        #/fn reads value
          (next-one-fruitful #/process-entry reads (then value))))
    #/w- handle-generic-pubsub-write
      (fn ds pubsub-name write-entry get-other-writes spawn
        (dissect ds (internal:dspace _ ds-name parents-list)
        #/w- pubsub-name (authorized-name-get-name pubsub-name)
        #/w- db
          (hash-update db 'pubsub #/fn db-pubsub
            (table-update-default db-pubsub pubsub-name (table-empty)
            #/fn db-pubsub-for-name
              (table-update-default db-pubsub-for-name ds-name
                (db-pubsub-entry (table-empty) (list) (list))
                write-entry)))
        #/w- add-descendants
          (fn db then
            (w-loop next parents parents-list db db
              (expect parents (cons parent parents)
                (then db)
              #/next parents
                (hash-update db 'pubsub #/fn db-pubsub
                  (table-update-default db-pubsub pubsub-name
                    (table-empty)
                  #/fn db-pubsub-for-name
                    (table-update-default db-pubsub-for-name parent
                      (db-pubsub-entry (table-empty) (list) (list))
                    #/dissectfn
                      (db-pubsub-entry
                        descendants pub-writes sub-writes)
                      (db-pubsub-entry
                        (table-shadow ds-name (just #/trivial)
                          descendants)
                        pub-writes
                        sub-writes)))))))
        #/add-descendants db #/fn db
        #/w- other-writes
          (expect (table-get pubsub-name (hash-ref db 'pubsub))
            (just db-pubsub-for-name)
            (list)
          #/append
            (list-bind (cons ds-name parents-list) #/fn parent
              (expect (table-get parent db-pubsub-for-name)
                (just entry)
                (list)
              #/get-other-writes entry))
            (dissect (table-get ds-name db-pubsub-for-name)
              (just #/db-pubsub-entry (unsafe:table descendants) _ _)
            #/list-bind (hash->list descendants) #/dissectfn (cons k v)
              (dissect (table-get (unsafe:name k) db-pubsub-for-name)
                (just entry)
              #/get-other-writes entry)))
        #/w-loop next processes processes other-writes other-writes
          (expect other-writes (cons other-write-entry other-writes)
            (next-full
              processes rev-next-processes unspent-tickets db rev-errors
              #t)
          #/dissect other-write-entry
            (pubsub-write-entry write-reads other-value)
          #/next
            (cons
              (process-entry (reads-union reads write-reads)
                (spawn other-value))
              processes)
            other-writes)))
    #/w- parse-ticket
      (fn ticket
        (mat ticket
          (internal:continuation-ticket ticket-symbol ds then)
          (list
            ticket-symbol
            ds
            (fn new-ticket-symbol
              (internal:continuation-ticket
                new-ticket-symbol ds then)))
        #/mat ticket (internal:familiarity-ticket ticket-symbol ds)
          (list
            ticket-symbol
            ds
            (fn new-ticket-symbol
              (internal:familiarity-ticket new-ticket-symbol ds)))
        #/error "Internal error: Encountered an unrecognized ticket value"))
    
    
    #/mat process
      (internal:extfx-run-getfx (internal:getfx-done result) then)
      (next-one-fruitful #/process-entry reads (then result))
    #/mat process
      (internal:extfx-run-getfx
        (internal:getfx-bind effects then-1)
        then-2)
      (next-one-fruitful #/process-entry reads
        (internal:extfx-run-getfx effects #/fn intermediate
        #/internal:extfx-run-getfx (then-1 intermediate) then-2))
    #/mat process (internal:extfx-noop)
      (next-zero)
    #/mat process (internal:extfx-fused a b)
      (next-simple #/list*
        (process-entry reads b)
        (process-entry reads a)
        processes)
    #/mat process
      (internal:extfx-run-getfx (internal:getfx-err on-execute) then)
      (next-with-error-definer on-execute
        "Executed an unexpected part of the program")
    #/mat process (internal:extfx-spawn-dexed dexed-then)
      (w- name (dexed-get-name dexed-then)
      #/w- then (dexed-get-value dexed-then)
      #/mat (table-get name (hash-ref db 'spawn-dexed)) (just _)
        ; TODO: In this case, where we discover the process has
        ; already been spawned, see if we should somehow store the
        ; current value of `reads` into the `db`. Is there any way we
        ; would use this information even if we had it stored?
        (next-zero)
      #/w- then-result (then)
      ; NOTE DEXED-FIRST-ORDER/C: We have to check this result
      ; manually since we can't use higher-order contracts on a dexed
      ; value.
      #/expect (extfx? then-result) #t
        (raise-arguments-error 'extfx-spawn-dexed
          "expected the result of dexed-then to be an extfx value"
          "dexed-then" dexed-then
          "then-result" then-result)
      #/next-full
        (cons (process-entry reads then-result) processes)
        rev-next-processes unspent-tickets
        (hash-update db 'spawn-dexed #/fn db-spawn-dexed
          (table-shadow name (just #/trivial) db-spawn-dexed))
        rev-errors #t)
    #/mat process (internal:extfx-table-each t on-element then)
      (dissect t (unsafe:table t)
      #/w- table-each-symbol (gensym)
      #/w- entries (hash->list t)
      #/mat entries (list)
        (next-one-fruitful #/process-entry reads (then #/table-empty))
      #/w-loop next
        entries (hash->list t)
        db-table-each-entry (table-empty)
        processes processes
        unspent-tickets unspent-tickets
        
        (expect entries (cons entry entries)
          (next-full
            (cons
              (process-entry
                reads
                (extfx-finish-table-each-then
                  root-ds table-each-symbol then))
              processes)
            rev-next-processes unspent-tickets
            (hash-update db 'table-each #/fn db-table-each
              (hash-set db-table-each table-each-symbol
                db-table-each-entry))
            rev-errors #t)
        #/dissect entry (cons k v)
        #/w- k (unsafe:name k)
        #/dissect (on-element v) (list on-cont-unspent then)
        #/w- on-cont-unspent
          (error-definer-or-message on-cont-unspent
            "Expected an extfx-table-each continuation to be continued")
        #/w- element-continuation-ticket-symbol (gensym)
        #/w- element-continuation-ticket
          (internal:continuation-ticket
            element-continuation-ticket-symbol root-ds
            (fn result
              (extfx-finish-table-each-element
                root-ds table-each-symbol k result)))
        #/next
          entries
          (table-shadow k (db-table-each-entry-incomplete)
            db-table-each-entry)
          (cons
            (process-entry
              reads
              (then element-continuation-ticket))
            processes)
          (hash-set unspent-tickets element-continuation-ticket-symbol
            (unspent-ticket-entry-anonymous on-cont-unspent))))
    #/mat process
      (extfx-finish-table-each-element ds table-each-symbol k result)
      (expect (dspace-eq? root-ds ds) #t
        (next-with-error "Expected ds to be the extfx runner's root definition space")
      #/next-full
        processes rev-next-processes unspent-tickets
        (hash-update db 'table-each #/fn db-table-each
          (hash-ref db-table-each table-each-symbol #/fn db-part
            (table-shadow k
              (just #/db-table-each-entry-complete reads result)
              db-part)))
        rev-errors #t)
    #/mat process
      (extfx-finish-table-each-then ds table-each-symbol then)
      (expect (dspace-eq? root-ds ds) #t
        (next-with-error "Expected ds to be the extfx runner's root definition space")
      #/dissect
        (hash-ref (hash-ref db 'table-each) table-each-symbol)
        (unsafe:table db-part)
      #/expect
        (hash-v-all db-part #/fn v
          (mat v (db-table-each-entry-complete reads v) #t #f))
        #t
        (next-fruitless)
      #/next-one-fruitful #/process-entry
        (list-foldl reads (hash->list db-part) #/fn reads entry
          (dissect entry
            (cons k #/db-table-each-entry-complete more-reads v)
          #/reads-union reads more-reads))
        (then #/unsafe:table #/hash-v-map db-part #/fn v
          (dissect v (db-table-each-entry-complete reads v)
            v)))
    
    #/mat process
      (internal:extfx-claim-unique
        n on-conflict on-familiarity-ticket-unspent then)
      (expect (authorized-name-dspace-descends? n root-ds) #t
        (next-with-error "Expected n to be a name authorized for the extfx runner's root definition space")
      #/claim-unique n reads db on-conflict
        "Tried to claim a name unique twice"
      #/fn reads db
      #/w- fresh-ticket-symbol (gensym)
      #/w- fresh-name
        (unsafe:name #/list 'name:claim-unique-result (gensym))
      #/w- fresh-authorized-name
        (internal:authorized-name root-ds fresh-name
          (name-parent-bag-empty))
      #/w- familiarity-ticket-symbol (gensym)
      #/w- on-familiarity-ticket-unspent
        (error-definer-or-message on-familiarity-ticket-unspent
          "Expected an extfx-claim-unique continuation to be continued")
      #/w- disbursements (table-empty)
      #/w- familiarity-ticket
        (internal:familiarity-ticket
          familiarity-ticket-symbol
          
          ; NOTE: This creates a familiarity ticket for `root-ds`,
          ; even if the part of the program that performs an
          ; `extfx-claim-unique` effect is otherwise localized to a
          ; descendant shadowing definition space.
          ;
          root-ds)
      #/next-full
        (cons
          (process-entry
            reads
            (then fresh-authorized-name familiarity-ticket))
          processes)
        rev-next-processes
        (hash-set unspent-tickets familiarity-ticket-symbol
          (unspent-ticket-entry-familiarity-ticket
            on-familiarity-ticket-unspent root-ds
            fresh-authorized-name disbursements))
        db rev-errors #t)
    
    #/mat process (internal:extfx-put ds n on-cont-unspent comp)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/w- n (authorized-name-get-name n)
      #/w- on-cont-unspent
        (error-definer-or-message on-cont-unspent
          "Expected an extfx-put continuation to be continued")
      #/handle-generic-put unspent-tickets reads ds
        (fn db func
          (hash-update db 'put #/fn db-put
            (table-update-default db-put n (table-empty) func)))
        (fn on-conflict value
          (extfx-finish-put ds n on-conflict value))
        on-cont-unspent comp)
    #/mat process (extfx-finish-put ds n on-conflict value)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/handle-generic-finish-put unspent-tickets reads ds
        (fn db
          (table-get n (hash-ref db 'put)))
        (fn db func
          (hash-update db 'put #/fn db-put
            (table-update-default db-put n (table-empty) func)))
        on-conflict value)
    #/mat process
      (internal:extfx-run-getfx (internal:getfx-get ds n on-stall)
        then)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/handle-generic-get ds
        (fn db
          (table-get n (hash-ref db 'put)))
        (fn db func
          (hash-update db 'put #/fn db-put
            (table-update-default db-put n (table-empty) func)))
        then)
    
    #/mat process
      (internal:extfx-private-put
        ds putter-name getter-name on-cont-unspent comp)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/w- putter-name (authorized-name-get-name putter-name)
      #/w- on-cont-unspent
        (error-definer-or-message on-cont-unspent
          "Expected an extfx-private-put continuation to be continued")
      #/handle-generic-put unspent-tickets reads ds
        (fn db func
          (hash-update db 'private-put #/fn db-private-put
            (table-update-default db-private-put putter-name
              (table-empty)
            #/fn db-private-put-for-putter
              (table-update-default db-private-put-for-putter
                getter-name
                (table-empty)
                func))))
        (fn on-conflict value
          (extfx-finish-private-put
            ds putter-name getter-name on-conflict value))
        on-cont-unspent comp)
    #/mat process
      (extfx-finish-private-put
        ds putter-name getter-name on-conflict value)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/handle-generic-finish-put unspent-tickets reads ds
        (fn db
          (maybe-bind
            (table-get putter-name (hash-ref db 'private-put))
          #/fn db-private-put-for-putter
          #/table-get getter-name db-private-put-for-putter))
        (fn db func
          (hash-update db 'private-put #/fn db-private-put
            (table-update-default db-private-put putter-name
              (table-empty)
            #/fn db-private-put-for-putter
              (table-update-default db-private-put-for-putter
                getter-name
                (table-empty)
                func))))
        on-conflict value)
    #/mat process
      (internal:extfx-run-getfx
        (internal:getfx-private-get
          ds putter-name getter-name on-stall)
        then)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/w- getter-name (authorized-name-get-name getter-name)
      #/handle-generic-get ds
        (fn db
          (maybe-bind
            (table-get putter-name (hash-ref db 'private-put))
          #/fn db-private-put-for-putter
          #/table-get getter-name db-private-put-for-putter))
        (fn db func
          (hash-update db 'private-put #/fn db-private-put
            (table-update-default db-private-put putter-name
              (table-empty)
            #/fn db-private-put-for-putter
              (table-update-default db-private-put-for-putter
                getter-name
                (table-empty)
                func))))
        then)
    
    #/mat process
      (internal:extfx-pub-write ds p unique-name on-conflict arg)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/dissect p (internal:pub _ pubsub-name)
      #/claim-unique unique-name reads db on-conflict
        "Tried to claim a name unique twice"
      #/fn reads db
      #/handle-generic-pubsub-write ds pubsub-name
        (dissectfn (db-pubsub-entry descendants pub-writes sub-writes)
          (db-pubsub-entry
            descendants
            (cons (pubsub-write-entry reads arg) pub-writes)
            sub-writes))
        (dissectfn (db-pubsub-entry descendants pub-writes sub-writes)
          sub-writes)
        (fn func
          (func arg)))
    #/mat process
      (internal:extfx-sub-write ds s unique-name on-conflict func)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/dissect s (internal:sub _ pubsub-name)
      #/claim-unique unique-name reads db on-conflict
        "Tried to claim a name unique twice"
      #/fn reads db
      #/handle-generic-pubsub-write ds pubsub-name
        (dissectfn (db-pubsub-entry descendants pub-writes sub-writes)
          (db-pubsub-entry
            descendants
            pub-writes
            (cons (pubsub-write-entry reads func) sub-writes)))
        (dissectfn (db-pubsub-entry descendants pub-writes sub-writes)
          pub-writes)
        (fn arg
          (func arg)))
    
    #/mat process (internal:extfx-freshen ticket on-conflict then)
      (dissect (parse-ticket ticket)
        (list ticket-symbol ds wrap-fresh)
      #/expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ticket to be a ticket descending from the extfx runner's root definition space")
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/w- fresh-ticket-symbol (gensym)
      #/next-full
        (cons
          (process-entry
            reads
            (then #/wrap-fresh fresh-ticket-symbol))
          processes)
        rev-next-processes
        (hash-set unspent-tickets fresh-ticket-symbol entry)
        db rev-errors #t)
    #/mat process
      (internal:extfx-split-list ticket times on-conflict then)
      (dissect (parse-ticket ticket)
        (list ticket-symbol ds wrap-fresh)
      #/expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ticket to be a ticket descending from the extfx runner's root definition space")
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/w-loop next unspent-tickets unspent-tickets result (list)
        (expect (nat->maybe times) (just times)
          (next-full
            (cons (process-entry reads (then result)) processes)
            rev-next-processes unspent-tickets db rev-errors #t)
        #/w- fresh-ticket-symbol (gensym)
        #/next
          (hash-set unspent-tickets fresh-ticket-symbol entry)
          (cons (wrap-fresh fresh-ticket-symbol) result)))
    #/mat process
      (internal:extfx-split-table ticket times on-conflict then)
      (dissect (parse-ticket ticket)
        (list ticket-symbol ds wrap-fresh)
      #/expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ticket to be a familiarity ticket descending from the extfx runner's root definition space")
      #/dissect times (unsafe:table times)
      #/next-one-fruitful #/process-entry
        reads
        (internal:extfx-split-list
          ticket (hash-count times) on-conflict
        #/fn tickets
        #/then #/unsafe:table #/make-immutable-hash
        #/list-zip-map (hash->list times) tickets #/fn time ticket
          (dissect time (cons k #/trivial)
          #/cons k ticket)))
    #/mat process
      (internal:extfx-disburse
        ds hub-name on-cont-unspent comp-ticket)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/w- hub-unauthorized-name (authorized-name-get-name hub-name)
      #/w- on-cont-unspent
        (error-definer-or-message on-cont-unspent
          "Expected an extfx-disburse continuation to be continued")
      #/handle-generic-put unspent-tickets reads ds
        (fn db func
          (hash-update db 'disburse #/fn db-disburse
            (table-update-default db-disburse hub-unauthorized-name
              (table-empty)
              func)))
        (fn on-conflict ticket
          (extfx-finish-disburse ds hub-name on-conflict ticket))
        on-cont-unspent comp-ticket)
    #/mat process
      (extfx-finish-disburse ds hub-name on-conflict ticket)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/w- hub-unauthorized-name (authorized-name-get-name hub-name)
      #/dissect (parse-ticket ticket) (list ticket-symbol _ _)
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/w- unspent-tickets
        (expect entry
          (unspent-ticket-entry-familiarity-ticket
            _ target-ds target-n _)
          unspent-tickets
        #/hash-v-map unspent-tickets #/fn unspent-ticket
          (expect unspent-ticket
            (unspent-ticket-entry-familiarity-ticket
              on-unspent unspent-ds unspent-n disbursements)
            unspent-ticket
          #/expect
            (and
              (dspace-descends? unspent-ds ds)
              (authorized-name-subname-descends? unspent-n hub-name))
            #t
            unspent-ticket
          #/unspent-ticket-entry-familiarity-ticket
            on-unspent unspent-ds unspent-n
            (dissect ds (internal:dspace _ ds-name _)
            #/table-update-default disbursements ds-name (table-empty)
            #/fn disb-for-ds
              (table-shadow hub-unauthorized-name
                (just
                #/disbursement-entry ds hub-name target-ds target-n)
                disb-for-ds))))
      #/handle-generic-finish-put unspent-tickets reads ds
        (fn db
          (table-get hub-unauthorized-name (hash-ref db 'disburse)))
        (fn db func
          (hash-update db 'disburse #/fn db-disburse
            (table-update-default db-disburse hub-unauthorized-name
              (table-empty)
              func)))
        on-conflict
        (internal:optionally-dexed-once entry))
    #/mat process
      (internal:extfx-imburse
        ds hub-familiarity-ticket on-conflict then)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/dissect hub-familiarity-ticket
        (internal:familiarity-ticket hub-ticket-symbol _)
      #/spend-ticket
        hub-ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets hub-entry
      #/dissect hub-entry
        (unspent-ticket-entry-familiarity-ticket _ _ hub-name _)
      #/w- hub-unauthorized-name (authorized-name-get-name hub-name)
      #/handle-generic-get-next reads ds
        (fn db
          (table-get hub-unauthorized-name (hash-ref db 'disburse)))
        (fn db func
          (hash-update db 'disburse #/fn db-disburse
            (table-update-default db-disburse hub-unauthorized-name
              (table-empty)
              func)))
      #/fn reads value
      #/dissect value (list disbursed-spent-ticket entry)
      #/dissect (parse-ticket disbursed-spent-ticket)
        (list _ _ wrap-fresh)
      #/w- fresh-ticket-symbol (gensym)
      #/w- fresh-ticket (wrap-fresh fresh-ticket-symbol)
      #/next-full
        (cons (process-entry reads (then fresh-ticket)) processes)
        rev-next-processes
        (hash-set unspent-tickets fresh-ticket-symbol entry)
        db rev-errors #t)
    #/mat process
      (internal:extfx-ct-continue ticket on-conflict value)
      (dissect ticket
        (internal:continuation-ticket ticket-symbol ds then)
      #/expect (dspace-eq? root-ds ds) #t
        (next-with-error "Expected ticket to be a continuation ticket associated with the extfx runner's root definition space")
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/next-full
        (cons (process-entry reads (then value)) processes)
        rev-next-processes unspent-tickets db rev-errors #t)
    #/mat process
      (internal:extfx-ft-subname ticket key on-conflict then)
      (dissect ticket (internal:familiarity-ticket ticket-symbol ds)
      #/expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ticket to be a familiarity ticket descending from the extfx runner's root definition space")
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/dissect entry
        (unspent-ticket-entry-familiarity-ticket
          on-unspent ds n disbursements)
      #/w- fresh-ticket-symbol (gensym)
      #/w- n (authorized-name-subname key n)
      #/w- disbursements
        (table-v-map-maybe disbursements #/fn disb-for-ds
          (w- disb-for-ds
            (table-kv-map-maybe disb-for-ds #/fn entry
              (dissect entry
                (disbursement-entry
                  source-ds source-name target-ds target-name)
              #/if (authorized-name-subname-descends? n source-name)
                (just entry)
                (nothing)))
          #/if (table-empty? disb-for-ds)
            (nothing)
            (just disb-for-ds)))
      #/next-full
        (cons
          (process-entry
            reads
            (then
            #/internal:familiarity-ticket fresh-ticket-symbol ds))
          processes)
        rev-next-processes
        (hash-set unspent-tickets fresh-ticket-symbol
          (unspent-ticket-entry-familiarity-ticket
            on-unspent ds n disbursements))
        db rev-errors #t)
    #/mat process
      (internal:extfx-ft-restrict
        ticket new-ds on-conflict on-restriction-error then)
      (dissect ticket (internal:familiarity-ticket ticket-symbol ds)
      #/expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ticket to be a familiarity ticket descending from the extfx runner's root definition space")
      #/expect (dspace-descends? ds new-ds) #t
        (next-with-error-definer on-restriction-error
          "Expected ds to be a definition space descending from ticket's definition space")
      #/spend-ticket ticket-symbol reads unspent-tickets on-conflict
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/dissect entry
        (unspent-ticket-entry-familiarity-ticket
          on-unspent ds n disbursements)
      #/w- fresh-ticket-symbol (gensym)
      #/w- disbursements
        (table-v-map-maybe disbursements #/fn disb-for-ds
          (w- disb-for-ds
            (table-kv-map-maybe disb-for-ds #/fn entry
              (dissect entry
                (disbursement-entry
                  source-ds source-name target-ds target-name)
              #/if (dspace-descends? new-ds source-ds)
                (just entry)
                (nothing)))
          #/if (table-empty? disb-for-ds)
            (nothing)
            (just disb-for-ds)))
      #/next-full
        (cons
          (process-entry
            reads
            (then
            #/internal:familiarity-ticket fresh-ticket-symbol new-ds))
          processes)
        rev-next-processes
        (hash-set unspent-tickets fresh-ticket-symbol
          (unspent-ticket-entry-familiarity-ticket
            on-unspent new-ds n disbursements))
        db rev-errors #t)
    
    #/mat process
      (internal:extfx-contribute
        ds collector-familiarity-ticket contributor-name
        on-familiarity-double-spend on-cont-unspent comp)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/dissect collector-familiarity-ticket
        (internal:familiarity-ticket ticket-symbol _)
      #/spend-ticket
        ticket-symbol reads unspent-tickets
        on-familiarity-double-spend
        "Tried to spend a ticket twice"
      #/fn reads unspent-tickets entry
      #/dissect entry
        (unspent-ticket-entry-familiarity-ticket _ _ collector-name _)
      #/w- collector-name (authorized-name-get-name collector-name)
      #/w- contributor-name
        (authorized-name-get-name contributor-name)
      #/w- on-cont-unspent
        (error-definer-or-message on-cont-unspent
          "Expected an extfx-contribute continuation to be continued")
      #/handle-generic-put unspent-tickets reads ds
        (fn db func
          (hash-update db 'contribute #/fn db-contribute
            (table-update-default db-contribute collector-name
              (table-empty)
            #/fn db-contribute-for-collector
              (table-update-default db-contribute-for-collector
                contributor-name
                (table-empty)
                func))))
        (fn on-value-conflict value
          (extfx-finish-contribute
            ds collector-name contributor-name on-value-conflict
            value))
        on-cont-unspent comp)
    #/mat process
      (extfx-finish-contribute
        ds collector-name contributor-name on-value-conflict value)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/handle-generic-finish-put unspent-tickets reads ds
        (fn db
          (maybe-bind
            (table-get collector-name (hash-ref db 'contribute))
          #/fn db-contribute-for-collector
          #/table-get contributor-name db-contribute-for-collector))
        (fn db func
          (hash-update db 'contribute #/fn db-contribute
            (table-update-default db-contribute collector-name
              (table-empty)
            #/fn db-contribute-for-collector
              (table-update-default db-contribute-for-collector
                contributor-name
                (table-empty)
                func))))
        on-value-conflict value)
    #/mat process (internal:extfx-collect ds collector-name then)
      (expect (dspace-descends? root-ds ds) #t
        (next-with-error "Expected ds to be a definition space descending from the extfx runner's root definition space")
      #/dissect ds (internal:dspace _ ds-name ds-parents-list)
      #/w- ds-improper-parents (cons ds-name ds-parents-list)
      #/dissect collector-name
        (internal:authorized-name _ collector-name _)
      
      ; We check if there are any outstanding familiarity tickets for
      ; ancestors of `collector-name`, or which can access
      ; disbursements of ancestors of `collector-name`. If there are,
      ; this process is currently stalled.
      #/if
        (hash-v-any unspent-tickets
        #/expectfn
          (unspent-ticket-entry-familiarity-ticket
            on-unspent ticket-ds ticket-n disbursements)
          #f
          (w- is-this-one
            (fn ticket-ds ticket-n
              (and
                (dspace-descends? ticket-ds ds)
                (authorized-name-subname-descends?
                  ticket-n collector-name)))
          #/or (is-this-one ticket-ds ticket-n)
          #/unsafe-table-v-any-short-circuiting disbursements
          #/fn disb-for-ds
          #/unsafe-table-v-any-short-circuiting disb-for-ds
          #/dissectfn
            (disbursement-entry
              source-ds source-name target-ds target-name)
            (is-this-one target-ds target-name)))
        (next-fruitless)
      
      #/w- collector-name (authorized-name-get-name collector-name)
      #/expect (table-get collector-name (hash-ref db 'contribute))
        (just db-contribute-for-collector)
        (next-fruitless)
      #/dissect db-contribute-for-collector
        (unsafe:table db-contribute-for-collector)
      #/w- db-contribute-for-collector
        (hash->list db-contribute-for-collector)
      #/w- contributions
        (list-bind db-contribute-for-collector
        #/dissectfn
          (cons contributor-name-rep db-contribute-for-contributor)
          (w-loop next parents-to-check ds-improper-parents
            (expect parents-to-check (cons parent parents-to-check)
              (list)
            #/expect (table-get parent db-contribute-for-contributor)
              (just entry)
              (next parents-to-check)
            #/expect entry (db-put-entry-written write-reads value)
              (next parents-to-check)
              (list #/cons contributor-name-rep entry))))
      #/next-one-fruitful #/process-entry
        (list-foldl reads contributions #/fn reads entry
          (dissect entry
            (cons contributor-name-rep
            #/db-put-entry-written write-reads value)
          #/reads-union reads write-reads))
        (then #/unsafe:table #/list-map contributions #/fn entry
          (dissect entry
            (cons contributor-name-rep
            #/db-put-entry-written write-reads value)
          #/cons contributor-name-rep
          #/optionally-dexed-value value)))
    
    #/mat process (extfx-finish-run ds value)
      (expect (dspace-eq? root-ds ds) #t
        (next-with-error "Expected ds to be the extfx runner's root definition space")
      #/dissect (hash-ref db 'finish-run) (nothing)
      #/next-full
        processes rev-next-processes unspent-tickets
        (hash-set db 'finish-run (just value))
        rev-errors #t)
    
    #/error "Internal error: Expected process to be an extfx value")))