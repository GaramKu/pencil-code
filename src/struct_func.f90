! $Id: struct_func.f90,v 1.6 2003-01-10 14:00:27 nilshau Exp $
!
!  Calculates 2-point structure functions and/or PDFs
!  and saves them during the run.
!
!  For the time being, the structure functions (or PDFs) are
!  called from power, so the output frequency is set by dspec.
!
!  The save files are under data/proc# under the names
!  sfz1_sum_ or sfz1_sum_transp_ .
!
!-----------------------------------------------------------------------
!   23-dec-02/nils: adapted from postproc/src/struct_func_mpi.f90
!

module struct_func
  !
  implicit none
  !
  contains

!***********************************************************************
    subroutine structure(f,variabl)
!
!  The following parameters may need to be readjusted:
!  qmax should be set to the largest moment to be calculated
!  n_pdf gives the number of bins of the PDF
!
!   23-dec-02/nils: adapted from postproc/src/struct_func_mpi.f90
!   28-dec-02/axel: need also n_pdf in normalization
!
  use Cdata
  use Sub
  use General
  use Mpicomm
  !
  implicit none
  !
  integer, parameter :: qmax=8, imax=nx/2
  integer, parameter :: n_pdf=101
  real, dimension (mx,my,mz,mvar) :: f
  real, dimension (nx,ny,nz,3) :: vect,u_vec,b_vec
  real, dimension (nx) :: bb 
  real, dimension (imax,3,qmax,3) :: sf,sf_sum
  real, dimension (imax) :: totall 
  real, dimension (ny,nz,3) :: dvect
  real, dimension(n_pdf,imax,3,3) :: p_du,p_du_sum
  real, dimension(n_pdf) :: x_du
  integer, dimension (ny,nz,3) :: i_du
  integer :: l,ll,j,q,direction
  integer :: separation,i,ivec,im,in
  real :: pdf_max,pdf_min,normalization,dx_du
  character (len=4) :: var
  character (len=*) :: variabl
  character (len=20):: filetowrite
  logical :: llsf=.false., llpdf=.false.
  ! 
  !
  !
  if (iproc==root) print*,'Doing structure functions'
  do ivec=1,3
     !
     if (variabl .eq. 'u') then
        vect(:,:,:,ivec)=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
        filetowrite='/sfu_'
        sf=0.
        totall=0
        llsf=.true.
        llpdf=.false.
     elseif (variabl .eq. 'b') then
        vect(:,:,:,ivec)=f(l1:l2,m1:m2,n1:n2,iaa+ivec-1)
        filetowrite='/sfb_'
        sf=0.
        totall=0
        llsf=.true.
        llpdf=.false.
     elseif (variabl .eq. 'z1') then
        u_vec(:,:,:,ivec)=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              b_vec(:,im,in,ivec)=bb
           enddo
        enddo
        vect(:,:,:,ivec)=u_vec(:,:,:,ivec)+b_vec(:,:,:,ivec)
        filetowrite='/sfz1_'
        sf=0.
        totall=0
        llsf=.true.
        llpdf=.false.
     elseif (variabl .eq. 'z2') then
        u_vec(:,:,:,ivec)=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              b_vec(:,im,in,ivec)=bb
           enddo
        enddo
        vect(:,:,:,ivec)=u_vec(:,:,:,ivec)-b_vec(:,:,:,ivec)
        filetowrite='/sfz2_'
        sf=0.
        totall=0
        llsf=.true.
        llpdf=.false.
     end if
  enddo
  !
  !  Setting some variables depending on wether we want to
  !  calculate pdf or structure functions.
  !
  if (variabl .eq. 'pdf') then 
     vect(:,:,:,ivec)=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
     pdf_max= 1.  !(for the time being; assumes |u|<1)
     pdf_min=-pdf_max
     dx_du=(pdf_max-pdf_min)/n_pdf
     do l=1,n_pdf
        x_du(l)=(l-.5)*dx_du+pdf_min
     enddo
     p_du=0.
     llpdf=.true.
     llsf=.false.
  endif
  !
  !  Beginning the loops
  !
  do direction=1,nr_directions
     do l=1,nx
        do ll=l+1,nx
           separation=min(mod(ll-l+nx,nx),mod(l-ll+nx,nx))
           dvect=vect(l,:,:,:)-vect(ll,:,:,:)
           if (llpdf) then !if pdf=.true.
              i_du=1+int((dvect-pdf_min)*n_pdf/(pdf_max-pdf_min))
              i_du=min(max(i_du,1),n_pdf)  !(make sure its inside array bdries)
              !
              !  Calculating pdf
              !
              do j=1,3
                 do m=1,ny
                    do n=1,nz
                       p_du(i_du(m,n,j),separation,j,direction) &
                            =p_du(i_du(m,n,j),separation,j,direction)+1
                    enddo
                 enddo
              enddo
           endif
           !
           if (llsf) then
              !
              !  Calculates sf
              !
              totall(separation)=totall(separation)+1
              do j=1,3
                 do q=1,qmax                          
                    sf(separation,j,q,direction) &
                         =sf(separation,j,q,direction) &
                         +sum(abs(dvect(:,:,j))**q)
                 enddo
              enddo
           endif
        enddo
     enddo
     if (nr_directions .gt. 1) then
        if (direction .eq. 1) then
           !Doing transpose of y direction
           call transp(vect(:,:,:,1),'y')
           call transp(vect(:,:,:,2),'y')
           call transp(vect(:,:,:,3),'y')
        endif
        if (direction .eq. 2) then
           !Doing transpose of z direction
           call transp(vect(:,:,:,1),'z')
           call transp(vect(:,:,:,2),'z')
           call transp(vect(:,:,:,3),'z')
        endif
     endif
  enddo
  !
  !  Collecting all data on root processor and normalizing pdf and sf
  !
  if(llpdf) then
     call mpireduce_sum(p_du,p_du_sum,n_pdf*imax*3*3)  !Is this safe???
     do i=1,imax
        do j=1,3
           do direction=1,nr_directions
              normalization=1./(n_pdf*dx_du*sum(p_du_sum(:,i,j,direction)))
              p_du_sum(:,i,j,direction)=normalization*p_du_sum(:,i,j,direction)
           enddo
        enddo
     enddo
  endif
  !
  if(llsf) then
     call mpireduce_sum(sf,sf_sum,imax*3*qmax*3)  !Is this safe???
     sf_sum=sf_sum/(nw*ncpus)
     sf_sum(imax,:,:,:)=2*sf_sum(imax,:,:,:)
  endif
  !
  !  Writing output file
  !
  if (iproc==root) then
     do j=1,3              
        call chn(j,var)
        if(llpdf) then
           if (ip<10) print*,'Writing pdf of variable',var &
                ,'to ',trim(datadir)//'/pdf_'//trim(var)//'.dat'
           open(1,file=trim(datadir)//'/pdf_'//trim(var) &
                //'.dat',position='append')
           write(1,*) t,n_pdf
           write(1,'(1p,8e10.2)') p_du_sum(:,:,j,:)
           write(1,'(1p,8e10.2)') x_du
           close(1)
        endif
        !
        if(llsf) then
           if (ip<10) print*,'Writing structure functions of variable',var &
                ,'to ',trim(datadir)//trim(filetowrite)//trim(var)//'.dat'
           open(1,file=trim(datadir)//trim(filetowrite)//trim(var) &
                //'.dat',position='append')
           write(1,*) t,qmax
           write(1,'(1p,8e10.2)') sf_sum(:,j,:,:)
           close(1)
        endif
     enddo
  endif
  !
end subroutine structure
!***********************************************************************
end module struct_func
