module cons2prim
 use cons2primsolver, only:ien_entropy
 implicit none

 interface primitive_to_conservative
  module procedure prim2cons_i,prim2cons_all, prim2consphantom_i,prim2consphantom_all
 end interface primitive_to_conservative

 interface conservative_to_primitive
  module procedure cons2prim_i,cons2prim_all, cons2primphantom_i,cons2primphantom_all
 end interface conservative_to_primitive

 public :: primitive_to_conservative, conservative_to_primitive

 private

contains

!-------------------------------------
!
!  Primitive to conservative routines
!
!-------------------------------------

subroutine prim2cons_i(pos,vel,dens,u,P,rho,pmom,en)
 use cons2primsolver, only:primitive2conservative
 real, intent(in)  :: pos(1:3)
 real, intent(in)  :: dens,vel(1:3),u,P
 real, intent(out) :: rho,pmom(1:3),en

 call primitive2conservative(pos,vel,dens,u,P,rho,pmom,en,ien_entropy)

end subroutine prim2cons_i


subroutine prim2cons_all(npart,xyzh,dens,v,u,P,rho,pmom,en)
 use part,            only:isdead_or_accreted
 use cons2primsolver, only:primitive2conservative
 integer, intent(in) :: npart
 real, intent(in) :: xyzh(:,:), v(:,:)
 real, intent(in) :: dens(:),u(:),P(:)
 real, intent(out) :: pmom(:,:)
 real, intent(out) :: rho(:), en(:)
 integer :: i

!$omp parallel do default (none) &
!$omp shared(xyzh,v,dens,u,p,rho,pmom,en,npart) &
!$omp private(i)
 do i=1,npart
    if (.not.isdead_or_accreted(xyzh(4,i))) then
       call prim2cons_i(xyzh(1:3,i),v(1:3,i),dens(i),u(i),P(i),rho(i),pmom(1:3,i),en(i))
    endif
 enddo
!$omp end parallel do

end subroutine prim2cons_all


subroutine prim2consphantom_i(xyzhi,vxyzui,dens_i,pxyzui,use_dens)
 use utils_gr,        only:h2dens
 use cons2primsolver, only:primitive2conservative
 use eos,          only:equationofstate,ieos
 real, dimension(4), intent(in)  :: xyzhi, vxyzui
 real, intent(inout)             :: dens_i
 real, dimension(4), intent(out) :: pxyzui
 logical, intent(in), optional   :: use_dens
 logical :: usedens
 real :: rhoi,Pi,ui,xyzi(1:3),vi(1:3),pondensi,spsoundi,densi

 !  By default, use the smoothing length to compute primitive density, and then compute the conserved variables.
 !  (Alternatively, use the provided primitive density to compute conserved variables.
 !   Depends whether you have prim dens prior or not.)
 if (present(use_dens)) then
    usedens = use_dens
 else
    usedens = .false.
 endif

 xyzi = xyzhi(1:3)
 vi   = vxyzui(1:3)
 ui   = vxyzui(4)
 if (usedens) then
    densi = dens_i
 else
    call h2dens(densi,xyzhi,vi) ! Compute dens from h
    dens_i = densi              ! Feed the newly computed dens back out of the routine
 endif
 call equationofstate(ieos,pondensi,spsoundi,densi,xyzi(1),xyzi(2),xyzi(3),ui)
 pi = pondensi*densi
 call primitive2conservative(xyzi,vi,densi,ui,Pi,rhoi,pxyzui(1:3),pxyzui(4),ien_entropy)

end subroutine prim2consphantom_i


subroutine prim2consphantom_all(npart,xyzh,vxyzu,dens,pxyzu,use_dens)
 use part,         only:isdead_or_accreted
 integer, intent(in)  :: npart
 real,    intent(in)  :: xyzh(:,:),vxyzu(:,:)
 real,    intent(inout) :: dens(:)
 real,    intent(out) :: pxyzu(:,:)
 logical, intent(in), optional :: use_dens
 logical :: usedens
 integer :: i

!  By default, use the smoothing length to compute primitive density, and then compute the conserved variables.
!  (Alternatively, use the provided primitive density to compute conserved variables.
!   Depends whether you have prim dens prior or not.)
 if (present(use_dens)) then
    usedens = use_dens
 else
    usedens = .false.
 endif

!$omp parallel do default (none) &
!$omp shared(xyzh,vxyzu,dens,pxyzu,npart,usedens) &
!$omp private(i)
 do i=1,npart
    if (.not.isdead_or_accreted(xyzh(4,i))) then
       call prim2consphantom_i(xyzh(:,i),vxyzu(:,i),dens(i),pxyzu(:,i),usedens)
    endif
 enddo
!$omp end parallel do

end subroutine prim2consphantom_all


!-------------------------------------
!
!  Conservative to primitive routines
!
!-------------------------------------

subroutine cons2prim_i(pos,vel,dens,u,P,rho,pmom,en,ierr)
 use cons2primsolver, only:conservative2primitive
 real, intent(in)     :: pos(1:3)
 real, intent(in)     :: rho,pmom(1:3),en
 real, intent(out)    :: vel(1:3),u
 real, intent(inout)  :: dens,P      ! Intent=inout because we need their previous values as an initial guess in the solver
 integer, intent(out) :: ierr

 call conservative2primitive(pos,vel,dens,u,P,rho,pmom,en,ierr,ien_entropy)

end subroutine cons2prim_i


subroutine cons2prim_all(npart,xyzh,rho,pmom,en,dens,v,u,P)
 use part,            only:isdead_or_accreted
 use io,              only:fatal
 use cons2primsolver, only:conservative2primitive
 integer, intent(in) :: npart
 real, intent(in) :: pmom(:,:),xyzh(:,:)
 real, intent(in) :: rho(:),en(:)
 real, intent(inout) :: v(:,:)
 real, intent(inout) :: dens(:), u(:), P(:)
 integer :: i, ierr

!$omp parallel do default (none) &
!$omp shared(xyzh,v,dens,u,p,rho,pmom,en,npart) &
!$omp private(i,ierr)
 do i=1,npart
    if (.not.isdead_or_accreted(xyzh(4,i))) then
       call cons2prim_i(xyzh(1:3,i),v(1:3,i),dens(i),u(i),P(i),rho(i),pmom(1:3,i),en(i),ierr)
       if (ierr > 0) then
          print*,' pmom =',pmom(1:3,i)
          print*,' rho* =',rho(i)
          print*,' en   =',en(i)
          call fatal('cons2prim','could not solve rootfinding',i)
       endif
    endif
 end do
!$omp end parallel do

end subroutine cons2prim_all


subroutine cons2primphantom_i(xyzhi,pxyzui,vxyzui,densi,ierr,pressure)
 use part,            only:massoftype, igas, rhoh
 use cons2primsolver, only:conservative2primitive
 use utils_gr,        only:rho2dens
 use eos,             only:equationofstate,ieos
 real,    dimension(4), intent(in)    :: xyzhi,pxyzui
 real,    dimension(4), intent(inout) :: vxyzui
 real, intent(inout)                  :: densi
 integer, intent(out),  optional      :: ierr
 real,    intent(out),  optional      :: pressure
 real    :: rhoi, p_guess, xyzi(1:3), v_guess(1:3), u_guess, pondens, spsound
 integer :: ierror

 rhoi    = rhoh(xyzhi(4),massoftype(igas))
 xyzi    = xyzhi(1:3)
 v_guess = vxyzui(1:3)
 u_guess = vxyzui(4)
 call equationofstate(ieos,pondens,spsound,densi,xyzi(1),xyzi(2),xyzi(3),u_guess)
 p_guess = pondens*densi
 call conservative2primitive(xyzi,vxyzui(1:3),densi,vxyzui(4),p_guess,rhoi,pxyzui(1:3),pxyzui(4),ierror,ien_entropy)
 if (present(pressure)) pressure = p_guess
 if (present(ierr)) ierr = ierror

end subroutine cons2primphantom_i


subroutine cons2primphantom_all(npart,xyzh,pxyzu,vxyzu,dens)
 use part, only:isdead_or_accreted, massoftype, igas, rhoh
 use io,   only:fatal
 integer, intent(in)    :: npart
 real,    intent(in)    :: pxyzu(:,:),xyzh(:,:)
 real,    intent(inout) :: vxyzu(:,:),dens(:)
 integer :: i, ierr

!$omp parallel do default (none) &
!$omp shared(xyzh,vxyzu,dens,pxyzu,npart,massoftype) &
!$omp private(i,ierr)
 do i=1,npart
    if (.not.isdead_or_accreted(xyzh(4,i))) then
       call cons2primphantom_i(xyzh(:,i),pxyzu(:,i),vxyzu(:,i),dens(i),ierr)
       if (ierr > 0) then
          print*,' pmom =',pxyzu(1:3,i)
          print*,' rho* =',rhoh(xyzh(4,i),massoftype(igas))
          print*,' en   =',pxyzu(4,i)
          call fatal('cons2prim','could not solve rootfinding',i)
       endif
    endif
 end do
!$omp end parallel do

end subroutine cons2primphantom_all

end module cons2prim