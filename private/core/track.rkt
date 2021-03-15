#lang racket/base

(require racket/contract
         net/url)

(provide make-track
         track-id/string
         track-location/string
         track-tags)

(struct track (id location tags) #:transparent)

(define (derive-id fname tags)
  (if (hash-has-key? tags "musicbrainz-releasetrackid")
      (string->url
        (string-append
          "http://musicbrainz.org/track/"
          (hash-ref tags "musicbrainz-releasetrackid")))
      fname))

(define (make-track fname tags)
  (track (derive-id fname tags)
         fname
         tags))

(define (track-id/string tr)
  (url->string (track-id tr)))

(define (track-location/string tr)
  (url->string (track-location tr)))

