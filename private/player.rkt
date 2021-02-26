#lang racket/base

(require racket/match
         racket/place
         net/url
         ffi/unsafe
         ffi/unsafe/port
         "announcements.rkt"
         "gstreamer.rkt")

(provide make-player
         player-subscribe!
         player-state
         set-player-state!
         set-player-track!

         player-msg?
         player-msg-timestamp
         (struct-out player-state-changed-msg)
         (struct-out player-tags-msg))

(struct player [gst-element announcer bus-thread])

(define (make-player)
  (unless gst_init?
    (gst_init_check))
  (define playbin (gst_element_factory_make "playbin" #f))
  (define bus-thread (thread (lambda () (run-bus-thread ply))))
  (define ply (player playbin (make-announcer) bus-thread))
  ply)

(struct player-msg (timestamp) #:transparent)
(struct player-state-changed-msg player-msg (old new pending) #:transparent)
(struct player-tags-msg player-msg (tags) #:transparent)

(define (gst-message->player-message msg)
  (match (GstMessage-type msg)
    ['GST_MESSAGE_STATE_CHANGED
     ;; XXX: should these state values be converted from GST values?
     (define-values (old new pending) (gst_message_parse_state_changed msg))
     (player-state-changed-msg (GstMessage-timestamp msg) old new pending)]
    ['GST_MESSAGE_TAG
     (player-tags-msg (GstMessage-timestamp msg) (convert-gst-tags-message msg))]
    [x x]))

;; For now we'll just deal with this set of string valued tags
(define player-tags
  '("album" "artist" "genre" "title"))

(define (convert-gst-tags-message msg)
  (define taglist (gst_message_parse_tag msg))
  (dynamic-wind
    void
    (lambda ()
      (for/hash ([tag (in-list player-tags)])
        (values tag (gst_tag_list_get_string taglist tag))))
    (lambda ()
      (gst_tag_list_unref taglist))))

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

(define (run-bus-thread ply)
  (sync
    (handle-evt (player-message-evt ply)
      (lambda (msg)
        (announcer-announce (player-announcer ply) msg)
        (run-bus-thread ply)))))

(define (player-subscribe! ply selector action)
  (define sub (subscription 50 #f selector action))
  (announcer-add-subscription! (player-announcer ply) sub))

(define (player-state ply)
  (define-values (status state pending-state)
    (gst_element_get_state (player-gst-element ply) 0))
  (match state
    ['GST_STATE_NULL    'pause]
    ['GST_STATE_READY   'pause]
    ['GST_STATE_PAUSED  'pause]
    ['GST_STATE_PLAYING 'play]))

(define (set-player-state! ply new-state)
  (define new-gst-state
    (match new-state
      ['play 'GST_STATE_PLAYING]
      ['pause 'GST_STATE_PAUSED]
      ['null 'GST_STATE_NULL]))
  (gst_element_set_state (player-gst-element ply) new-gst-state))

(define (set-player-track! ply url)
  ;; XXX: save current state, pause, restore state
  (g_object_set (cast (player-gst-element ply) _GstElement _GObject)
                "uri" _string/utf-8 (url->string url)))

