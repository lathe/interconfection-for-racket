#lang parendown/slash reprovide

; codebasewide-requires.rkt
;
; An import list that's useful primarily for this codebase.

;   Copyright 2022, 2025 The Lathe Authors
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
  -> ->i =/c any any/c case-> cons/c contract? contract-name flat-contract? get/build-late-neg-projection list/c listof none/c or/c recontract-out rename-contract)
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
