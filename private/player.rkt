#lang racket/base

(require racket/match
         net/url
         ffi/unsafe
         "gstreamer.rkt")

(provide make-player
         player-state
         set-player-state!
         set-player-track!)

(struct player
  [gst-element
    ])

(define (make-player)
  (unless gst_init?
    (gst_init_check))
  (player (gst_element_factory_make "playbin" #f)))

(define (player-state ply)
  (define-values (status state pending-state)
    (gst_element_get_state (player-gst-element ply) 0))
  (match state
    ['GST_STATE_READY   'pause]
    ['GST_STATE_PAUSED  'pause]
    ['GST_STATE_PLAYING 'play]))

(define (set-player-state! ply new-state)
  (define new-gst-state
    (match new-state ['play 'GST_STATE_PLAYING] ['pause 'GST_STATE_PAUSED]))
  (gst_element_set_state (player-gst-element ply) new-gst-state))

(define (set-player-track! ply url)
  ;; XXX: save current state, pause, restore state
  (g_object_set (cast (player-gst-element ply) _GstElement _GObject)
                "uri" _string/utf-8 (url->string url)))

