#lang racket/base

(require racket/format
         racket/hash
         racket/match
         racket/path
         racket/sequence
         ffi/unsafe
         ffi/unsafe/port
         net/url
         threading
         "../gstreamer.rkt"
         "track.rkt")

(provide scan-roots)

(define-logger track-scanner)

(struct scanner (pipeline bus) #:mutable)

(define (make-scanner)
  (unless gst_init?
    (gst_init_check))
  (define pipeline
    (gst_parse_launch "playbin audio-sink=fakesink"))
  (define bus (gst_element_get_bus pipeline))
  (scanner pipeline bus))

(define (scanner-close! scn)
  (define pipeline (scanner-pipeline scn))
  (gst_object_unref (cast (scanner-bus scn) _GstBus _GstObject))
  (gst_element_set_state pipeline 'GST_STATE_NULL)
  (gst_object_unref (cast pipeline _GstElement _GstObject))
  (set-scanner-pipeline! scn #f)
  (set-scanner-bus! scn #f))

(define (scan-file scn fname)
  (define uri (url->string fname))
  (define p (scanner-pipeline scn))
  (define b (scanner-bus scn))
  (log-track-scanner-info "scanning ~a for tags" uri)
  (gst_element_set_state p 'GST_STATE_NULL)
  (g_object_set (cast p _GstElement _GObject) "uri" _string/utf-8 uri)
  (gst_element_set_state p 'GST_STATE_PLAYING)
  (define msgs (scanner-bus-collect-messages b))
  (gst_element_set_state p 'GST_STATE_NULL)
  msgs)

(define (scanner-bus-collect-messages bus)
  (define bus-msg-evt
    (wrap-evt
      (guard-evt
        (lambda ()
          (unsafe-fd->evt (gst_bus_get_pollfd bus) 'read)))
      (lambda (ignore)
        (gst_bus_pop bus))))
  (define (collect tags)
    (define msg (sync bus-msg-evt))
    (match (GstMessage-type msg)
      ['GST_MESSAGE_EOS
       (gst_message_unref msg)
       tags]
      ['GST_MESSAGE_TAG
       (define new-tags
         (extract-tags (gst_message_parse_tag msg)))
       (gst_message_unref msg)
       (collect
         (hash-union tags new-tags #:combine (lambda (a b) b)))]
      ['GST_MESSAGE_ERROR
       ;; XXX: extract out the error message
       (gst_message_unref msg)
       (log-track-scanner-error "an error occurred reading tags")
       tags]
      [type
       (log-track-scanner-debug "skipping gst bus message type: ~a" type)
       (gst_message_unref msg)
       (collect tags)]))
  (collect (hash)))

(define (get-tag-ref name)
  (match (g_type_name (gst_tag_get_type name))
    ["gchararray" gst_tag_list_get_string]
    ["guint"      gst_tag_list_get_uint]
    [ty
      (log-track-scanner-warning "skipping tag: ~s with type: ~s" name ty)
      #f]))

(define (extract-tags tags)
  (define n (gst_tag_list_n_tags tags))
  (define extracted
    (for*/hash ([i n]
                [name (in-value (gst_tag_list_nth_tag_name tags i))]
                [ref  (in-value (get-tag-ref name))]
                #:when ref)
      (values name (ref tags name))))
  (gst_tag_list_unref tags)
  extracted)

(define (audio-file? fname)
  (match (path-get-extension fname)
    [(or #".ogg" #".mp3" #".m4a") #t]
    [_ #f]))

;; XXX: one problem is that the my storage is on a network mount, so
;; interruption during operations are probably going to happen.  What does that
;; look like? How to handle that?

(define (scan-roots roots filter? each-f)
  (define scn (make-scanner))
  (define fname-urls
    (~>> (map in-directory roots)
         (apply sequence-append)
         (sequence-filter audio-file?)
         (sequence-map path->url)
         (sequence-filter filter?)))
  (for ([loc fname-urls])
    (each-f (make-track loc (scan-file scn loc))))
  (scanner-close! scn))

(module* scan #f
  (time
    (scan-roots (list "/mnt/music/reorganized/Various Artists")
                (lambda (u) #t)
                (lambda (t)
                  (log-track-scanner-info "seen ~s" t)))))

#;
(module* exp #f
  (require racket/exn
           racket/pretty
           db)

  (define dbc (sqlite3-connect #:database "test.db" #:mode 'create #:use-place #t))
  (create-schema dbc)

  (define insert-track-stmt
    (prepare dbc "INSERT INTO tracks (id, location, last_file_scan) VALUES (?, ?, strftime('%s','now'))"))

  (define insert-tags-stmt
    (prepare dbc "INSERT INTO tags (name, value) VALUES (?, ?)"))

  (define insert-track-tag-stmt
    (prepare dbc "INSERT INTO track_tag (track_id, tag_id) VALUES (?, ?)"))

  (define find-existing-tag-stmt
    (prepare dbc "SELECT id FROM tags WHERE name=? AND value=?"))

  (define (log-exception e)
    (log-track-scanner-error (exn->string e)))

  (define (track-add-tag! track-id tag-name tag-value)
    (define tag-id
      (cond
        [(query-maybe-value dbc find-existing-tag-stmt tag-name tag-value) => values]
        [else
          (query-exec dbc insert-tags-stmt tag-name tag-value)
          (query-value dbc "SELECT last_insert_rowid()")]))
    (query-exec dbc insert-track-tag-stmt track-id tag-id))

  (define (insert-track! tr)
    (with-handlers ([exn:fail? log-exception])
      (call-with-transaction dbc
        (lambda ()
          (define id (track-id/string tr))
          (query-exec dbc insert-track-stmt id (track-location/string tr))
          (for ([(k v) (in-hash (track-tags tr))])
            ;; XXX: some tags (like genre) we want to split into multiples...
            (track-add-tag! id k v))))))

  (define track-last-file-scan-stmt
    (prepare dbc "SELECT last_file_scan FROM tracks WHERE location=?"))

  (define (fetch-track-last-file-scan loc)
    (query-maybe-value dbc track-last-file-scan-stmt (url->string loc)))

  (define (filter-location? loc)
    (define t (fetch-track-last-file-scan loc))
    (or (not t)
        ;; XXX: check file mod time vs timestamp
        ))

  (scan-roots '("/Volumes/music")
              filter-location?
              insert-track!))

