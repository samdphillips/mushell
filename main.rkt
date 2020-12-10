#lang racket/base

(require racket/class
         racket/gui
         net/url
         (only-in ffi/unsafe cast _string/utf-8)
         "private/gstreamer.rkt")

(define track
  "/media/sam/reorganized/CAKE/Motorcade of Generosity/01 Comanche.mp3")

(define simple-player%
  (class object%
    (super-new)
    (field [frame #f]
           [prev-button #f]
           [play-pause-button #f]
           [next-button #f]
           [playbin #f])

    (define (build-ui!)
      (set! frame (new frame% [label "mshell"]))
      (define hpane (new horizontal-pane% [parent frame]))
      (set! prev-button
        (new button% [label "prev"] [parent hpane]))
      (set! play-pause-button
        (new button%
             [parent hpane]
             [label "play"]
             [callback (lambda (b e) (toggle-play-pause!))]))
      (set! next-button
        (new button% [label "next"] [parent hpane])))

    (define (build-player!)
      (gst_init_check)
      (set! playbin
        (gst_element_factory_make "playbin" "playbin")))

    (define (toggle-play-pause!)
      (define new-state
        (match (current-state)
          ['pause 'play]
          ['play  'pause]))
      (set-state! new-state))

    (define/public (set-state! new-state)
      (define new-gst-state
        (match new-state ['play 'GST_STATE_PLAYING] ['pause 'GST_STATE_PAUSED]))
      (gst_element_set_state playbin new-gst-state))

    (define/public (current-state)
      (define-values (status state pending-state)
        (gst_element_get_state playbin 0))
      (match state
        ['GST_STATE_READY   'pause]
        ['GST_STATE_PAUSED  'pause]
        ['GST_STATE_PLAYING 'play]))

    (define/public (set-current-track! filename)
      ;; XXX: save current state, pause, restore state
      (define url (url->string (path->url filename)))
      (g_object_set (cast playbin _GstElement _GObject)
                    "uri"
                    _string/utf-8
                    url))

    (define/public (run)
      (build-ui!)
      (build-player!)
      (send frame show #t)
      (set-state! 'pause)
      (set-current-track! track))))

(module* main #f
  (send (new simple-player%) run))

