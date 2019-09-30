;;;; animise.lisp

(in-package #:animise)

;;; Utilities for defining easing functions

(defun time-frac (start duration current)
  (let* ((end (+ start duration))
        (progress (max 0 (- end current))))
    (- 1.0 (/ progress duration))))

(defmacro def-ease (name &rest body)
  `(defun ,name (start duration current &optional (delta 1))
     (let ((frac (time-frac start duration current)))
       ,@body)))

(defmacro def-mirror-for (name-of-ease)
  (let ((mirror-name (read-from-string (format nil "mirror-~a" name-of-ease))))
    `(def-ease ,mirror-name
         (if (<= frac 0.5)
             (,name-of-ease start (* 0.5 duration) current delta)
             (,name-of-ease start (* 0.5 duration)
                            (- (+ start (* 0.5 duration))
                               (- current (+ start (* 0.5 duration))))
                            delta)))))

;;; EASING FUNCTION DEFINITIONS ;;;

;;; The DEF-EASE macro defines a function. the BODY of the function has the
;;; following variables available to it:
;;; START the start time in MS
;;; DURATION intended duration of this animation
;;; CURRENT the current time, sometime after START
;;; DELTA, a number, the total change in the value being animated (e.g. X coordinate)
;;; FRAC, a number between 0 and 1, the how close to completion this animation is.

(def-ease linear (* delta frac))

(def-mirror-for linear)

(def-ease quad-in (* frac frac delta))

(def-mirror-for quad-in)

(def-ease quad-out (* frac (- frac 2.0) -1 delta))

(def-mirror-for quad-out)

(def-ease quad-in-out
  (setf frac (/ frac 0.5))
  (if (< frac 1) (* frac frac 0.5 delta)
      (progn (decf frac)
             (* -1 delta 0.5 (1- (* frac (- frac 2)))))))

(def-mirror-for quad-in-out)

(def-ease cubic-in (* frac frac frac delta))

(def-mirror-for cubic-in)

(def-ease cubic-out
    (decf frac)
    (* (1+ (* frac frac frac)) delta))

(def-mirror-for cubic-out)

(def-ease cubic-in-out
  (setf frac (/ frac 0.5))
  (if (< frac 1) (* delta 0.5 frac frac frac)
      (progn
        (decf frac 2)
        (* delta 0.5 (+ 2 (* frac frac frac))))))

(def-mirror-for cubic-in-out)

(def-ease sinusoidal-in
  (+ delta (* -1 delta (cos (* frac pi 0.5)))))

(def-mirror-for sinusoidal-in)

(def-ease sinusoidal-out
  (* delta (sin (* frac pi 0.5))))
(def-mirror-for sinusoidal-out)

(def-ease sinusoidal-in-out
  (* delta -0.5 (1- (cos (* pi frac)))))
(def-mirror-for sinusoidal-in-out)

(def-ease elastic-out
      (let ((sqrd (* frac frac))
            (cubed (* frac frac frac)))
        (* 100 delta (+ (* 0.33 sqrd cubed)
                        (* -1.06 sqrd sqrd)
                        (* 1.26 cubed)
                        (* -0.67 sqrd)
                        (* 0.15 frac)))))

(def-mirror-for elastic-out)

(def-ease bounce-out
    (let ((coeff 7.5627)
          (step (/ 1 2.75)))
      (cond ((< frac step)
             (* delta coeff frac frac))
            ((< frac (* 2 step))
             (decf frac (* 1.5 step))
             (* delta
                (+ 0.75
                   (* coeff frac frac))))
            ((< frac ( * 2.5 step))
             (decf frac (* 2.25 step))
             (* delta
                (+ 0.9375
                   (* coeff frac frac))))
            (t
             (decf frac (* 2.65 step))
             (* delta
                (+ 0.984375
                   (* coeff frac frac)))))))

(def-mirror-for bounce-out)

;;; Some functions to check your intuitions about the output of easing functions

(defun make-frames (ease-fn &optional (step 0.1))
  (loop :for time :from 0 :upto (+ 1 step) :by step
        :collect (funcall ease-fn 0 1.0 time)))

(defun print-frames (fn &key (width 20) (mark #\.) (step 0.1))
  (loop for frame in (make-frames fn step) do
    (dotimes (x width) (princ #\Space))
    (dotimes (x (round (* frame width)))
      (princ #\Space))
    (princ mark)
    (terpri)))

;;; TWEENS

"A TWEEN is function to produce a sequence of values over time for the purpose
  of animating an object.

  START-TIME and DURATION arguments are a representation of time and must use
  the same units. START-TIME must be supplied on TWEEN instantiation, and is
  used to record when the tween begins running.

  DELTA-VAL is a number, the amount by which the animated object's target
  property should have changed by the time the animation is over.

  Different EASE functions may be supplied to modulate the way that sequence is
  produced.  EASE is the heart of the TWEEN's behavior.

  Every TWEEN instance must have an EFFECTOR, which should be a closure that
  accepts a single argument. The purpose of the EFFECTOR is to apply the values
  generated by the TWEEN to some object."


(defclass tween ()
  ((start-time
    :accessor start-time
    :initarg :start-time
    :initform (error "Must supply a start time."))
   (duration
    :reader duration
    :initarg :duration
    :initform 1000.0) ; 1 second
   (ease-fn
    :initarg :ease-fn
    :initform #'linear)
   (start-val
    :accessor start-val
    :initarg start-val
    :initform (error "Must supply a start value."))
   (delta-val
    :accessor delta-val
    :initarg :delta-val
    :initform (error "Must supply a delta value."))
   (effector
    :initarg :effector
    :initform (error "Must supply an effector function"))))

(defun end-time (tween)
    (+ (start-time tween) (duration tween)))

(defun tween-finished-p (tween current-time)
  (>= current-time (end-time tween)))

(defgeneric run-tween (tween time))

(defmethod run-tween ((tween tween) time)
  (with-slots (start-time duration ease start-val delta-val effector) tween
    (when (>= time start-time)
      (funcall effector
               (+ start-val
                  (funcall ease start-time duration time delta-val))))))

(defgeneric reverse-tween (tween &optional start))

(defmethod reverse-tween ((tween tween) &optional start)
  (with-slots (start-time duration ease start-val delta-val effector) tween
    (make-tween :start-time (if start start (+ duration start-time))
                :duration duration
                :start-val (+ start-val delta-val)
                :delta-val (* -1 delta-val)
                :effector effector)))

(defclass tween-seq ()
  ((tweens
    :accessor tweens
    :initarg :tweens
    :initform nil)
   (loop-mode
    :accessor loop-mode
    :initarg :loop-mode
    :initform nil)))  ; :looping :reflecting

(defmethod start-time ((ob tween-seq))
  (when (tweens ob)
    (start-time (car (tweens ob)))))

(defmethod duration ((ob tween-seq))
  (when (tweens ob)
    (reduce #'+ (tweens ob) :key #'duration :initial-value 0)))

;; TODO implmeent the reflecting tween behavior
(defun apply-looping (seq)
  (case (loop-mode seq)
    (:looping
     (setf (start-time seq) (end-time seq))
     (correct-sequencing seq)
     (car (tweens seq)))
    (:reflecting nil)))

(defmethod run-tween ((ob tween-seq) time)
  (let-cond
    (tween (find-if-not (lambda (tween) (tween-finished-p tween time))
                               (tweens ob))
           (run-tween tween time))
    (tween (apply-looping ob)
           (run-tween tween time))))

(defgeneric add-after (first second)
  (:documentation "A potentialy destructive function that puts its tween
  arguments into sequence. In the case of a TWEEN-SEQ in the first position, it
  is that argument that will be returned. Consider the second argument as
  discarded."))

(defmethod add-after ((first tween) (second tween))
  (setf (start-time second) (end-time first))
  (make-instance 'tween-seq :tweens (list first second)))

(defmethod add-after ((first tween-seq) (second tween))
  (setf (start-time second) (end-time first))
  (setf (tweens first)
        (append (tweens first) (list second)))
  first)

(defun correct-sequencing (seq)
  (when (tweens seq)
    (let ((end (end-time (car (tweens seq)))))
      (doist (tween (cdr (tweens seq))
        (setf (start-time tween) end)
        (setf end (end-time tween))))))

(defmethod add-after ((first tween) (second tween-seq))
  (push first (tweens second))
  (correct-sequencing second)
  second)

(defmethod add-after ((first tween-seq) (second tween-seq))
  (setf (tweens first)
        (append (tweens first) (tweens second)))
  (correct-sequencing first)
  first)

;; TODO perhaps a little slow b/c of the unnecessary calls to correct-sequencing
;; in the intermediate steps
(defun join (tween1 tween2 &rest tweens)
  (let ((tween (add-after tween1 tween2)))
    (dolist (tw tweens)
      (setf tween (add-after tween tw)))
    tween))
