(in-package #:cl+lbfgsb3)

(defstruct lbfgsb3-result
  x                      ; final point (simple-vector of double-float)
  f                      ; final function value
  g                      ; final gradient
  task                   ; final itask code
  n-iter                 ; number of iterations (isave[29] in 0-based)
  n-fg                   ; number of function/gradient evaluations
  message)               ; human-readable termination message

(defun task-message (task)
  (case task
    (1  "NEW_X")
    (2  "START")
    (4  "FG")
    (5  "ABNORMAL_TERMINATION_IN_LNSRCH")
    (6  "CONVERGENCE")
    (7  "CONVERGENCE: NORM_OF_PROJECTED_GRADIENT_<=_PGTOL")
    (8  "CONVERGENCE: REL_REDUCTION_OF_F_<=_FACTR*EPSMCH")
    (9  "ERROR: FTOL .LT. ZERO")
    (10 "ERROR: GTOL .LT. ZERO")
    (11 "ERROR: INITIAL G .GE. ZERO")
    (12 "ERROR: INVALID NBD")
    (13 "ERROR: M .LE. 0")
    (14 "ERROR: NO FEASIBLE SOLUTION")
    (15 "ERROR: STP .GT. STPMAX")
    (16 "ERROR: STP .LT. STPMIN")
    (17 "ERROR: STPMAX .LT. STPMIN")
    (18 "ERROR: STPMIN .LT. ZERO")
    (19 "ERROR: XTOL .LT. ZERO")
    (20 "FG_LNSRCH")
    (21 "FG_START")
    (22 "RESTART_FROM_LNSRCH")
    (23 "WARNING: ROUNDING ERRORS PREVENT PROGRESS")
    (24 "WARNING: STP = STPMAX")
    (25 "WARNING: STP = STPMIN")
    (26 "WARNING: XTOL TEST SATISFIED")
    (t  (format nil "UNKNOWN TASK ~D" task))))

(defun finite-p (x)
  (and (numberp x) (not (or (float-features:float-nan-p x)
                            (float-features:float-infinity-p x)))))

(defun make-nbd (n lower upper)
  "Build the nbd array (0=unbounded, 1=lower, 2=both, 3=upper)."
  (let ((nbd (make-array n :element-type '(signed-byte 32) :initial-element 0))
        (lo  (if (and lower (not (consp lower)) (not (vectorp lower)))
                 (make-array n :initial-element (float lower 1d0))
                 lower))
        (up  (if (and upper (not (consp upper)) (not (vectorp upper)))
                 (make-array n :initial-element (float upper 1d0))
                 upper)))
    (dotimes (i n nbd)
      (let ((has-lo (and lo (finite-p (elt lo i))))
            (has-up (and up (finite-p (elt up i)))))
        (setf (aref nbd i)
              (cond ((and has-lo has-up) 2)
                    (has-lo              1)
                    (has-up              3)
                    (t                   0)))))))

(defun copy-to-foreign (lisp-vec foreign-ptr type)
  (dotimes (i (length lisp-vec))
    (setf (mem-aref foreign-ptr type i)
          (coerce (aref lisp-vec i) (if (eq type :double) 'double-float 'integer)))))

(defun copy-from-foreign (foreign-ptr n type)
  (let ((v (make-array n :element-type (if (eq type :double)
                                           'double-float
                                           '(signed-byte 32)))))
    (dotimes (i n v)
      (setf (aref v i) (mem-aref foreign-ptr type i)))))

(defun make-finite-difference-gradient (fn &optional (eps 1d-8))
  (lambda (x)
    (let* ((n (length x))
           (g (make-array n :element-type 'double-float))
           (f0 (funcall fn x)))
      (dotimes (i n g)
        (let* ((xi (aref x i))
               (step (* eps (max 1d0 (abs xi)))))
          (setf (aref x i) (+ xi step))
          (setf (aref g i) (/ (- (funcall fn x) f0) step))
          (setf (aref x i) xi))))))

(defun lbfgsb3 (fn x0
                &key
                  (gr nil)
                  lower upper
                  (m 10)
                  (factr 1d6)
                  (pgtol 1d-5)
                  (max-iter 200)
                  (max-fg 2500)
                  (iprint -1)
                  (trace nil))
  (let ((*fortran-prints-enabled* trace)) 
    (unless gr
      (setf gr (make-finite-difference-gradient fn)))
    (let* ((n       (length x0))
           (x0      (map '(vector double-float) (lambda (v) (float v 1d0)) x0))
           (nbd-vec (make-nbd n lower upper))
           (lo-vec  (if lower
                        (map '(vector double-float)
                             (lambda (v) (float (or v -1d100) 1d0))
                             (if (vectorp lower) lower (make-array n :initial-element lower)))
                        (make-array n :element-type 'double-float :initial-element -1d100)))
           (up-vec  (if upper
                        (map '(vector double-float)
                             (lambda (v) (float (or v 1d100) 1d0))
                             (if (vectorp upper) upper (make-array n :initial-element upper)))
                        (make-array n :element-type 'double-float :initial-element 1d100)))
           (wa-size (+ (* 2 m n) (* 5 n) (* 11 m m) (* 8 m))))
      (with-foreign-objects
          ((pn      :int)
           (pm      :int)
           (x       :double n)
           (l       :double n)
           (u       :double n)
           (nbd     :int n)
           (f       :double)
           (g       :double n)
           (pfactr  :double)
           (ppgtol  :double)
           (wa      :double wa-size)
           (iwa     :int (* 3 n))
           (itask   :int)
           (piprint :int)
           (icsave  :int)
           (lsave   :int 4)
           (isave   :int 44)
           (dsave   :double 29))
        (setf (mem-ref pn      :int)    n
              (mem-ref pm      :int)    m
              (mem-ref pfactr  :double) factr
              (mem-ref ppgtol  :double) pgtol
              (mem-ref piprint :int)    iprint
              (mem-ref itask   :int)    2      ; START
              (mem-ref icsave  :int)    0)
        (dotimes (i wa-size) (setf (mem-aref wa :double i) 0d0))
        (dotimes (i (* 3 n)) (setf (mem-aref iwa :int i) 0))
        (dotimes (i 4)       (setf (mem-aref lsave :int i) 0))
        (dotimes (i 44)      (setf (mem-aref isave :int i) 0))
        (dotimes (i 29)      (setf (mem-aref dsave :double i) 0d0))
        (copy-to-foreign x0     x   :double)
        (copy-to-foreign lo-vec l   :double)
        (copy-to-foreign up-vec u   :double)
        (copy-to-foreign nbd-vec nbd :int)
        (let ((n-fg 0)
              (lisp-x (make-array n :element-type 'double-float)))
          (loop
            (setulb pn pm x l u nbd f g pfactr ppgtol
                    wa iwa itask piprint icsave lsave isave dsave)
            (let ((task (mem-ref itask :int)))
              (cond
                ((member task '(4 20 21))
                 (incf n-fg)
                 (when (> n-fg max-fg)
                   (return-from lbfgsb3
                     (make-lbfgsb3-result
                      :x (copy-from-foreign x n :double)
                      :f (mem-ref f :double)
                      :g (copy-from-foreign g n :double)
                      :task task
                      :n-iter (mem-aref isave :int 29)
                      :n-fg n-fg
                      :message "MAX_FG_EVALUATIONS_REACHED")))
                 (dotimes (i n)
                   (setf (aref lisp-x i) (mem-aref x :double i)))
                 (let ((fv (funcall fn lisp-x))
                       (gv (funcall gr lisp-x)))
                   (setf (mem-ref f :double) (float fv 1d0))
                   (dotimes (i n)
                     (setf (mem-aref g :double i) (float (elt gv i) )))))
                ;; NEW_X : optional iteration limit
                ((= task 1)
                 (let ((iter (mem-aref isave :int 29)))
                   (when (and max-iter (>= iter max-iter))
                     (return-from lbfgsb3
                       (make-lbfgsb3-result
                        :x (copy-from-foreign x n :double)
                        :f (mem-ref f :double)
                        :g (copy-from-foreign g n :double)
                        :task task
                        :n-iter iter
                        :n-fg n-fg
                        :message "MAX_ITERATIONS_REACHED")))))
                ;; successful termination
                ((member task '(6 7 8))
                 (return-from lbfgsb3
                   (make-lbfgsb3-result
                    :x (copy-from-foreign x n :double)
                    :f (mem-ref f :double)
                    :g (copy-from-foreign g n :double)
                    :task task
                    :n-iter (mem-aref isave :int 29)
                    :n-fg n-fg
                    :message (task-message task))))
                ;; error / warning / unknown
                (t
                 (return-from lbfgsb3
                   (make-lbfgsb3-result
                    :x (copy-from-foreign x n :double)
                    :f (mem-ref f :double)
                    :g (copy-from-foreign g n :double)
                    :task task
                    :n-iter (mem-aref isave :int 29)
                    :n-fg n-fg
                    :message (task-message task))))))))))))
