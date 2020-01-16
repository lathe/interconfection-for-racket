#lang info

(define collection "interconfection")

(define deps (list "base"))
(define build-deps
  (list
    "interconfection-lib"
    "lathe-comforts-doc"
    "lathe-comforts-lib"
    "parendown-lib"
    "racket-doc"
    "scribble-lib"))

(define scribblings
  (list (list "scribblings/interconfection.scrbl" (list))))
