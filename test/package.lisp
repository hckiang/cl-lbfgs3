(defpackage #:cl+lbfgsb3/test
  (:use #:cl
        #:cl+lbfgsb3          ; so you can call FIT-ROSENBROCK unqualified
        #:bordeaux-threads
        #:fiveam)
  (:export #:run-tests
           #:concurrent-fit-rosenbrock))  ; if you want to run it individually
