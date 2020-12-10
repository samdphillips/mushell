#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define)

(provide _GObject
         _GstElement
         g_object_set
         gst_init?
         gst_init_check
         gst_bus_get_pollfd
         gst_bus_pop
         gst_element_factory_make
         gst_element_get_bus
         gst_element_get_state
         gst_element_set_state)

(define-ffi-definer define-gst
  (ffi-lib "libgstreamer-1.0"))

(define _gboolean _bool)
(define _gint     _int)
(define _gushort  _ushort)
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

(define-cstruct _GPollFD
  ([fd      _gint]
   [events  _gushort]
   [revents _gushort]))

(define GST_CLOCK_TIME_NONE #xFFFFFFFFFFFFFFFF)

(define gst_init? #f)

;; FIXME: don't pass in nulls
(define-gst gst_init_check
  (_fun (_pointer = #f)
        (_pointer = #f)
        (_pointer = #f)
        ->
        (ret : _gboolean)
        ->
        (begin
          (set! gst_init? ret)
          ret)))

;; FIXME: don't pass in null for error
(define-gst gst_parse_launch
  (_fun _string/utf-8
        (_pointer = #f)
        ->
        _GstElement/null))

(define-gst gst_object_unref
  (_fun _GstObject -> _void))

(define-gst gst_element_get_state
  (_fun _GstElement
        [current-state : (_ptr o _GstState)]
        [pending-state : (_ptr o _GstState)]
        _GstClockTime
        ->
        [return : _GstStateChangeReturn]
        ->
        (values return current-state pending-state)))

(define-gst gst_element_set_state
  (_fun _GstElement _GstState
        ->
        _GstStateChangeReturn))

(define-gst gst_element_get_bus
  (_fun _GstElement -> _GstBus/null))

(define-gst gst_bus_pop
  (_fun _GstBus
        ->
        _GstMessage/null))

(define-gst gst_bus_timed_pop_filtered
  (_fun _GstBus
        _GstClockTime
        _GstMessageType
        ->
        _GstMessage/null))

;; The program only needs the file descriptor so we toss out the rest of the
;; _GPollFD struct
(define-gst gst_bus_get_pollfd
  (_fun _GstBus
        (poll-fd : (_ptr o _GPollFD))
        ->
        _void
        ->
        (GPollFD-fd poll-fd)))

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

(define-gst gst_element_factory_make
  (_fun _string/utf-8
        _string/utf-8
        ->
        _GstElement))

(define gobject-lib
  (ffi-lib "libgobject-2.0"))

(define-cpointer-type _GObject)

;; g_object_set accepts varargs and can set multiple keys at once, but for
;; FFI reasons that is kinda sucky.  Just doing one covers most uses.
;; Additionally it's easier (at this point) to make the specify the correct
;; types, than to try and guess and be wrong.
(define g_object_set-cache (make-hash))
(define (g_object_set gobject name type val)
  (define func
    (hash-ref g_object_set-cache type
              (lambda ()
                (define ftype
                  (_cprocedure (list _GObject _string/utf-8 type _pointer) _void))
                (get-ffi-obj 'g_object_set gobject-lib ftype))))
  (func gobject name val #f))

(module* non-interactive-player-test #f
  (gst_init_check)
  (define playbin
    (gst_element_factory_make "playbin" "playbin"))
  (g_object_set
    (cast playbin _GstElement _GObject)
    "uri"
    _string/utf-8
    "https://www.freedesktop.org/software/gstreamer-sdk/data/media/sintel_trailer-480p.webm")
  (gst_element_set_state playbin 'GST_STATE_PLAYING)
  (define bus (gst_element_get_bus playbin))
  (define msg
    (gst_bus_timed_pop_filtered
      bus GST_CLOCK_TIME_NONE '(GST_MESSAGE_ERROR GST_MESSAGE_EOS)))
  (when msg
    (gst_message_unref msg))
  (gst_object_unref (cast bus _GstBus _GstObject))
  (gst_element_set_state playbin 'GST_STATE_NULL)
  (gst_object_unref (cast playbin _GstElement _GstObject)))

