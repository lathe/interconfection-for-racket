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
(require #/only-in lathe-comforts/struct
  auto-equal auto-write
  define-syntax-and-value-imitation-simple-struct)

(require interconfection/extensibility/base)
(require interconfection/order)

; (We provide nothing from this module.)


(define-syntax-and-value-imitation-simple-struct
  (mk-just1?) mk-just1 mk-just1/t
  'mk-just1 (current-inspector) (auto-write)
  (#:prop prop:procedure #/fn this result
    (expect this (mk-just1)
      (error "Expected this to be a mk-just1")
    #/getfx-done #/just result)))
(define-syntax-and-value-imitation-simple-struct
  (mk-just2?) mk-just2 mk-just2/t
  'mk-just2 (current-inspector) (auto-write)
  (#:prop prop:procedure #/fn this result
    (expect this (mk-just2)
      (error "Expected this to be a mk-just2")
    #/getfx-done #/just result)))


(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex
    ; This dex compares any dex which has itself in its domain. The
    ; method of comparison (the dex) is obtained from the value by
    ; doing nothing; the method is the value.
    (dex-by-own-method
      (just-value #/pure-run-getfx
        (getfx-dexed-of (dex-tuple mk-just1/t) #/mk-just1)))
    
    ; These two values are dexes, and they are each in their own
    ; domain, but they're different dexes. When they're compared, it
    ; will not be possible to decide upon a single method of
    ; comparison, but the fact that the comparison methods are
    ; different will mean we know the values that produced them are
    ; different anyway.
    (dex-by-own-method
      (just-value #/pure-run-getfx
        (getfx-dexed-of (dex-tuple mk-just1/t) #/mk-just1)))
    (dex-by-own-method
      (just-value #/pure-run-getfx
        (getfx-dexed-of (dex-tuple mk-just2/t) #/mk-just2))))
  (just #/ordering-private)
  "Calling a `dex-by-own-method` on two values with different methods successfully distinguishes them")

(check-exn
  exn:fail?
  (fn
    (pure-run-getfx #/getfx-compare-by-cline
      ; This cline compares any cline which has itself in its domain.
      ; The method of comparison (the cline) is obtained from the
      ; value by doing nothing; the method is the value.
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-tuple mk-just1/t) #/mk-just1)))
      
      ; These two values are clines, and they are each in their own
      ; domain, but they're different clines. When they're compared,
      ; it will not be possible to decide upon a single method of
      ; comparison, so a dynamic error will be raised.
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-tuple mk-just1/t) #/mk-just1)))
      (cline-by-own-method
        (just-value #/pure-run-getfx
          (getfx-dexed-of (dex-tuple mk-just2/t) #/mk-just2)))))
  "Calling a `cline-by-own-method` on two values with different methods raises an error")


; TODO: We can't test with the `nothing` and `just` values from
; Lathe Comforts because those don't have tuplers. See if we should
; have Lathe Comforts define their tuplers.
(define-syntax-and-value-imitation-simple-struct
  (s-nothing?) s-nothing s-nothing/t
  's-nothing (current-inspector) (auto-equal) (auto-write))
(define-syntax-and-value-imitation-simple-struct
  (s-just? s-just-value) s-just s-just/t
  's-just (current-inspector) (auto-equal) (auto-write))

(define (dex-maybe dex-elem)
  (dex-default (dex-tuple s-nothing/t) (dex-tuple s-just/t dex-elem)))

(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex (dex-name)
    (just-value #/pure-run-getfx
      (getfx-name-of (dex-tuple s-nothing/t) (s-nothing)))
    (just-value #/pure-run-getfx
      (getfx-name-of (dex-maybe dex-give-up) (s-nothing))))
  (just #/ordering-eq)
  "Using `getfx-name-of` with different dexes gives the same name")


(define-syntax-and-value-imitation-simple-struct
  (custom-pair? custom-pair-a custom-pair-b)
  custom-pair custom-pair/t
  'custom-pair (current-inspector) (auto-write))

(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex
    (dex-tuple-by-field-position custom-pair/t
      [0 (dex-dex)]
      [1 (dex-cline)])
    (custom-pair (dex-give-up) (cline-give-up))
    (custom-pair (dex-give-up) (cline-give-up)))
  (just #/ordering-eq)
  "Specifying fields in order with `dex-tuple-by-field-position` works")
(check-equal?
  (pure-run-getfx #/getfx-compare-by-dex
    (dex-tuple-by-field-position custom-pair/t
      [1 (dex-cline)]
      [0 (dex-dex)])
    (custom-pair (dex-give-up) (cline-give-up))
    (custom-pair (dex-give-up) (cline-give-up)))
  (just #/ordering-eq)
  "Specifying fields out of order with `dex-tuple-by-field-position` works")

(check-equal?
  (w- name
    (just-value #/pure-run-getfx #/getfx-name-of (dex-dex)
    #/dex-tuple-by-field-position custom-pair/t
      [1 (dex-cline)]
      [0 (dex-dex)])
    (pure-run-getfx #/getfx-compare-by-dex (dex-name) name name))
  (just #/ordering-eq)
  "Names that internally contain structure type descriptors and exact nonnegative integers can be compared")
