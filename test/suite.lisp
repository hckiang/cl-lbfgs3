(in-package #:cl+lbfgsb3/test)

(defun run-tests ()
  (run! 'concurrent-fit-rosenbrock))
