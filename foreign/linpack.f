c     Minimal LINPACK routines required by L-BFGS-B 3.0
c     (dpofa + dtrsl).  Taken from netlib, F77 style.

      subroutine dpofa(a,lda,n,info)
      integer lda,n,info
      double precision a(lda,*)
c
c     factors a double precision symmetric positive definite matrix.
c
      double precision ddot,s,t
      integer j,jm1,k
      info = 0
      do 30 j = 1, n
         info = j
         s = 0.0d0
         jm1 = j - 1
         if (jm1 .lt. 1) go to 20
         do 10 k = 1, jm1
            t = a(k,j) - ddot(k-1,a(1,k),1,a(1,j),1)
            t = t/a(k,k)
            a(k,j) = t
            s = s + t*t
   10    continue
   20    continue
         s = a(j,j) - s
         if (s .le. 0.0d0) go to 40
         a(j,j) = dsqrt(s)
   30 continue
      info = 0
   40 return
      end

      subroutine dtrsl(t,ldt,n,b,job,info)
      integer ldt,n,job,info
      double precision t(ldt,*),b(*)
c
c     solves systems of the form  t*x=b  or  trans(t)*x=b
c     where t is a triangular matrix of order n.
c
      double precision ddot,temp
      integer case,j,jj
      info = 0
c
c     check for zero diagonal elements.
c
      do 10 j = 1, n
         if (t(j,j) .eq. 0.0d0) then
            info = j
            return
         endif
   10 continue
c
      case = 1
      if (job .ge. 10) case = 2
      if (mod(job,10) .ne. 0) case = case + 2
c
      go to (20,50,80,110), case
c
c     solve t*x=b  (lower triangular, job = 00)
c
   20 continue
      b(1) = b(1)/t(1,1)
      if (n .lt. 2) return
      do 40 j = 2, n
         temp = -b(j-1)
         call daxpy(n-j+1,temp,t(j,j-1),1,b(j),1)
         b(j) = b(j)/t(j,j)
   40 continue
      return
c
c     solve t*x=b  (upper triangular, job = 01)
c
   50 continue
      b(n) = b(n)/t(n,n)
      if (n .lt. 2) return
      do 70 jj = 2, n
         j = n - jj + 1
         temp = -b(j+1)
         call daxpy(j,temp,t(1,j+1),1,b(1),1)
         b(j) = b(j)/t(j,j)
   70 continue
      return
c
c     solve trans(t)*x=b  (lower triangular, job = 10)
c
   80 continue
      b(n) = b(n)/t(n,n)
      if (n .lt. 2) return
      do 100 jj = 2, n
         j = n - jj + 1
         b(j) = b(j) - ddot(jj-1,t(j+1,j),1,b(j+1),1)
         b(j) = b(j)/t(j,j)
  100 continue
      return
c
c     solve trans(t)*x=b  (upper triangular, job = 11)
c
  110 continue
      b(1) = b(1)/t(1,1)
      if (n .lt. 2) return
      do 130 j = 2, n
         b(j) = b(j) - ddot(j-1,t(1,j),1,b(1),1)
         b(j) = b(j)/t(j,j)
  130 continue
      return
      end
