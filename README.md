# cl+lbfgs3

An Common Lisp FFI for the 2011 version of L-BFGS-B (C. Zhu, R. H. Byrd and J. Nocedal
1997).

This version of Fortran code is based on the version 3.0 (Remark on Algorithm 778,
J.L. Morales and J. Nocedal 2011), lightly modified by John C Nash for linking to
R language, taken from Nash's lbfgsb3c R package.

## Multi-threading support

This library supports being called simultaneously from different thread optimising
different functions. From the user's side, no locking is needed (of course if your
objective function or gradients do something unsafe you still need to lock).

The original Fortran code cannot be run concurrently even if objective functions
and gradients does only pure side-effect-free arithmetics, due to the use of
COMMON and SAVE etc in Fortran. To circumvant this, this pacakge `dlopen` and
`dlclose` every time the optimisation is requested.

On Linux, you can only have as many threads as maximum usable amount of file
descriptors because we mmap to a file descriptor to pass to dlopen, and glibc
path-caches dlopen, forcing us to wait till the time for dlclose before we can
close the file descriptor. I don't know if this caching means they have to
share memory; for safety reason we wait.

On FreeBSD there's no such restriction.

## Supported platforms

SBCL, ClozureCL on Linux and FreeBSD.

## Extending to other platforms

If you are interested in making it work on Mac or Windows, take a look
at linking.c. I am not proficient enough in Mac and Windows (nor have access to)
to know how `load_library_from_memory` should look like in those platforms.
Contribution is welcome.

## Example

```lisp
(defun rosenbrock (x)
  (let ((x1 (aref x 0)) (x2 (aref x 1)))
    (+ (expt (- 1 x1) 2)
       (* 100 (expt (- x2 (* x1 x1)) 2)))))

(defun rosenbrock-grad (x)
  (let ((x1 (aref x 0)) (x2 (aref x 1)))
    (vector (+ (* -2 (- 1 x1))
               (* -400 x1 (- x2 (* x1 x1))))
            (* 200 (- x2 (* x1 x1))))))

(let ((res (lbfgsb3 #'rosenbrock
                    #(-1.2d0 1.0d0)
                    :gr #'rosenbrock-grad
                    :m 5
                    :factr 0d0
                    :pgtol 1d-5
                    :iprint 1)))
  (format t "x       = ~A~%" (lbfgsb3-result-x res))
  (format t "f       = ~A~%" (lbfgsb3-result-f res))
  (format t "n-iter  = ~A~%" (lbfgsb3-result-n-iter res))
  (format t "n-fg    = ~A~%" (lbfgsb3-result-n-fg res))
  (format t "message = ~A~%" (lbfgsb3-result-message res)))
```



