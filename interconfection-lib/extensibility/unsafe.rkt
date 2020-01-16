#lang parendown racket/base

; interconfection/extensibility/unsafe
;
; Unsafe operations for extensibility side effects.

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


(require #/only-in racket/contract/base recontract-out)

(require #/submod interconfection/extensibility/base private/unsafe)

; TODO: See if we can use something more like this at some point. For
; now, `recontract-out` can't be combined with `all-from-out`.
#;
(provide #/all-from-out
  (submod interconfection/extensibility/base private/unsafe))

(provide #/recontract-out
  run-extfx-result-success?
  run-extfx-result-success-value)
(provide
  run-extfx-result-success)
(provide #/recontract-out
  run-extfx-result-failure?
  run-extfx-result-failure-errors)
(provide
  run-extfx-result-failure)
(provide #/recontract-out
  run-extfx!)
