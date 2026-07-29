(in-package #:cl+lbfgsb3/test)

(defun rosenbrock (x)
  (let ((x1 (aref x 0)) (x2 (aref x 1)))
    (+ (expt (- 1 x1) 2)
       (* 100 (expt (- x2 (* x1 x1)) 2)))))

(defun rosenbrock-grad (x)
  (let ((x1 (aref x 0)) (x2 (aref x 1)))
    (vector (+ (* -2 (- 1 x1))
               (* -400 x1 (- x2 (* x1 x1))))
            (* 200 (- x2 (* x1 x1))))))

(defun fit-rosenbrock ()
  (let ((res (cl+lbfgsb3:lbfgsb3 #'rosenbrock
                                 #(-1.2d0 1.0d0)
                                 :gr #'rosenbrock-grad
                                 :m 5
                                 :factr 1d0
                                 :pgtol 1d-4
                                 :iprint -1)))
    ;; (format t "x       = ~A~%" (cl+lbfgsb3:lbfgsb3-result-x res))
    ;; (format t "f       = ~A~%" (cl+lbfgsb3:lbfgsb3-result-f res))
    ;; (format t "n-iter  = ~A~%" (cl+lbfgsb3:lbfgsb3-result-n-iter res))
    ;; (format t "n-fg    = ~A~%" (cl+lbfgsb3:lbfgsb3-result-n-fg res))
    ;; (format t "message = ~A~%" (cl+lbfgsb3:lbfgsb3-result-message res))
    res))


(defparameter *num-threads* 256)
(defparameter *calls-per-thread* 50)

(defun call-fit-rosenbrock ()
  (fit-rosenbrock)
  t)

(defstruct (locked-queue (:constructor make-locked-queue ()))
  (lock  (make-lock) :read-only t)
  (items '()         :type list))


(defun enqueue (item q)
  (push item (locked-queue-items q)))

(defun queue-contents (q)
  (locked-queue-items q))

(defmacro with-locked-queue (q &body body)
  `(with-lock-held ((locked-queue-lock ,q))
     ,@body))

(test concurrent-fit-rosenbrock
  "Start many threads that all call FIT-ROSENBROCK simultaneously."
  (let ((barrier (make-semaphore :count 0))
        (errors  (make-locked-queue))
        (threads '()))

    (dotimes (i *num-threads*)
      (push (make-thread
             (lambda ()
               (wait-on-semaphore barrier)
               (handler-case
                   (dotimes (_ *calls-per-thread*)
                     (call-fit-rosenbrock))
                 (error (e)
                   (with-locked-queue errors
                     (enqueue e errors)))))
             :name (format nil "fit-rosenbrock-worker-~D" i))
            threads))

    (dotimes (_ *num-threads*)
      (signal-semaphore barrier))

    (mapc #'join-thread threads)

    (let ((err-list (with-locked-queue errors
                      (queue-contents errors))))
      (is (null err-list)
          "No errors should have been signalled.~%~
           Errors seen:~%~{  ~A~%~}" err-list))))

