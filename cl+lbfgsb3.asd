;;(defsystem "cl+lbfgsb3"
;;  :description "CFFI bindings to L-BFGS-B 3.0"
;;  :author "Woodrow Hao Chi Kiang"
;;  :license "BSD 3-Clause"
;;  :depends-on ("cffi")
;;  :serial t
;;  :components
;;  ((:module "src"
;;    :components
;;    ((:file "package")
;;     (:file "library")
;;     (:file "ffi")
;;     (:file "lbfgsb-ffi")))))
;;


(defpackage #:cl+lbfgsb3-system
  (:use #:cl #:asdf))

(in-package #:cl+lbfgsb3-system)

;;; Custom component that represents a Makefile
(defclass makefile (source-file)
  ((type :initform nil)))

(defmethod perform ((o load-op) (c makefile))
  t)

(defmethod perform ((o compile-op) (c makefile))
  (let* ((fortran-dir (asdf:component-pathname (asdf:component-parent c)))  ; ← the module
         (lib-dir     (merge-pathnames "../lib/" fortran-dir))
         (lib-name    #+darwin "liblbfgsb3.dylib"
                      #+(and unix (not darwin)) "liblbfgsb3.so"
                      #+(or windows win32) "lbfgsb3.dll"
                      #-(or darwin unix windows win32) "liblbfgsb3.so")
         (lib         (merge-pathnames lib-name lib-dir)))
    (ensure-directories-exist lib-dir)
    (format *error-output* "~&; Building ~A (in ~A) ...~%" lib fortran-dir)
    (uiop:run-program
     (list "make" "-C" (uiop:native-namestring fortran-dir))
     :output t
     :error-output t)
    (unless (probe-file lib)
      (error "Makefile did not produce ~A" lib))))



(defmethod output-files ((o compile-op) (c makefile))
  (let* ((fortran-dir (component-pathname c))
         (lib-dir     (merge-pathnames "../lib/" fortran-dir)))
    (list (merge-pathnames
           #+darwin "liblbfgsb3.dylib"
           #+(and unix (not darwin)) "liblbfgsb3.so"
           #+(or windows win32) "lbfgsb3.dll"
           #-(or darwin unix windows win32) "liblbfgsb3.so"
           lib-dir))))

(defsystem "cl+lbfgsb3"
  :description "CFFI bindings to L-BFGS-B 3.0 (automatic Fortran build)"
  :author "Woodrow Hao Chi Kiang"
  :license "BSD 3-Clause"
  :depends-on ("cffi" "float-features")
  :serial t
  :components
  ((:module "fortran"
    :components ((:makefile "Makefile")))
   (:module "src"
    :components
    ((:file "package")
     (:file "lbfgsb3-ffi")))))
