#lang racket/base

(require (for-syntax racket/base)
         racket/class
         racket/dict)

(provide tag-tracker%)

(define tag-tracker%
  (class object%
    (super-new)
    (field [artist #f]
           [album  #f]
           [title  #f]
           [genre  #f])

    (define/public (reset!)
      (set!-values (artist album title genre) (values #f #f #f #f)))

    (define/public (update! d)
      (define-syntax (update-field! stx)
        (syntax-case stx ()
          [(_ name)
           (with-syntax ([name-s (symbol->string (syntax->datum #'name))])
             #'(let ([v (dict-ref d name-s #f)])
                 (when v (set! name v))))]))
      (update-field! artist)
      (update-field! album)
      (update-field! title)
      (update-field! genre))))

