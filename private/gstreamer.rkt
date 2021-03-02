#lang racket/base

(require racket/match
         setup/dirs
         ffi/unsafe
         ffi/unsafe/define)

(provide _GObject
         _GstElement
         g_object_set
         gst_init?
         gst_init_check
         gst_parse_launch
         gst_bus_get_pollfd
         gst_bus_pop
         gst_element_factory_make
         gst_element_get_bus
         gst_element_get_state
         gst_element_set_state
         GstMessage-type
         GstMessage-timestamp
         gst_message_unref
         gst_message_parse_state_changed
         gst_message_parse_tag

         gst_tag_list_unref
         gst_tag_list_n_tags
         gst_tag_list_nth_tag_name
         gst_tag_list_get_string
         gst_tag_list_get_tag_size)

;; workaround for MacOS with homebrew installed gstreamer
(define (get-lib-dirs)
  (append (match (system-type 'os)
            ['macosx
             '("/usr/local/Cellar/gstreamer/1.18.3/lib"
               "/usr/local/Cellar/glib/2.66.7/lib/")]
            [_ null])
          (get-lib-search-dirs)))

(define-ffi-definer define-gst
  (ffi-lib "libgstreamer-1.0"
           #:get-lib-dirs get-lib-dirs))

(define _gboolean _bool)
(define _gint     _int)
(define _guint    _uint)
(define _guint64  _uint64)
(define _gushort  _ushort)
(define _GstClockTime _uint64)

(define-cpointer-type _GstObject)
(define-cpointer-type _GstElement)
(define-cpointer-type _GstBus)
(define-cpointer-type _GstMessage)
(define-cpointer-type _GstMiniObject)
(define-cpointer-type _GstTagList)

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

(define _GstMessageType/bitmask
  (_bitmask '[GST_MESSAGE_UNKNOWN = 0
              GST_MESSAGE_EOS     = 1
              GST_MESSAGE_ERROR   = 2]))

(define _GstMessageType/enum
  (_enum
    '[GST_MESSAGE_UNKNOWN           = #x00000000
      GST_MESSAGE_EOS               = #x00000001
      GST_MESSAGE_ERROR             = #x00000002
      GST_MESSAGE_WARNING           = #x00000004
      GST_MESSAGE_INFO              = #x00000008
      GST_MESSAGE_TAG               = #x00000010
      GST_MESSAGE_BUFFERING         = #x00000020
      GST_MESSAGE_STATE_CHANGED     = #x00000040
      GST_MESSAGE_STATE_DIRTY       = #x00000080
      GST_MESSAGE_STEP_DONE         = #x00000100
      GST_MESSAGE_CLOCK_PROVIDE     = #x00000200
      GST_MESSAGE_CLOCK_LOST        = #x00000400
      GST_MESSAGE_NEW_CLOCK         = #x00000800
      GST_MESSAGE_STRUCTURE_CHANGE  = #x00001000
      GST_MESSAGE_STREAM_STATUS     = #x00002000
      GST_MESSAGE_APPLICATION       = #x00004000
      GST_MESSAGE_ELEMENT           = #x00008000
      GST_MESSAGE_SEGMENT_START     = #x00010000
      GST_MESSAGE_SEGMENT_DONE      = #x00020000
      GST_MESSAGE_DURATION_CHANGED  = #x00040000
      GST_MESSAGE_LATENCY           = #x00080000
      GST_MESSAGE_ASYNC_START       = #x00100000
      GST_MESSAGE_ASYNC_DONE        = #x00200000
      GST_MESSAGE_REQUEST_STATE     = #x00400000
      GST_MESSAGE_STEP_START        = #x00800000
      GST_MESSAGE_QOS               = #x01000000
      GST_MESSAGE_PROGRESS          = #x02000000
      GST_MESSAGE_TOC               = #x04000000
      GST_MESSAGE_RESET_TIME        = #x08000000
      GST_MESSAGE_STREAM_START      = #x10000000
      GST_MESSAGE_NEED_CONTEXT      = #x20000000
      GST_MESSAGE_HAVE_CONTEXT      = #x40000000]))

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
        _GstMessageType/bitmask
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

;; DANGER: this is very unsafe and may not work on every platform.  I asked the
;; C compiler for the offset of these fields on my system.  I am much too lazy
;; to transcribe all the parts of this just to get this these fields.
(define (GstMessage-type msg)
  (ptr-ref (ptr-add msg 64) _GstMessageType/enum))

(define (GstMessage-timestamp msg)
  (ptr-ref (ptr-add msg 72) _guint64))

(define-gst gst_mini_object_unref
  (_fun _GstMiniObject -> _void))

(define (gst_message_unref gst-message)
  (gst_mini_object_unref
    (cast gst-message _GstMessage _GstMiniObject)))

(define-gst gst_message_parse_state_changed
  (_fun _GstMessage
        [old : (_ptr o _GstState)]
        [new : (_ptr o _GstState)]
        [pending : (_ptr o _GstState)]
        ->
        _void
        ->
        (values old new pending)))

(define-gst gst_message_parse_tag
  (_fun _GstMessage
        [taglist : (_ptr o _GstTagList)]
        ->
        _void
        ->
        taglist))

(define-gst gst_tag_list_n_tags
  (_fun _GstTagList -> _gint))

(define-gst gst_tag_list_nth_tag_name
  (_fun _GstTagList
        _guint
        ->
        _string/utf-8))

;; Copy to a Racket string, but also free the pointer from C.
(define (ptr->string p)
  (dynamic-wind
    void
    (lambda () (cast p _pointer _string/utf-8))
    (lambda () (g_free p))))

(define-gst gst_tag_list_get_string
  (_fun _GstTagList
        _string/latin-1
        [val : (_ptr o _pointer)]
        ->
        [res : _gboolean]
        ->
        (and res (ptr->string val))))

(define-gst gst_tag_list_get_tag_size
  (_fun _GstTagList
        _string/utf-8
        ->
        _guint))

(define (gst_tag_list_unref gst-tag-list)
  (gst_mini_object_unref
    (cast gst-tag-list _GstTagList _GstMiniObject)))

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

(define-ffi-definer define-glib
  (ffi-lib "libglib-2.0"
           #:get-lib-dirs get-lib-dirs))

(define-glib g_free
  (_fun _pointer -> _void))

(define gobject-lib
  (ffi-lib "libgobject-2.0"
           #:get-lib-dirs get-lib-dirs))

(define-cpointer-type _GObject)

;; g_object_set accepts varargs and can set multiple keys at once, but for
;; FFI reasons that is kinda sucky.  Just doing one covers most uses.
;; Additionally it's easier (at this point) to make the specify the correct
;; types, than to try and guess and be wrong.
(define g_object_set-cache (make-hash))
(define (g_object_set gobject name type val)
  (define func
    (hash-ref! g_object_set-cache type
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

