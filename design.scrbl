#lang scribble/base

@title{mushell Design}

Basically Model View Presenter architecture

@section{Model}
@subsection{mushell-core%}
@para{
  Ties the other model parts together.
}

@subsection{player%}
@para{
  Interface to gstreamer.
}

@subsection{playlist%}

@subsection{track-library%}

@subsection{make-track-scanner}
@para{
  Scans a path and it's subdirectories for tracks.  Returns a
  stream of @tt{track}.
}

@section{Presenter}
@subsection{mushell-repl%}

@section{View}
Basic view pieces...

@subsection{mushell-view%}
