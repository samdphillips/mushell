#lang racket/base

(require db
         sql
         "track.rkt")

(provide db-track-should-rescan?
         db-add-track!
         #;db-update-track!)

(define (create-schema dbc)
  (query-exec dbc
    (create-table #:if-not-exists tracks
      #:columns
      [id text]
      [location text]
      [last_file_scan integer #:default 0]
      [last_mb_scan integer #:default 0]
      #:constraints
      (unique location)
      (primary-key id)))
  (query-exec dbc
    (create-table #:if-not-exists tags
      #:columns
      [id integer]
      [name text]
      [value text]
      #:constraints
      (primary-key id)
      (unique name value)))
  ;; XXX: foreign key constraints?
  (query-exec dbc
    (create-table #:if-not-exists track_tag
      #:columns
      [track_id text]
      [tag_id integer]
      #:constraints
      (primary-key track_id tag_id))))

(define ((make-db-track-should-rescan? dbc) loc)
  (define last-scan-time
    (query-maybe-value dbc
      (select last_file_scan
              #:from tracks
              #:where (= location ,(url->string loc)))))
  (define file-mod-time
    (file-or-directory-modify-seconds (url->path loc) #f (lambda () #f)))
  (cond
    [(and last-scan-time file-mod-time) (> file-mod-time last-scan-time)]
    [else #t]))

(define (track-add-tag! dbc a-track-id tag-name tag-value)
  (define tag-id
    (cond
      [(query-maybe-value dbc
         (select id
                 #:from tags
                 #:where
                 (and (= name ,tag-name)
                      (= value ,tag-value)))) => values]
      [else
        (query-exec dbc
          (insert #:into tags
                  #:set
                  [name ,tag-name]
                  [value ,tag-value]))
        (query-value dbc
          (select (last_insert_rowid)))]))
  (query-exec dbc
    (insert #:into track_tag
            #:set
            [track_id ,a-track-id]
            [tag_id   ,tag-id])))

(define (track-remove-tag! dbc a-track-id tag-name tag-value)
  (define tag-id
    (query-maybe-value dbc
      (select id
              #:from tags
              #:where
              (and (= name ,tag-name)
                   (= value ,tag-value)))))
  (when tag-id
    (query-exec dbc
      (delete #:from track_tag
              #:where (and (= track_id ,a-track-id)
                           (= tag_id ,tag-id))))))

(define (add-track! dbc a-track)
  (call-with-transaction dbc
    (lambda ()
      (define id (track-id/string a-track))
      (query-exec dbc
        (insert #:into tracks
                #:set
                [id ,id]
                [location ,(track-location/string a-track)]
                [last_file_scan (strftime "%s" "now")]))
      (for ([(k v) (in-hash (track-tags a-track))])
        ;; XXX: some tags (like genre) may want to split into multiple tags?
        (track-add-tag! id k v)))))

