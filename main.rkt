#lang racket/base

(require racket/class
         racket/gui
         net/url
         "private/player.rkt")

(define track
  "/media/sam/reorganized/CAKE/Motorcade of Generosity/01 Comanche.mp3")

(define simple-player-ui%
  (class object%
    (super-new)
    (field [frame #f]
           [prev-button #f]
           [play-pause-button #f]
           [next-button #f]
           [player #f])

    (define (build-ui!)
      (set! frame (new frame% [label "mshell"]))
      (define hpane (new horizontal-pane% [parent frame]))
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
             [stretchable-width #t])))

    (define (build-player!)
      (set! player (make-player)))

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

    (define/public (on-player-state-change e)
      (match e
        [(player-state-changed-msg _ 'GST_STATE_PAUSED 'GST_STATE_PLAYING _)
         (set-play-pause-label! "pause")]
        [(player-state-changed-msg _ 'GST_STATE_PLAYING 'GST_STATE_PAUSED _)
         (set-play-pause-label! "play")]
        [_ (void)]))

    (define/public (on-player-tags e)
      (void))

    (define/public (on-player-event e)
      (match e
        [(? player-state-changed-msg?) (on-player-state-change e)]
        [(? player-tags-msg?)          (on-player-tags e)]
        [_ (void)]))

    (define (player-evt-handler)
      (define e (sync (player-message-evt player)))
      (queue-callback
        (lambda ()
          (send this on-player-event e)))
      (player-evt-handler))

    (define/public (run)
      (build-ui!)
      (build-player!)
      (send frame show #t)
      (set-state! 'pause)
      (set-current-track! track)
      (void (thread player-evt-handler)))))

(module* main #f
  (send (new simple-player-ui%) run))

