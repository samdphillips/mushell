#lang racket/base

(require racket/class
         racket/gui
         net/url
         "private/player.rkt")

(define simple-player-ui%
  (class object%
    (super-new)
    (field [frame #f]
           [prev-button #f]
           [play-pause-button #f]
           [next-button #f]
           [track-label #f]
           [player #f])

    (define (build-ui!)
      (set! frame
        (new frame%
             [label "mshell"]
             [min-width 400]))
      (define vpane (new vertical-pane% [parent frame]))
      (define hpane (new horizontal-pane% [parent vpane]))
      (set! prev-button
        (new button%
             [label "prev"]
             [parent hpane]
             [stretchable-width #t]))
      (set! play-pause-button
        (new button%
             [parent hpane]
             [label "play"]
             [stretchable-width #t]
             [callback (lambda (b e) (toggle-play-pause!))]))
      (set! next-button
        (new button%
             [label "next"]
             [parent hpane]
             [stretchable-width #t]))
      (set! track-label
        (new message%
             [label ""]
             [auto-resize #t]
             [stretchable-width #t]
             [parent vpane])))

    (define (build-player!)
      (set! player (make-player))
      (player-subscribe! player player-state-changed-msg?
                         (lambda (msg)
                           (queue-callback
                             (lambda ()
                               (send this on-player-state-change msg)))))
      (player-subscribe! player player-tags-msg?
                         (lambda (msg)
                           (queue-callback
                             (lambda () (send this on-player-tags msg))))))

    (define (toggle-play-pause!)
      (define new-state
        (match (current-state)
          ['pause 'play]
          ['play  'pause]))
      (set-state! new-state))

    (define/public (set-state! new-state)
      (set-player-state! player new-state))

    (define/public (current-state)
      (player-state player))

    (define/public (set-current-track! filename)
      (set-player-track! player (path->url filename)))

    (define (set-play-pause-label! s)
      (send play-pause-button set-label s))

    (define (set-track-label! s)
      (send track-label set-label s))

    (define/public (on-player-state-change e)
      (match e
        [(player-state-changed-msg _ 'GST_STATE_PAUSED 'GST_STATE_PLAYING _)
         (set-play-pause-label! "pause")]
        [(player-state-changed-msg _ 'GST_STATE_PLAYING 'GST_STATE_PAUSED _)
         (set-play-pause-label! "play")]
        [_ (void)]))

    (define/public (on-player-tags e)
      (set-track-label! (~a (player-tags-msg-tags e))))

    (define/public (run track)
      (build-ui!)
      (build-player!)
      (send frame show #t)
      (set-state! 'pause)
      (set-current-track! track))))

(module* main #f
  (define track
    (vector-ref (current-command-line-arguments) 0))
  (send (new simple-player-ui%) run track))

