#lang racket/base

(require racket/class
         racket/stream)

(module+ test
  (require rackunit))

(define songlist%
  (class object%
    (init [source null])
    (field [current #f]
           [up-next-queue null]
           [future-queue  source]
           [history       null])

    (define/public (empty?)
      (and (not current)
           (null? up-next-queue)
           (stream-empty? future-queue)))

    (define/public (get-current) current)

    (define (changed!)
      ;; trigger change announcments
      (void))

    (define/public (next!)
      (cond
        [(not (null? up-next-queue))
         (set! current (car up-next-queue))
         (set! up-next-queue (cdr up-next-queue))]
        [(not (stream-empty? future-queue))
         (set! current (stream-first future-queue))
         (set! future-queue (stream-rest future-queue))]
        [else
          (set! current #f)]))

    (define/public (queue-next! song)
      (set! up-next-queue (cons song up-next-queue)))

    (super-new)
    (unless (stream-empty? future-queue)
      (next!))))

(module+ test
  (check-true (send (new songlist%) empty?))
  (let ([s (new songlist% [source '(a b c d)])])
    (check-equal? (send s get-current) 'a)
    (check-equal? (send* s (next!) (get-current)) 'b)
    (check-equal? (send* s (next!) (get-current)) 'c)
    (check-equal? (send* s (next!) (get-current)) 'd)
    (check-true   (send* s (next!) (empty?)))))

