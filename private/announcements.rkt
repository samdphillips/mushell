#lang racket/base

(provide make-announcer
         announcer?
         announcer-add-subscription!
         announcer-announce
         (struct-out subscription))

;; TODO: unsubscribing from announcements
;; TODO: announcements handle on different threads better

(struct announcer [(subscriptions #:mutable)])

(struct subscription [priority target selector action])

(define (make-announcer)
  (announcer null))

;; XXX: could make some prettier ways of doing this
(define (announcer-add-subscription! ann sub)
  (define cur-subs (announcer-subscriptions ann))
  (define subs
    (sort (cons sub cur-subs) > #:key subscription-priority))
  (set-announcer-subscriptions! ann subs))

(define (subscription-interested? sub val)
  (define select? (subscription-selector sub))
  (select? val))

(define (subscription-notify sub val)
  (define action (subscription-action sub))
  (action val))

(define (announcer-announce ann val)
  (for ([s (in-list (announcer-subscriptions ann))]
        #:when (subscription-interested? s val))
    (subscription-notify s val)))


