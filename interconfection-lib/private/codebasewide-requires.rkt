#lang parendown/slash reprovide

; codebasewide-requires.rkt
;
; An import list that's useful primarily for this codebase.

;   Copyright 2022 The Lathe Authors
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


#|
(for-syntax /combine-in/fallback
  (combine-in
    (only-in racket/contract/base ->)
    (only-in racket/format ~a)
    (only-in racket/list append* check-duplicates last range)
    (only-in racket/provide-transform
      make-provide-pre-transformer pre-expand-export)
    (only-in racket/struct-info extract-struct-info struct-info?)
    (only-in racket/syntax
      format-id syntax-local-eval
      
      generate-temporary)
    (only-in racket/unit rename)
    (only-in syntax/contract wrap-expr/c)
    (only-in syntax/parse
      ...+ ~! ~and ~bind ~fail ~literal ~not ~optional ~or ~or* ~parse ~seq ~var attribute define-splicing-syntax-class define-syntax-class expr expr/c id keyword nat pattern syntax-parse this-syntax
      
      str))
  racket/base)

(only-in racket/contract/base
  -> ->i </c and/c any any/c chaperone-contract? cons/c contract? contract-name contract-out flat-contract? get/build-late-neg-projection listof none/c or/c procedure-arity-includes/c recontract-out recursive-contract rename-contract unconstrained-domain->)
(only-in racket/contract/combinator
  blame-add-context coerce-chaperone-contract coerce-contract coerce-flat-contract contract-first-order-passes? make-chaperone-contract make-contract make-flat-contract raise-blame-error)
(only-in racket/contract/region invariant-assertion)
(only-in racket/list append-map range)
(only-in racket/match
  define-match-expander match match/derived match-lambda)
(only-in racket/math natural?)
(only-in racket/struct make-constructor-style-printer)
(only-in syntax/parse/define
  define-syntax-parser define-syntax-parse-rule)
|#


(for-syntax /combine-in/fallback
  (combine-in
    (only-in racket/contract/base -> any/c listof)
    (only-in racket/syntax generate-temporary)
    (only-in syntax/parse
      ~optional ~seq expr expr/c id nat str syntax-parse this-syntax)
    
    (only-in lathe-comforts dissect expect fn mat w- w-loop)
    (only-in lathe-comforts/list list-kv-map list-map))
  racket/base)

(only-in racket/contract/base
  -> ->i =/c and/c any any/c case-> cons/c contract? contract-name flat-contract? get/build-late-neg-projection hash/c list/c listof none/c or/c recontract-out rename-contract)
(only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order contract-first-order-passes? make-contract make-flat-contract raise-blame-error)
(only-in racket/generic define-generics)
(only-in racket/hash hash-union)
(only-in racket/math natural?)
(only-in syntax/parse/define define-syntax-parse-rule)

(only-in lathe-comforts
  dissect dissectfn expect expectfn fn mat w- w-loop)
(only-in lathe-comforts/hash
  hash-ref-maybe hash-set-maybe hash-v-all hash-v-any hash-v-map)
(only-in lathe-comforts/list
  list-all list-any list-bind list-foldl list-map list-zip-map nat->maybe)
(only-in lathe-comforts/match match/c)
(only-in lathe-comforts/maybe
  just just? just-value maybe? maybe-bind maybe/c maybe-map nothing
  nothing?)
(only-in lathe-comforts/string immutable-string?)
(only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-struct define-syntax-and-value-imitation-simple-struct istruct/c struct-easy tupler/c tupler-make-fn tupler-pred?-fn tupler-ref-fn)
(only-in lathe-comforts/trivial trivial trivial?)
(only-in lathe-comforts/own-contract
  ascribe-own-contract define/own-contract own-contract-out)
