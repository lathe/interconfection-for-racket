#lang parendown racket/base

; interconfection/private/order-unsafe
;
; Private, unsafe operations for order-invariant programming.

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


(require #/only-in racket/generic define-generics)

(require #/only-in lathe-comforts expect fn)
(require #/only-in lathe-comforts/struct
  auto-write define-imitation-simple-struct struct-easy)


(provide #/struct-out name)
(provide
  gen:dex-internals
  dex-internals?
  dex-internals-tag
  dex-internals-autoname
  dex-internals-autodex
  getfx-dex-internals-is-in
  getfx-dex-internals-name-of
  getfx-dex-internals-dexed-of
  getfx-dex-internals-compare)
(provide #/struct-out dex)

(provide
  gen:cline-internals
  cline-internals?
  cline-internals-tag
  cline-internals-autoname
  cline-internals-autodex
  cline-internals-dex
  getfx-cline-internals-is-in
  getfx-cline-internals-compare)
(provide #/struct-out cline)

(provide
  gen:furge-internals
  furge-internals?
  furge-internals-tag
  furge-internals-autoname
  furge-internals-autodex
  getfx-furge-internals-call)
(provide #/struct-out merge)
(provide #/struct-out fuse)

(provide
  table?
  table-hash
  table
  table-entry?
  table-entry-key
  table-entry-value
  table-entry)

(provide #/struct-out fusable-function)



; ===== Names, dexes, and dexed values ===============================

; Internally, we represent name values as data made of structure type
; descriptors, uninterned symbols, exact rational numbers, interned
; symbols, empty lists, and cons cells. For sorting purposes, we
; consider them to ascend in that order.
;
; This is the struct type we "encapsulate" that in, but we offer it as
; an unsafe export.
;
(struct-easy (name rep)
  #:error-message-phrase "a name")

(define-generics dex-internals
  (dex-internals-tag dex-internals)
  (dex-internals-autoname dex-internals)
  (dex-internals-autodex dex-internals other)
  (getfx-dex-internals-is-in dex-internals x)
  (getfx-dex-internals-name-of dex-internals x)
  (getfx-dex-internals-dexed-of dex-internals x)
  (getfx-dex-internals-compare dex-internals a b))

(struct-easy (dex internals))


; ===== Clines =======================================================

(define-generics cline-internals
  (cline-internals-tag cline-internals)
  (cline-internals-autoname cline-internals)
  (cline-internals-autodex cline-internals other)
  (cline-internals-dex cline-internals)
  (getfx-cline-internals-is-in cline-internals x)
  (getfx-cline-internals-compare cline-internals a b))

(struct-easy (cline internals))


; ===== Merges and fuses =============================================

(define-generics furge-internals
  (furge-internals-tag furge-internals)
  (furge-internals-autoname furge-internals)
  (furge-internals-autodex furge-internals other)
  (getfx-furge-internals-call furge-internals a b))

(struct-easy (merge internals))
(struct-easy (fuse internals))


; ===== Tables =======================================================

(define-imitation-simple-struct
  (table? table-hash)
  table
  'table (current-inspector) (auto-write))

(define-imitation-simple-struct
  (table-entry? table-entry-key table-entry-value)
  table-entry
  'table-entry (current-inspector) (auto-write))


; ===== Fusable functions ============================================

(struct-easy (fusable-function proc)
  #:other
  
  #:property prop:procedure
  (fn this arg
    (expect this (fusable-function proc)
      (error "Expected this to be a fusable-function")
    #/proc arg)))
