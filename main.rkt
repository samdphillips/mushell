#lang racket/base

(require racket/class
         racket/gui
         net/url
         "private/player.rkt"
         "private/songlist.rkt")

(define simple-player-ui%
  (class object%
    (super-new)
    (field [frame #f]
           [prev-button #f]
           [play-pause-button #f]
           [next-button #f]
           [track-label #f]
           [songlist #f]
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
             [stretchable-width #t]
             [callback (lambda (b e) (on-next-button))]))
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
      (set-track-label! (~a filename))
      (set-player-track! player (path->url filename)))

    (define (set-play-pause-label! s)
      (send play-pause-button set-label s))

    (define (set-track-label! s)
      (send track-label set-label s))

    (define/public (on-player-state-change e)
      (displayln e)
      (match e
        [(player-state-changed-msg _ 'GST_STATE_PAUSED 'GST_STATE_PLAYING _)
         (set-play-pause-label! "pause")]
        [(player-state-changed-msg _ 'GST_STATE_PLAYING 'GST_STATE_PAUSED _)
         (set-play-pause-label! "play")]
        [_ (void)]))

    (define/public (on-player-tags e)
      (set-track-label!
        (apply ~a #:separator "\n"
               (send songlist get-current)
               (for/list ([(k v) (in-hash (player-tags-msg-tags e))])
                 (~a k ": " v)))))

    (define/public (on-next-button)
      (define prev-state (current-state))
      ;; This next line causes the player to reset and flush the current
      ;; pipeline
      (set-state! 'null)
      (send songlist next!)
      (set-current-track! (send songlist get-current))
      (set-state! prev-state))

    (define/public (run a-songlist)
      (build-ui!)
      (build-player!)
      (set! songlist a-songlist)
      (send frame show #t)
      (set-state! 'pause)
      (set-current-track! (send songlist get-current)))))

(module* main #f
  (define base-dir (vector-ref (current-command-line-arguments) 0))
  (define (audio-file-name? fn)
    (match (path-get-extension fn)
      [(or #".ogg" #".mp3" #".m4a") #t]
      [_ #f]))
  (define tracks
    (shuffle
      (for/list ([filename (in-directory base-dir)]
                 #:when (audio-file-name? filename))
        filename)))
  (define songlist
    (new songlist% [source tracks]))
  (send (new simple-player-ui%) run songlist))

