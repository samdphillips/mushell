#lang racket/base

(require racket/class
         framework)

(provide shell%)

(define (apply-mixins % . mxs)
  (for/fold ([% %]) ([mx (in-list mxs)])
    (mx %)))

(define repl:text%
  (apply-mixins text:basic%
                editor:standard-style-list-mixin
                text:wide-snip-mixin
                text:ports-mixin))

(define shell%
  (class object%
    (super-new)
    (init parent min-height)

    (define repl-text
      (new repl:text%))

    (define editor-canvas
      (new canvas:basic%
           [parent parent]
           [min-height min-height]
           [editor repl-text]))

    (send editor-canvas focus)
    ))
