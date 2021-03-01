#lang racket/base

(require racket/class
         racket/gui
         net/url
         pict
         "private/player.rkt"
         "private/songlist.rkt"
         "private/tag-tracker.rkt"
         "private/track-info.rkt")

(define simple-player-ui%
  (class object%
    (super-new)
    (field [frame #f]
           [prev-button #f]
           [play-pause-button #f]
           [next-button #f]
           [track-info-canvas #f]
           [track-info  #f]
           [tag-tracker (new tag-tracker%)]
           [songlist #f]
           [player #f])

    (define (build-ui!)
      (set! frame
        (new frame%
             [label "mushell"]
             [min-width 600]))
      (define vpane (new vertical-pane% [parent frame]))
      (define hpane (new horizontal-pane% [parent vpane]))
      (set! prev-button
        (new button%
             [parent hpane]
             [label "prev"]
             [stretchable-width #t]
             [callback (lambda (b e) (on-prev-button))]))
      (set! play-pause-button
        (new button%
             [parent hpane]
             [label "play"]
             [stretchable-width #t]
             [callback (lambda (b e) (toggle-play-pause!))]))
      (set! next-button
        (new button%
             [parent hpane]
             [label "next"]
             [stretchable-width #t]
             [callback (lambda (b e) (on-next-button))]))
      (set! track-info-canvas
        (new canvas%
             [parent vpane]
             [paint-callback
               (lambda (canvas dc) (send this paint-track-info-canvas dc))]
             [min-width 600]
             [min-height 100])))

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
                             (lambda () (send this on-player-tags msg)))))
      (player-subscribe! player player-eos-msg?
                         (lambda (msg)
                           (queue-callback
                             (lambda () (send this on-next-button))))))

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
      (send tag-tracker reset!)
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
      (send tag-tracker update! (player-tags-msg-tags e))
      (set! track-info (render-track-info (send songlist get-current) tag-tracker))
      (send track-info-canvas refresh))

    (define/public (paint-track-info-canvas dc)
      (when track-info
        (draw-pict track-info dc 0 0)))

    (define/public (on-prev-button)
      ;; XXX: just reset the current track for now
      (define prev-state (current-state))
      (set-state! 'null)
      (set-state! prev-state))

    (define/public (on-next-button)
      (define prev-state (current-state))
      ;; This next line causes the player to reset and flush the current
      ;; pipeline
      (set-state! 'null)
      (send songlist next!)
      (send tag-tracker reset!)
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
  (define (audio-file-name? fn)
    (match (path-get-extension fn)
      [(or #".ogg" #".mp3" #".m4a") #t]
      [_ #f]))
  (define tracks
    (values
      (for*/list ([base-dir (in-vector (current-command-line-arguments))]
                  [filename (in-directory base-dir)]
                  #:when (audio-file-name? filename))
        filename)))
  (define songlist
    (new songlist% [source tracks]))
  (send (new simple-player-ui%) run songlist))

