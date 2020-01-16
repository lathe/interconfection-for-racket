#lang parendown racket/base

; interconfection/tests
;
; Unit tests of Interconfection.

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


(require rackunit)

(require #/only-in lathe-comforts expect fn w-)
(require #/only-in lathe-comforts/maybe just just-value)
(require #/only-in lathe-comforts/struct struct-easy)

(require interconfection/extensibility/base)
(require interconfection/order)

; (We provide nothing from this module.)


(struct-easy (mk-just1)
  #:other
  
  #:property prop:procedure
  (fn this result
    (expect this (mk-just1)
      (error "Expected this to be a mk-just1")
    #/getfx-done #/just result))
)
(struct-easy (mk-just2)
  #:other
  
  #:property prop:procedure
  (fn this result
    (expect this (mk-just2)
      (error "Expected this to be a mk-just2")
    #/getfx-done #/just result))
)


(check-exn
  exn:fail:contract?
  (fn
    (pure-run-getfx #/getfx-compare-by-dex
      ; This dex compares any dex which has itself in its domain. The
      ; method of comparison (the dex) is obtained from the value by
      ; doing nothing; the method is the value.
      (dex-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just1) #/mk-just1)))
      
      ; These two values are dexes, and they are each in their own
      ; domain, but they're different dexes. When they're compared,
      ; it will not be possible to decide upon a single method of
      ; comparison, so a dynamic error will be raised.
      (dex-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just1) #/mk-just1)))
      (dex-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just2) #/mk-just2)))))
  "Calling a `dex-by-own-method` on two values with different methods raises an error")

(check-exn
  exn:fail?
  (fn
    (pure-run-getfx #/getfx-compare-by-cline
      ; This cline compares any cline which has itself in its domain.
      ; The method of comparison (the cline) is obtained from the
      ; value by doing nothing; the method is the value.
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just1) #/mk-just1)))
      
      ; These two values are clines, and they are each in their own
      ; domain, but they're different clines. When they're compared,
      ; it will not be possible to decide upon a single method of
      ; comparison, so a dynamic error will be raised.
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just1) #/mk-just1)))
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-struct mk-just2) #/mk-just2)))))
  "Calling a `cline-by-own-method` on two values with different methods raises an error")


; TODO: We can no longer test with actual `nothing` and `just` values
; from Lathe Comforts because those identifiers don't carry struct
; information anymore. We should make a `dex-match` to test those
; with, and until we do, we test using these actual structs instead.
(struct-easy (s-nothing) #:equal)
(struct-easy (s-just value) #:equal)

(define (dex-maybe dex-elem)
  (dex-default (dex-struct s-nothing) (dex-struct s-just dex-elem)))

(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex (dex-name)
    (just-value #/pure-run-getfx
      (getfx-name-of (dex-struct s-nothing) (s-nothing)))
    (just-value #/pure-run-getfx
      (getfx-name-of (dex-maybe dex-give-up) (s-nothing))))
  (just #/ordering-eq)
  "Using `getfx-name-of` with different dexes gives the same name")


(struct-easy (custom-pair a b))

(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex
    (dex-struct-by-field-position custom-pair
      [0 (dex-dex)]
      [1 (dex-cline)])
    (custom-pair (dex-give-up) (cline-give-up))
    (custom-pair (dex-give-up) (cline-give-up)))
  (just #/ordering-eq)
  "Specifying fields in order with `dex-struct-by-field-position` works")
(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex
    (dex-struct-by-field-position custom-pair
      [1 (dex-cline)]
      [0 (dex-dex)])
    (custom-pair (dex-give-up) (cline-give-up))
    (custom-pair (dex-give-up) (cline-give-up)))
  (just #/ordering-eq)
  "Specifying fields out of order with `dex-struct-by-field-position` works")

(check-equal?
  (w- name
    (just-value #/pure-run-getfx #/getfx-name-of (dex-dex)
    #/dex-struct-by-field-position custom-pair
      [1 (dex-cline)]
      [0 (dex-dex)])
    (pure-run-getfx #/getfx-compare-by-dex (dex-name) name name))
  (just #/ordering-eq)
  "Names that internally contain structure type descriptors and exact nonnegative integers can be compared")