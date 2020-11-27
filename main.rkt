#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/define/conventions)

(define gst-lib
  (ffi-lib "libgstreamer-1.0"))

(define-ffi-definer define-gst gst-lib
  #:make-c-id convention:hyphen->underscore)

(define _gboolean _bool)
(define _gst-clock-time _uint64)

(define-cpointer-type _gst-element)
(define-cpointer-type _gst-bus)
(define-cpointer-type _gst-message)

(define _gst-state
  (_enum '[GST_STATE_VOID_PENDING = 0
           GST_STATE_NULL         = 1
           GST_STATE_READY        = 2
           GST_STATE_PAUSED       = 3
           GST_STATE_PLAYING      = 4]))

(define _gst-state-change-return
  (_enum '[GST_STATE_CHANGE_FAILURE    = 0
           GST_STATE_CHANGE_SUCCESS    = 1
           GST_STATE_CHANGE_ASYNC      = 2
           GST_STATE_CHANGE_NO_PREROLL = 3]))

(define _gst-message-type
  (_bitmask '[GST_MESSAGE_UNKNOWN = 0
              GST_MESSAGE_EOS     = 1
              GST_MESSAGE_ERROR   = 2]))

(define GST_CLOCK_TIME_NONE #xFFFFFFFFFFFFFFFF)

;; FIXME: don't pass in nulls
(define-gst gst-init-check
  (_fun (_pointer = #f)
        (_pointer = #f)
        (_pointer = #f)
        -> _gboolean))

;; FIXME: don't pass in null for error
(define-gst gst-parse-launch
  (_fun _string/utf-8
        (_pointer = #f)
        ->
        _gst-element/null))

(define-gst gst-element-set-state
  (_fun _gst-element _gst-state
        ->
        _gst-state-change-return))

(define-gst gst-element-get-bus
  (_fun _gst-element -> _gst-bus/null))

(define-gst gst-bus-timed-pop-filtered
  (_fun _gst-bus
        _gst-clock-time
        _gst-message-type
        ->
        _gst-message/null))

(module* tutorial-1 #f
  (gst-init-check)
  (define pipeline
    (gst-parse-launch
      "playbin uri=https://www.freedesktop.org/software/gstreamer-sdk/data/media/sintel_trailer-480p.webm"))
  (gst-element-set-state pipeline 'GST_STATE_PLAYING)
  (define bus (gst-element-get-bus pipeline))
  (define msg
    (gst-bus-timed-pop-filtered
      bus GST_CLOCK_TIME_NONE '(GST_MESSAGE_ERROR GST_MESSAGE_EOS)))

  (when msg
    (gst-message-unref msg))
  (gst-object-unref bus)
  (gst-element-set-state pipeline 'GST_STATE_NULL)
  (gst-object-unref pipeline))

