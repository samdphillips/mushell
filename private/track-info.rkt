#lang racket/base

(require racket/class
         racket/format
         racket/match
         racket/path
         pict)

(provide render-track-info)

(define cover-art-size 75)

(define (containing-directory path)
  (simple-form-path (build-path path 'up)))

(define (image-name? fname)
  (match (path-get-extension fname)
    [(or #".jpg" #".png") #t]
    [_ #f]))

(define (find-cover-art album-dir)
  (define (sort-candidates f*)
    (sort f* < #:key file-size))
  (define candidates
    (sort-candidates
     (for/list ([fname (directory-list album-dir)]
                #:when (image-name? fname))
       (build-path album-dir fname))))
  (cond
    [(null? candidates) #f]
    [else (car candidates)]))

(define cover-art-cache (make-hash))

(define (cover-art fname)
  (define (generate-pict)
    (if fname
        (scale-to-fit (bitmap fname)
                      cover-art-size cover-art-size
                      #:mode 'inset)
        (colorize
         (filled-rectangle cover-art-size cover-art-size) "gray")))
  (hash-ref! cover-art-cache fname generate-pict))

(define (render-track-info fname tc)
  (define (~b v) (if v v ""))
  (lc-superimpose (blank 600 (+ 20 cover-art-size))
                  (hc-append
                   5.0
                   (blank 5 cover-art-size)
                   (cover-art
                    (find-cover-art
                     (containing-directory fname)))
                   (vl-append
                    (hb-append (text "Title: " null 14)
                               (text (~b (get-field title tc))
                                     (list 'bold) 14))
                    (hb-append (text "Artist: " null 14)
                               (text (~b (get-field artist tc))
                                     (list 'bold) 14))
                    (hb-append (text "Album: " null 14)
                               (text (~b (get-field album tc))
                                     (list 'bold) 14))
                    (hb-append (text "Genre: " null 10)
                               (text (~b (get-field genre tc))
                                     (list 'bold) 10))
                    (text (~a fname) null 10)))))

