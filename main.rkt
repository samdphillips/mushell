#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define)

(define gst-lib
  (ffi-lib "libgstreamer-1.0"))

(define-ffi-definer define-gst gst-lib)

(define _gboolean _bool)
(define _GstClockTime _uint64)

(define-cpointer-type _GstObject)
(define-cpointer-type _GstElement)
(define-cpointer-type _GstBus)
(define-cpointer-type _GstMessage)
(define-cpointer-type _GstMiniObject)

(define _GstState
  (_enum '[GST_STATE_VOID_PENDING = 0
           GST_STATE_NULL         = 1
           GST_STATE_READY        = 2
           GST_STATE_PAUSED       = 3
           GST_STATE_PLAYING      = 4]))

(define _GstStateChangeReturn
  (_enum '[GST_STATE_CHANGE_FAILURE    = 0
           GST_STATE_CHANGE_SUCCESS    = 1
           GST_STATE_CHANGE_ASYNC      = 2
           GST_STATE_CHANGE_NO_PREROLL = 3]))

(define _GstMessageType
  (_bitmask '[GST_MESSAGE_UNKNOWN = 0
              GST_MESSAGE_EOS     = 1
              GST_MESSAGE_ERROR   = 2]))

(define GST_CLOCK_TIME_NONE #xFFFFFFFFFFFFFFFF)

;; FIXME: don't pass in nulls
(define-gst gst_init_check
  (_fun (_pointer = #f)
        (_pointer = #f)
        (_pointer = #f)
        -> _gboolean))

;; FIXME: don't pass in null for error
(define-gst gst_parse_launch
  (_fun _string/utf-8
        (_pointer = #f)
        ->
        _GstElement/null))

(define-gst gst_object_unref
  (_fun _GstObject -> _void))

(define-gst gst_element_set_state
  (_fun _GstElement _GstState
        ->
        _GstStateChangeReturn))

(define-gst gst_element_get_bus
  (_fun _GstElement -> _GstBus/null))

(define-gst gst_bus_timed_pop_filtered
  (_fun _GstBus
        _GstClockTime
        _GstMessageType
        ->
        _GstMessage/null))

(define-gst gst_mini_object_unref
  (_fun _GstMiniObject -> _void))

(define (gst_message_unref gst-message)
  (gst_mini_object_unref
    (cast gst-message _GstMessage _GstMiniObject)))

(module* tutorial-1 #f
  (gst_init_check)
  (define pipeline
    (gst_parse_launch
      "playbin uri=https://www.freedesktop.org/software/gstreamer-sdk/data/media/sintel_trailer-480p.webm"))
  (gst_element_set_state pipeline 'GST_STATE_PLAYING)
  (define bus (gst_element_get_bus pipeline))
  (define msg
    (gst_bus_timed_pop_filtered
      bus GST_CLOCK_TIME_NONE '(GST_MESSAGE_ERROR GST_MESSAGE_EOS)))
  (when msg
    (gst_message_unref msg))
  (gst_object_unref (cast bus _GstBus _GstObject))
  (gst_element_set_state pipeline 'GST_STATE_NULL)
  (gst_object_unref (cast pipeline _GstElement _GstObject)))

