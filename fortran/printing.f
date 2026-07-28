c     Minimal replacements for R's intpr / dblepr / dblepr1
c     for use with L-BFGS-B from Common Lisp.

      subroutine intpr(label, nchar, data, ndata)
      implicit none
      character*(*) label
      integer nchar, ndata, data(*)
      integer nc, i
      nc = nchar
      if (nc .lt. 0) nc = len(label)
      if (ndata .le. 0) then
         write(6,'(A)') label(1:nc)
      else
         write(6,*) label(1:nc), (data(i), i=1,ndata)
      endif
      end

      subroutine dblepr(label, nchar, data, ndata)
      implicit none
      character*(*) label
      integer nchar, ndata
      double precision data(*)
      integer nc, i
      nc = nchar
      if (nc .lt. 0) nc = len(label)
      if (ndata .le. 0) then
         write(6,'(A)') label(1:nc)
      else
         write(6,*) label(1:nc), (data(i), i=1,ndata)
      endif
      end

      subroutine dblepr1(label, nchar, var)
      implicit none
      character*(*) label
      integer nchar
      double precision var, data(1)
      data(1) = var
      call dblepr(label, nchar, data, 1)
      end
