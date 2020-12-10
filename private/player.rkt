#lang racket/base

(require racket/match
         racket/place
         net/url
         ffi/unsafe
         ffi/unsafe/port
         "gstreamer.rkt")

(provide make-player
         player-message-evt
         player-state
         set-player-state!
         set-player-track!)

(struct player [gst-element])

(define (make-player)
  (unless gst_init?
    (gst_init_check))
  (define playbin (gst_element_factory_make "playbin" #f))
  (player playbin))

(define (gst-message->player-message msg)
  (GstMessage-type msg))

(define (player-message-evt ply)
  (guard-evt
    (lambda ()
      (define bus
        (gst_element_get_bus
          (player-gst-element ply)))
      (handle-evt
        (unsafe-fd->evt (gst_bus_get_pollfd bus) 'read)
        (lambda (e)
          (define msg
            (gst_bus_pop bus))
          (cond
            [msg (define new-msg (gst-message->player-message msg))
                 (gst_message_unref msg)
                 new-msg]
            [else #f]))))))

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

