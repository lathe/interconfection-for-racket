#lang parendown racket/base

; interconfection/order
;
; Operations for order-invariant programming.

;   Copyright 2017-2020 The Lathe Authors
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


(require #/only-in racket/contract/base -> any/c)
(require #/only-in racket/contract/region define/contract)

(require #/only-in lathe-comforts expect fn)
(require #/only-in lathe-comforts/maybe just nothing)
(require #/only-in lathe-comforts/string immutable-string?)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial?)

(require interconfection/order/base)
(require #/submod interconfection/order/base private/order)
(require #/only-in (submod interconfection/order/base private)
  define-datum-cline define-datum-dex)
(require #/only-in interconfection/private/getfx getfx-done)
(require #/only-in interconfection/private/order
  exact-rational?)
(require #/prefix-in internal: #/only-in interconfection/order/unsafe
  fuse gen:furge-internals)

(provide #/all-from-out interconfection/order/base)
(provide #/all-from-out #/submod interconfection/order/base
  private/order)

(provide
  dex-trivial
  dex-immutable-string
  cline-immutable-string
  dex-exact-rational
  cline-exact-rational
  fuse-exact-rational-by-plus
  fuse-exact-rational-by-times)


(define-datum-dex
  dex-internals-trivial dex-trivial tag:dex-trivial name:trivial
  trivial? (fn x 'trivial) (fn a b #f))

(define-datum-cline
  dex-internals-immutable-string dex-immutable-string
  tag:dex-immutable-string
  cline-internals-immutable-string cline-immutable-string
  tag:cline-immutable-string
  name:immutable-string immutable-string? string->symbol string<?)

(define-datum-cline
  dex-internals-exact-rational dex-exact-rational
  tag:dex-exact-rational
  cline-internals-exact-rational cline-exact-rational
  tag:cline-exact-rational
  name:exact-rational exact-rational? (fn x x) <)


(struct-easy (fuse-internals-exact-rational-by-plus)
  #:other
  
  #:methods internal:gen:furge-internals
  [
    
    (define (furge-internals-tag this)
      'tag:fuse-exact-rational-by-plus)
    
    (define (furge-internals-autoname this)
      'tag:fuse-exact-rational-by-plus)
    
    (define (furge-internals-autodex this other)
      (just #/ordering-eq))
    
    (define (getfx-furge-internals-call this a b)
      (getfx-done
        (expect (exact-rational? a) #t (nothing)
        #/expect (exact-rational? b) #t (nothing)
        #/just #/+ a b)))
  ])

(define/contract (fuse-exact-rational-by-plus)
  (-> fuse?)
  (internal:fuse #/fuse-internals-exact-rational-by-plus))


(struct-easy (fuse-internals-exact-rational-by-times)
  #:other
  
  #:methods internal:gen:furge-internals
  [
    
    (define (furge-internals-tag this)
      'tag:fuse-exact-rational-by-times)
    
    (define (furge-internals-autoname this)
      'tag:fuse-exact-rational-by-times)
    
    (define (furge-internals-autodex this other)
      (just #/ordering-eq))
    
    (define (getfx-furge-internals-call this a b)
      (getfx-done
        (expect (exact-rational? a) #t (nothing)
        #/expect (exact-rational? b) #t (nothing)
        #/just #/* a b)))
  ])

(define/contract (fuse-exact-rational-by-times)
  (-> fuse?)
  (internal:fuse #/fuse-internals-exact-rational-by-times))
